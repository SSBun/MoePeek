import AppKit
import OSLog
import SwiftUI

/// 独立的紧凑解析浮窗，尺寸由实际结果内容决定，不接触翻译面板。
@MainActor
final class ParsingPanelController: NSObject, NSWindowDelegate {
    private static let preferredWidth: CGFloat = 560
    private static let logger = Logger(subsystem: "com.nahida.MoePeek", category: "Pasteback")
    private let coordinator: ParsingCoordinator
    private var panel: ParsingPanel?
    private var previouslyActiveApp: NSRunningApplication?
    private var preferredContentHeight = ParsingPanelView.collapsedHeight
    private var isResizeScheduled = false
    private var focusGeneration = 0
    private var pasteTarget: Result<ParsingPasteTarget, ParsingPasteError> = .failure(.noTarget)
    private var pasteTask: Task<Void, Never>?
    private let pasteErrorToast = ToastController()

    init(coordinator: ParsingCoordinator) {
        self.coordinator = coordinator
        super.init()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersDidChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidResignActive),
            name: NSApplication.didResignActiveNotification,
            object: NSApplication.shared
        )
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
            // 必须在创建/激活自己的输入窗口之前捕获原目标。
            pasteTarget = ParsingPasteTarget.capture()
            switch pasteTarget {
            case .success:
                Self.logger.info("capture.success")
            case let .failure(error):
                Self.logger.error("capture.failed reason=\(String(describing: error), privacy: .public)")
            }
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
            panel.title = String(localized: "Parse Text")
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
            let view = ParsingPanelView(
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
            let hostingView = NSHostingView(rootView: view)
            hostingView.sizingOptions = []
            panel.contentView = hostingView
            if let frame = screen?.visibleFrame {
                panel.setFrameOrigin(NSPoint(x: frame.midX - panel.frame.width / 2, y: frame.midY - panel.frame.height / 2))
            } else {
                panel.center()
            }
        }
        NSApp.activate(ignoringOtherApps: true)
        panel?.makeKeyAndOrderFront(nil)
    }

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
                    Self.logger.info("paste.menu_action_accepted")
                } catch is CancellationError {
                    // 新的打开/关闭操作已取代这次回填。
                } catch {
                    guard let self, !Task.isCancelled, self.focusGeneration == generation else { return }
                    let reason = (error as? ParsingPasteError).map { String(describing: $0) } ?? "unknown"
                    Self.logger.error("paste.failed reason=\(reason, privacy: .public)")
                    let message = ParsingPasteTarget.copyAfterPasteFailure(text, error: error)
                    self.pasteErrorToast.show(message: message, duration: 4)
                }
            }
        } catch {
            let reason = (error as? ParsingPasteError).map { String(describing: $0) } ?? "unknown"
            Self.logger.error("handoff.failed reason=\(reason, privacy: .public)")
            let message = ParsingPasteTarget.copyAfterPasteFailure(text, error: error)
            coordinator.showPasteFailure(message)
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

    /// 等待焦点转移完成后再判断；旧窗口的延迟事件不能关闭新窗口，也不抢回焦点。
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

    /// 清理解析窗口及其请求，不改变翻译会话或快捷键设置。
    func dismiss(restoringFocus: Bool = true) {
        pasteTask?.cancel()
        pasteTask = nil
        pasteTarget = .failure(.noTarget)
        coordinator.reset()
        preferredContentHeight = ParsingPanelView.collapsedHeight
        panel?.contentView = nil
        panel?.onCancel = nil
        panel?.delegate = nil
        panel?.close()
        panel = nil
        if restoringFocus { previouslyActiveApp?.activate(options: []) }
        previouslyActiveApp = nil
    }

    /// 合并同一轮布局产生的高度通知，避免流式文本导致重复窗口布局。
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
        if frame != panel.frame {
            panel.setFrame(frame, display: true)
        }
    }

    @objc
    private func screenParametersDidChange() {
        requestResize(to: preferredContentHeight)
    }
}

/// 解析与智能翻译共用的非激活紧凑窗口，保留外缘拖动与关闭键。
final class ParsingPanel: NSPanel {
    var onCancel: (() -> Void)?

    override var canBecomeKey: Bool { true }

    override func cancelOperation(_ sender: Any?) {
        onCancel?()
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if isKeyWindow, event.charactersIgnoringModifiers?.lowercased() == "w",
           event.modifierFlags.intersection([.command, .option, .control, .shift]) == .command {
            onCancel?()
            return true
        }
        return super.performKeyEquivalent(with: event)
    }

    /// 仅外缘留白可拖动，输入和结果的选择/滚动事件交给原生控件。
    override func sendEvent(_ event: NSEvent) {
        if event.type == .leftMouseDown, let contentView {
            let point = contentView.convert(event.locationInWindow, from: nil)
            let interactiveBounds = contentView.bounds.insetBy(
                dx: ParsingPanelView.contentPadding,
                dy: ParsingPanelView.contentPadding
            )
            if contentView.bounds.contains(point), !interactiveBounds.contains(point) {
                performDrag(with: event)
                return
            }
        }
        super.sendEvent(event)
    }
}
