import AppKit
import Defaults
import SwiftUI

/// Manages the lifecycle and positioning of the popup translation panel.
@MainActor
final class PopupPanelController: NSObject, NSWindowDelegate {
    var onDismiss: (() -> Void)?

    private var panel: PopupPanel?
    private var dismissMonitor: PopupDismissMonitor?
    private var focusGeneration = 0

    private let coordinator: TranslationCoordinator
    let historyManager: TranslationHistoryManager

    /// The app that was frontmost before we activated ourselves for input mode.
    /// Used to restore focus after dismissing the input panel.
    private var previouslyActiveApp: NSRunningApplication?

    init(coordinator: TranslationCoordinator, historyManager: TranslationHistoryManager) {
        self.coordinator = coordinator
        self.historyManager = historyManager
        super.init()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidResignActive),
            name: NSApplication.didResignActiveNotification,
            object: NSApp
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(workspaceDidActivateApplication(_:)),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    func showAtCursor() {
        focusGeneration += 1
        let initialSize = setupPanel()
        guard let panel else { return }

        let cursorPos = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(cursorPos) })
            ?? NSScreen.main
            ?? NSScreen.screens.first
        else { return }
        let frame = PopupPositioning.panelFrame(
            contentSize: initialSize,
            cursor: cursorPos,
            screen: screen
        )
        panel.setFrame(frame, display: true)
        // Non-activating: don't steal focus from the user's active app.
        panel.orderFront(nil)

        startDismissMonitor()
    }

    func showAtScreenCenter() {
        focusGeneration += 1
        let initialSize = setupPanel()
        guard let panel else { return }

        let cursorPos = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(cursorPos) })
            ?? NSScreen.main
            ?? NSScreen.screens.first
        else { return }
        let visibleFrame = screen.visibleFrame
        let origin = NSPoint(
            x: visibleFrame.midX - initialSize.width / 2,
            y: visibleFrame.midY - initialSize.height / 2
        )
        panel.setFrame(NSRect(origin: origin, size: initialSize), display: true)
        // Input mode needs the app activated so the panel can receive keyboard events.
        // Without this, makeKeyAndOrderFront alone won't route keystrokes to our panel
        // because macOS keeps delivering them to the previously active app.
        // Remember the previously active app so we can restore focus after dismissal.
        previouslyActiveApp = NSWorkspace.shared.frontmostApplication
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)

        startDismissMonitor()
    }

    func dismiss(restoringFocus: Bool = true) {
        guard panel != nil else { return }
        let shouldRestoreFocus = restoringFocus && NSApp.isActive && panel?.isKeyWindow == true
        dismissMonitor?.stop()
        dismissMonitor = nil
        panel?.contentView = nil
        panel?.delegate = nil
        panel?.close()
        // Recreate panel on next show to ensure a fresh SwiftUI view tree,
        // avoiding stale @Observable state from previous translation sessions.
        panel = nil
        coordinator.dismiss()
        onDismiss?()

        // Restore focus to the previously active app so the user's workflow isn't interrupted.
        if shouldRestoreFocus, let previousApp = previouslyActiveApp {
            previousApp.activate(options: [])
        }
        previouslyActiveApp = nil
    }

    var isVisible: Bool {
        panel?.isVisible ?? false
    }

    func windowDidResignKey(_ notification: Notification) {
        guard let window = notification.object as? NSWindow, window === panel else { return }
        dismissAfterFocusChange(applicationDeactivated: false)
    }

    // MARK: - Private

    @objc
    private func applicationDidResignActive() {
        dismissAfterFocusChange(applicationDeactivated: true)
    }

    @objc
    private func workspaceDidActivateApplication(_ notification: Notification) {
        guard let application = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              application.processIdentifier != ProcessInfo.processInfo.processIdentifier else { return }
        // Cursor-mode panels may never become key or activate our app.
        dismissAfterFocusChange(applicationDeactivated: true)
    }

    private func dismissAfterFocusChange(applicationDeactivated: Bool) {
        guard let panel else { return }
        let generation = focusGeneration
        DispatchQueue.main.async { [weak self, weak panel] in
            guard let self, let panel, self.panel === panel,
                  self.focusGeneration == generation else { return }
            let lostFocus = applicationDeactivated ? !NSApp.isActive : !panel.isKeyWindow
            guard lostFocus else { return }
            self.dismiss(restoringFocus: false)
        }
    }

    @discardableResult
    private func setupPanel() -> CGSize {
        let initialSize = CGSize(
            width: CGFloat(Defaults[.popupDefaultWidth]),
            height: CGFloat(Defaults[.popupDefaultHeight])
        )

        if panel == nil {
            let newPanel = PopupPanel(contentRect: NSRect(origin: .zero, size: initialSize))
            let contentView = PopupView(
                coordinator: coordinator,
                historyManager: historyManager,
                onOpenSettings: { [weak self] in
                    self?.dismiss()
                },
                onCopyFirstAndDismiss: { [weak self] in
                    self?.dismiss()
                }
            )
            .environment(\.popupPanel, newPanel)
            let hostingView = NSHostingView(rootView: contentView)
            // Prevent NSHostingView from auto-resizing the window on content changes,
            // which causes an infinite constraint update loop during streaming.
            hostingView.sizingOptions = []
            newPanel.contentView = hostingView
            newPanel.delegate = self
            panel = newPanel
        }

        return initialSize
    }

    private func startDismissMonitor() {
        guard let panel else { return }
        dismissMonitor?.stop()
        let generation = focusGeneration
        dismissMonitor = PopupDismissMonitor(panel: panel) { [weak self, weak panel] in
            guard let self, let panel, self.panel === panel,
                  self.focusGeneration == generation else { return }
            self.dismiss()
        }
        dismissMonitor?.start()
    }
}
