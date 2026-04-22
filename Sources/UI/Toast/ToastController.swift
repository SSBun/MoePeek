import AppKit

/// Manages the toast notification lifecycle: show near cursor, auto-dismiss.
@MainActor
final class ToastController {
    private var panel: ToastPanel?
    private var dismissTimer: Timer?

    /// Show a toast message near the cursor, auto-dismissing after `duration` seconds.
    func show(message: String, duration: TimeInterval = 2.0) {
        dismiss()

        let panel = ToastPanel(message: message)
        self.panel = panel

        // Position near cursor
        let cursorPos = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(cursorPos) })
            ?? NSScreen.main
            ?? NSScreen.screens.first
        else { return }

        let visibleFrame = screen.visibleFrame
        let panelSize = panel.frame.size

        // Center horizontally under cursor, above if needed
        var x = cursorPos.x - panelSize.width / 2
        var y = cursorPos.y - panelSize.height - 16 // 16pt below cursor

        // Clamp to screen bounds
        x = max(visibleFrame.minX, min(x, visibleFrame.maxX - panelSize.width))
        if y < visibleFrame.minY {
            y = cursorPos.y + 16 // Show above cursor if no room below
        }
        y = max(visibleFrame.minY, min(y, visibleFrame.maxY - panelSize.height))

        panel.setFrame(NSRect(x: x, y: y, width: panelSize.width, height: panelSize.height), display: false)
        panel.alphaValue = 0
        panel.orderFront(nil)

        // Fade in
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.15
            panel.animator().alphaValue = 1
        }

        // Auto dismiss
        dismissTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.dismiss()
            }
        }
    }

    /// Dismiss the toast immediately.
    func dismiss() {
        dismissTimer?.invalidate()
        dismissTimer = nil

        guard let panel else { return }
        let panelRef = panel
        self.panel = nil

        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.15
            panelRef.animator().alphaValue = 0
        }, completionHandler: {
            Task { @MainActor [panelRef] in
                panelRef.contentView = nil
                panelRef.close()
            }
        })
    }

    var isVisible: Bool {
        panel?.isVisible ?? false
    }
}
