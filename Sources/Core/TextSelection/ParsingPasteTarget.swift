import AppKit
import ApplicationServices
import Carbon

/// 本次打开解析面板前的输入目标；只读取身份和选区元数据，不读取原文。
@MainActor
struct ParsingPasteTarget {
    private let application: NSRunningApplication
    private let applicationElement: AXUIElement
    private let window: AXUIElement
    private let input: AXUIElement
    private let selection: CFRange?

    static func capture() -> Result<ParsingPasteTarget, ParsingPasteError> {
        guard AXIsProcessTrusted() else { return .failure(.permissionRequired) }
        guard !IsSecureEventInputEnabled() else { return .failure(.secureInput) }
        guard let application = NSWorkspace.shared.frontmostApplication,
              application.processIdentifier != ProcessInfo.processInfo.processIdentifier,
              !application.isTerminated else { return .failure(.noTarget) }
        let app = AXUIElementCreateApplication(application.processIdentifier)
        guard let input = element(read(app, kAXFocusedUIElementAttribute)),
              let window = element(read(app, kAXFocusedWindowAttribute)),
              let inputWindow = element(read(input, kAXWindowAttribute)),
              CFEqual(window, inputWindow) else { return .failure(.noTarget) }
        guard !isSecure(input) else { return .failure(.secureInput) }
        guard isEditable(input) else { return .failure(.notEditable) }
        return .success(ParsingPasteTarget(application: application, applicationElement: app, window: window, input: input, selection: selectedRange(input)))
    }

    /// 在面板关闭前先检查背景目标，避免已知无效目标导致结果无谓丢失。
    func validateBeforeHandoff() throws {
        try validate(requireForeground: false)
        // 原生菜单在后台或菜单跟踪期间可能不可用，恢复目标应用后再检查。
    }

