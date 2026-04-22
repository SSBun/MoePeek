import AppKit

/// A tiny floating panel that hosts the toast message near the cursor.
final class ToastPanel: NSPanel {
    static let height: CGFloat = 32

    init(message: String) {
        let font = NSFont.systemFont(ofSize: 12, weight: .medium)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.labelColor,
        ]
        let textSize = (message as NSString).size(withAttributes: attributes)
        let width = min(textSize.width + 32, 280)
        let rect = NSRect(x: 0, y: 0, width: width, height: Self.height)

        super.init(
            contentRect: rect,
            styleMask: [.nonactivatingPanel, .borderless, .fullSizeContentView],
            backing: .buffered,
            defer: true
        )

        isReleasedWhenClosed = false
        level = .floating
        isOpaque = false
        backgroundColor = .clear
        hidesOnDeactivate = false
        isMovableByWindowBackground = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        contentView = ToastContentView(message: message, width: width, height: Self.height)
    }

    override var canBecomeKey: Bool { false }
}

/// The content view of the toast.
final class ToastContentView: NSView {
    init(message: String, width: CGFloat, height: CGFloat) {
        super.init(frame: NSRect(x: 0, y: 0, width: width, height: height))
        wantsLayer = true
        layer?.cornerRadius = 8
        layer?.masksToBounds = true
        layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

        // Add border
        layer?.borderWidth = 0.5
        layer?.borderColor = NSColor.separatorColor.cgColor

        // Add shadow
        layer?.shadowColor = NSColor.black.cgColor
        layer?.shadowOpacity = 0.15
        layer?.shadowOffset = CGSize(width: 0, height: -1)
        layer?.shadowRadius = 3

        let font = NSFont.systemFont(ofSize: 12, weight: .medium)

        let textField = NSTextField(labelWithString: message)
        textField.font = font
        textField.textColor = .secondaryLabelColor
        textField.alignment = .center
        textField.backgroundColor = .clear
        textField.isBordered = false
        textField.isEditable = false
        textField.isSelectable = false
        textField.lineBreakMode = .byTruncatingTail
        textField.frame = NSRect(x: 8, y: (height - textField.font!.pointSize) / 2, width: width - 16, height: textField.font!.pointSize + 2)

        addSubview(textField)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError()
    }
}
