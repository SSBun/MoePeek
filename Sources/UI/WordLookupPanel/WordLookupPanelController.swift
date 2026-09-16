import AppKit
import Defaults
import SwiftUI

/// 复用翻译浮窗的无标题栏窗口，但独立管理单词会话、键盘事件与关闭生命周期。
@MainActor
final class WordLookupPanelController: NSObject, NSWindowDelegate {
    private let coordinator: WordLookupCoordinator
    private var panel: PopupPanel?
    private var keyMonitor: Any?
    private var previouslyActiveApp: NSRunningApplication?

    init(coordinator: WordLookupCoordinator) {
        self.coordinator = coordinator
        super.init()
    }

    /// 重复打开只激活已有窗口，保留正在查看的条目。
    func show() {
        if panel == nil {
            let activeApp = NSWorkspace.shared.frontmostApplication
            previouslyActiveApp = activeApp?.processIdentifier == ProcessInfo.processInfo.processIdentifier ? nil : activeApp
            coordinator.reset()
            let screen = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main
            let bounds = screen?.visibleFrame.insetBy(dx: 12, dy: 12) ?? NSRect(x: 0, y: 0, width: 800, height: 600)
            let size = NSSize(
                width: min(max(280, CGFloat(Defaults[.popupDefaultWidth])), min(800, bounds.width)),
                height: min(max(200, CGFloat(Defaults[.popupDefaultHeight])), min(800, bounds.height))
            )
            let panel = PopupPanel(contentRect: NSRect(origin: .zero, size: size))
            panel.title = String(localized: "Word Translation")
            panel.minSize = NSSize(width: min(280, bounds.width), height: min(200, bounds.height))
            panel.maxSize = NSSize(width: min(800, bounds.width), height: min(800, bounds.height))
            panel.delegate = self
            let content = WordLookupPanelView(coordinator: coordinator).environment(\.popupPanel, panel)
            let hostingView = NSHostingView(rootView: content)
            hostingView.sizingOptions = []
            panel.contentView = hostingView
            panel.setFrameOrigin(NSPoint(x: bounds.midX - size.width / 2, y: bounds.midY - size.height / 2))
            self.panel = panel
            startKeyMonitor()
        }
        NSApp.activate(ignoringOtherApps: true)
        panel?.makeKeyAndOrderFront(nil)
    }

    /// 清理本模式的窗口和网络请求，不影响其它模式。
    func dismiss(restoringFocus: Bool = true) {
        let wasKeyWindow = panel?.isKeyWindow == true
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
        coordinator.reset()
        panel?.contentView = nil
        panel?.delegate = nil
        panel?.close()
        panel = nil
        if restoringFocus, wasKeyWindow { previouslyActiveApp?.activate(options: []) }
        previouslyActiveApp = nil
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        dismiss()
        return false
    }

    /// 只拦截此窗口的快捷键，避免同时打开翻译/设置时误复制或关闭。
    private func startKeyMonitor() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, let panel = self.panel, panel.isKeyWindow, event.window === panel else { return event }
            if (panel.firstResponder as? NSTextView)?.hasMarkedText() == true { return event }
            let modifiers = event.modifierFlags.intersection([.command, .option, .control, .shift])
            if event.keyCode == 53 || (modifiers == .command && event.charactersIgnoringModifiers?.lowercased() == "w") {
                self.dismiss()
                return nil
            }
            guard modifiers == .command else { return event }
            if event.keyCode == 36 || event.keyCode == 76 {
                let result = self.coordinator.activeSlots.lazy.compactMap { provider -> WordLookupResult? in
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

    private func copyAndDismiss(_ result: WordLookupResult) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(result.plainText, forType: .string)
        dismiss()
    }
}