    /// 恢复应用并重新核对目标，再调用该应用原生 Paste；不设置整框文本，不发送按键。
    func paste(_ text: String) async throws {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw ParsingPasteError.noEnglishText }
        try Task.checkCancellation()
        try validate(requireForeground: false)
        let ownPID = ProcessInfo.processInfo.processIdentifier
        let initialPID = NSWorkspace.shared.frontmostApplication?.processIdentifier
        guard initialPID == ownPID || initialPID == application.processIdentifier else { throw ParsingPasteError.targetChanged }
        guard application.activate(options: []) else { throw ParsingPasteError.focusFailed }
        let deadline = Date().addingTimeInterval(1)
        var focused = false
        while Date() < deadline {
            try Task.checkCancellation()
            let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier
            if pid == application.processIdentifier {
                try validate(requireForeground: true)
                focused = true
                break
            }
            guard pid == nil || pid == ownPID else { throw ParsingPasteError.targetChanged }
            try await Task.sleep(for: .milliseconds(20))
        }
        guard focused else { throw ParsingPasteError.focusFailed }
        guard let command = Self.pasteCommand(in: applicationElement) else { throw ParsingPasteError.pasteUnavailable }
        try validate(requireForeground: true)
        try Task.checkCancellation()
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        guard pasteboard.setString(text, forType: .string) else { throw ParsingPasteError.clipboardFailed }
        let ownedChangeCount = pasteboard.changeCount
        if Self.read(command, kAXEnabledAttribute) as? Bool != true {
            // iTerm2 等应用只在打开菜单时重新验证 Paste；等待剪贴板变化不会刷新缓存状态。
            try refreshPasteMenu(containing: command)
        }
        let commandDeadline = Date().addingTimeInterval(0.3)
        repeat {
            try Task.checkCancellation()
            try validate(requireForeground: true)
            guard pasteboard.changeCount == ownedChangeCount else { throw ParsingPasteError.clipboardChanged }
            if Self.read(command, kAXEnabledAttribute) as? Bool == true {
                // 所有异步等待都已结束；在身份/焦点复核后只执行一次原生菜单动作。
                let status = AXUIElementPerformAction(command, kAXPressAction as CFString)
                guard status == .success else { throw ParsingPasteError.pasteUnconfirmed }
                return
            }
            try await Task.sleep(for: .milliseconds(20))
        } while Date() < commandDeadline
        throw ParsingPasteError.pasteUnavailable
    }

    /// 尝试打开并关闭 Paste 所属的顶层菜单以更新状态；不支持时保留原有等待逻辑。
    private func refreshPasteMenu(containing command: AXUIElement) throws {
        guard let menu = Self.element(Self.read(command, kAXParentAttribute)),
              Self.read(menu, kAXRoleAttribute) as? String == kAXMenuRole as String,
              let menuBarItem = Self.element(Self.read(menu, kAXParentAttribute)),
              Self.read(menuBarItem, kAXRoleAttribute) as? String == kAXMenuBarItemRole as String else { return }
        var menuActions: CFArray?
        var itemActions: CFArray?
        guard AXUIElementCopyActionNames(menu, &menuActions) == .success,
              (menuActions as? [String])?.contains(kAXCancelAction as String) == true,
              AXUIElementCopyActionNames(menuBarItem, &itemActions) == .success,
              (itemActions as? [String])?.contains(kAXPressAction as String) == true else { return }
        try Task.checkCancellation()
        try validate(requireForeground: true)
        let opened = AXUIElementPerformAction(menuBarItem, kAXPressAction as CFString)
        // 即便打开返回失败，也尝试关闭可能已出现的菜单；不发送 Escape 或其他全局按键。
        let closed = AXUIElementPerformAction(menu, kAXCancelAction as CFString)
        guard opened == .success, closed == .success else { throw ParsingPasteError.pasteUnavailable }
        try validate(requireForeground: true)
    }

    private func validate(requireForeground: Bool) throws {
        guard AXIsProcessTrusted() else { throw ParsingPasteError.permissionRequired }
        guard !application.isTerminated else { throw ParsingPasteError.noTarget }
        guard !IsSecureEventInputEnabled(), !Self.isSecure(input) else { throw ParsingPasteError.secureInput }
        if requireForeground {
            guard NSWorkspace.shared.frontmostApplication?.processIdentifier == application.processIdentifier else { throw ParsingPasteError.targetChanged }
        }
        guard let currentWindow = Self.element(Self.read(applicationElement, kAXFocusedWindowAttribute)),
              let inputWindow = Self.element(Self.read(input, kAXWindowAttribute)),
              CFEqual(window, currentWindow), CFEqual(window, inputWindow),
              Self.isEditable(input) else { throw ParsingPasteError.targetChanged }
        if let currentInput = Self.element(Self.read(applicationElement, kAXFocusedUIElementAttribute)) {
            guard CFEqual(input, currentInput) else { throw ParsingPasteError.targetChanged }
        } else {
            // WebKit 输入框在应用退到后台时可能不再通过应用暴露焦点。
            // 仅允许交接前暂时缺失；恢复前台后仍必须重新取得同一个控件。
            guard !requireForeground, !application.isActive,
                  Self.read(input, kAXFocusedAttribute) as? Bool == true else { throw ParsingPasteError.targetChanged }
        }
        if let selection {
            guard let current = Self.selectedRange(input), current.location == selection.location,
                  current.length == selection.length else { throw ParsingPasteError.targetChanged }
        }
    }

    private static func isSecure(_ input: AXUIElement) -> Bool {
        read(input, kAXSubroleAttribute) as? String == kAXSecureTextFieldSubrole as String
            || read(input, "AXProtectedContent") as? Bool == true
    }

    private static func isEditable(_ input: AXUIElement) -> Bool {
        guard let role = read(input, kAXRoleAttribute) as? String,
              [kAXTextFieldRole as String, kAXTextAreaRole as String, kAXComboBoxRole as String].contains(role),
              read(input, kAXEnabledAttribute) as? Bool != false else { return false }
        if read(input, "AXEditable") as? Bool == true { return true }
        for attribute in [kAXValueAttribute, kAXSelectedTextAttribute] {
            var settable = DarwinBoolean(false)
            if AXUIElementIsAttributeSettable(input, attribute as CFString, &settable) == .success, settable.boolValue { return true }
        }
        // 仅可设置选区不代表可编辑；不把终端输出或只读文档当作输入框。
        return false
    }

    private static func pasteCommand(in app: AXUIElement) -> AXUIElement? {
        guard let menuBar = element(read(app, kAXMenuBarAttribute)) else { return nil }
        var queue: [(AXUIElement, Int)] = [(menuBar, 0)]
        var index = 0
        let deadline = Date().addingTimeInterval(1.5)
        while index < queue.count, index < 160, Date() < deadline {
            let (item, depth) = queue[index]
            index += 1
            if read(item, kAXRoleAttribute) as? String == kAXMenuItemRole as String,
               (read(item, kAXMenuItemCmdCharAttribute) as? String)?.lowercased() == "v",
               (read(item, kAXMenuItemCmdModifiersAttribute) as? NSNumber)?.intValue == 0 {
                var names: CFArray?
                if AXUIElementCopyActionNames(item, &names) == .success,
                   (names as? [String])?.contains(kAXPressAction as String) == true { return item }
            }
            guard depth < 4 else { continue }
            let children = (read(item, kAXChildrenAttribute) as? [AnyObject]) ?? []
            for child in children.prefix(64) where queue.count < 256 {
                if let child = element(child) { queue.append((child, depth + 1)) }
            }
        }
        return nil
    }

    private static func read(_ element: AXUIElement, _ attribute: String) -> CFTypeRef? {
        AXUIElementSetMessagingTimeout(element, 0.15)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return nil }
        return value
    }

    private static func element(_ value: CFTypeRef?) -> AXUIElement? {
        guard let value, CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return unsafeBitCast(value, to: AXUIElement.self)
    }

    private static func selectedRange(_ element: AXUIElement) -> CFRange? {
        guard let value = read(element, kAXSelectedTextRangeAttribute), CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
        let axValue = unsafeBitCast(value, to: AXValue.self)
        var range = CFRange()
        guard AXValueGetValue(axValue, .cfRange, &range), range.location >= 0, range.length >= 0 else { return nil }
        return range
    }
}

