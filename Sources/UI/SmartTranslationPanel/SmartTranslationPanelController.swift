import AppKit
import SwiftUI

/// 智能模式使用解析面板的窗口交互，独立拥有请求、回填目标与生命周期。
@MainActor
final class SmartTranslationPanelController: NSObject, NSWindowDelegate {
    private static let preferredWidth: CGFloat = 560
    private let coordinator: SmartTranslationCoordinator
    private var panel: ParsingPanel?
    private var keyMonitor: Any?
    private var previouslyActiveApp: NSRunningApplication?
    private var preferredContentHeight = ParsingPanelView.collapsedHeight
    private var isResizeScheduled = false
    private var focusGeneration = 0
    private var pasteTarget: Result<ParsingPasteTarget, ParsingPasteError> = .failure(.noTarget)
    private var pasteTask: Task<Void, Never>?
    private let pasteErrorToast = ToastController()

    init(coordinator: SmartTranslationCoordinator) {
        self.coordinator = coordinator
        super.init()
        NotificationCenter.default.addObserver(self, selector: #selector(screenParametersDidChange), name: NSApplication.didChangeScreenParametersNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(applicationDidResignActive), name: NSApplication.didResignActiveNotification, object: NSApp)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    /// 重复打开只激活已有浮窗，不清空草稿或结果。
    func show() {
        pasteTask?.cancel()
        pasteTask = nil
        pasteErrorToast.dismiss()
        focusGeneration += 1
        if panel == nil {
            pasteTarget = ParsingPasteTarget.capture()
            let activeApp = NSWorkspace.shared.frontmostApplication
            previouslyActiveApp = activeApp?.processIdentifier == ProcessInfo.processInfo.processIdentifier ? nil : activeApp
            coordinator.reset()
            preferredContentHeight = ParsingPanelView.collapsedHeight
            let screen = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main
            let width = min(Self.preferredWidth, max(1, (screen?.visibleFrame.width ?? Self.preferredWidth + 24) - 24))
            let panel = ParsingPanel(
                contentRect: NSRect(x: 0, y: 0, width: width, height: preferredContentHeight),
                styleMask: [.borderless, .closable, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            panel.title = String(localized: "Smart Translation")
            panel.level = .floating
            panel.isFloatingPanel = true
            panel.hidesOnDeactivate = false
            panel.isReleasedWhenClosed = false
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hasShadow = true
            panel.isMovableByWindowBackground = false
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            panel.delegate = self
            panel.onCancel = { [weak self] in
                guard let self else { return }
                self.dismiss()
            }
            self.panel = panel
            let content = SmartTranslationPanelView(
                coordinator: coordinator,
                onContentHeightChange: { [weak self, weak panel] height in
                    guard let self, let panel, self.panel === panel else { return }
                    self.requestResize(to: height)
                },
                onPasteResult: { [weak self, weak panel] text in
                    guard let self, let panel, self.panel === panel else { return }
                    self.pasteResult(text)
                }
            )
            let hostingView = NSHostingView(rootView: content)
            hostingView.sizingOptions = []
            panel.contentView = hostingView
            if let frame = screen?.visibleFrame {
                panel.setFrameOrigin(NSPoint(x: frame.midX - panel.frame.width / 2, y: frame.midY - panel.frame.height / 2))
            } else {
                panel.center()
            }
            startKeyMonitor()
        }
        NSApp.activate(ignoringOtherApps: true)
        panel?.makeKeyAndOrderFront(nil)
    }

    /// 仅已完成句子可调用，目标捕获和回填验证复用原解析实现。
    private func pasteResult(_ text: String) {
        guard pasteTask == nil else { return }
        do {
            let target = try pasteTarget.get()
            try target.validateBeforeHandoff()
            let generation = focusGeneration
            dismiss(restoringFocus: false)
            pasteTask = Task { @MainActor [weak self] in
                defer {
                    if self?.focusGeneration == generation { self?.pasteTask = nil }
                }
                do {
                    try await target.paste(text)
                } catch is CancellationError {
                    // 新的打开或关闭操作已取代这次回填。
                } catch {
                    guard let self, !Task.isCancelled, self.focusGeneration == generation else { return }
                    self.pasteErrorToast.show(message: error.localizedDescription, duration: 4)
                }
            }
        } catch {
            coordinator.showPasteFailure(error.localizedDescription)
        }
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        dismiss()
        return false
    }

    func windowDidChangeScreen(_ notification: Notification) {
        requestResize(to: preferredContentHeight)
    }

    func windowDidResignKey(_ notification: Notification) {
        guard let window = notification.object as? NSWindow, window === panel else { return }
        dismissAfterFocusChange(applicationDeactivated: false)
    }

    @objc
    private func applicationDidResignActive() {
        dismissAfterFocusChange(applicationDeactivated: true)
    }

    private func dismissAfterFocusChange(applicationDeactivated: Bool) {
        guard let panel else { return }
        let generation = focusGeneration
        DispatchQueue.main.async { [weak self, weak panel] in
            guard let self, let panel, self.panel === panel, self.focusGeneration == generation else { return }
            let lostFocus = applicationDeactivated ? !NSApp.isActive : !panel.isKeyWindow
            guard lostFocus else { return }
            self.dismiss(restoringFocus: false)
        }
    }

    /// 清理本模式的窗口和请求，不改变其它模式；关闭前显式释放 contentView。
    func dismiss(restoringFocus: Bool = true) {
        pasteTask?.cancel()
        pasteTask = nil
        pasteTarget = .failure(.noTarget)
        let shouldRestoreFocus = restoringFocus && NSApp.isActive && panel?.isKeyWindow == true
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
        coordinator.reset()
        preferredContentHeight = ParsingPanelView.collapsedHeight
        panel?.contentView = nil
        panel?.onCancel = nil
        panel?.delegate = nil
        panel?.close()
        panel = nil
        if shouldRestoreFocus { previouslyActiveApp?.activate(options: []) }
        previouslyActiveApp = nil
    }

    private func requestResize(to height: CGFloat) {
        guard panel != nil, height.isFinite, height > 0 else { return }
        preferredContentHeight = height
        guard !isResizeScheduled else { return }
        isResizeScheduled = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.isResizeScheduled = false
            self.resizeToContent()
        }
    }

    private func resizeToContent() {
        guard let panel, let visibleFrame = (panel.screen ?? NSScreen.main)?.visibleFrame else { return }
        let bounds = visibleFrame.insetBy(dx: 12, dy: 12)
        guard bounds.width > 0, bounds.height > 0 else { return }
        var frame = panel.frame
        let top = frame.maxY
        frame.size.width = min(Self.preferredWidth, bounds.width)
        frame.size.height = min(max(ParsingPanelView.collapsedHeight, ceil(preferredContentHeight)), min(640, bounds.height))
        frame.origin.y = top - frame.height
        frame.origin.x = min(max(frame.minX, bounds.minX), bounds.maxX - frame.width)
        frame.origin.y = min(max(frame.minY, bounds.minY), bounds.maxY - frame.height)
        if frame != panel.frame { panel.setFrame(frame, display: true) }
    }

    @objc
    private func screenParametersDidChange() {
        requestResize(to: preferredContentHeight)
    }

    /// 保留旧单词模式的显式复制快捷键，且只消费此窗口的键盘事件。
    private func startKeyMonitor() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, let panel = self.panel, panel.isKeyWindow, event.window === panel else { return event }
            if (panel.firstResponder as? NSTextView)?.hasMarkedText() == true { return event }
            let modifiers = event.modifierFlags.intersection([.command, .option, .control, .shift])
            guard modifiers == .command else { return event }
            if event.keyCode == 36 || event.keyCode == 76 {
                let result = self.coordinator.activeSlots.lazy.compactMap { provider -> SmartTranslationResult? in
                    if case let .completed(result) = self.coordinator.providerStates[provider.id] { return result }
                    return nil
                }.first
                if let result { self.copyAndDismiss(result) }
                return nil
            }
            if let characters = event.charactersIgnoringModifiers, let number = Int(characters), (1...9).contains(number) {
                let slots = self.coordinator.activeSlots
                if slots.indices.contains(number - 1),
                   case let .completed(result) = self.coordinator.providerStates[slots[number - 1].id] {
                    self.copyAndDismiss(result)
                }
                return nil
            }
            return event
        }
    }

    private func copyAndDismiss(_ result: SmartTranslationResult) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(result.plainText, forType: .string)
        dismiss()
    }
}