enum ParsingPasteError: LocalizedError {
    /// 用户尚未授予辅助功能权限。
    case permissionRequired
    /// 没有可以锁定的原输入框。
    case noTarget
    /// 安全输入不允许自动回填。
    case secureInput
    /// 辅助功能无法证明目标可编辑。
    case notEditable
    /// 原窗口、控件或选区已改变。
    case targetChanged
    /// 原应用未能恢复焦点。
    case focusFailed
    /// 原应用没有可用的普通 Paste 操作。
    case pasteUnavailable
    /// 没有可回填的英文正文。
    case noEnglishText
    /// 无法将正文写入剪贴板。
    case clipboardFailed
    /// 用户或其他应用在回填期间改变了剪贴板。
    case clipboardChanged
    /// 菜单动作返回失败，不能安全自动重试。
    case pasteUnconfirmed

    var errorDescription: String? {
        switch self {
        case .permissionRequired: String(localized: "Enable Accessibility to paste back.")
        case .noTarget: String(localized: "Original input is unavailable.")
        case .secureInput: String(localized: "Cannot paste into secure input.")
        case .notEditable: String(localized: "Original input is not editable.")
        case .targetChanged: String(localized: "Input focus changed. Paste stopped.")
        case .focusFailed: String(localized: "Could not focus the original input.")
        case .pasteUnavailable: String(localized: "Original app cannot paste automatically.")
        case .noEnglishText: String(localized: "No English text to paste.")
        case .clipboardFailed: String(localized: "Could not copy the English result.")
        case .clipboardChanged: String(localized: "Clipboard changed. Paste stopped.")
        case .pasteUnconfirmed: String(localized: "Paste was not confirmed. Check the input.")
        }
    }
}
