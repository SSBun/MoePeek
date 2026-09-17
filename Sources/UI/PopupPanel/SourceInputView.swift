import AppKit
import Defaults
import SwiftUI

/// Editable source text input with Enter to translate, Shift+Enter for newline.
struct SourceInputView: View {
    @Binding var text: String
    let onSubmit: () -> Void
    @Default(.popupFontSize) private var fontSize
    @Default(.popupFontName) private var fontName

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            SourceTextEditor(
                text: $text,
                fontSize: CGFloat(fontSize),
                fontName: fontName,
                onSubmit: onSubmit
            )
                .frame(maxHeight: .infinity)
                .background { InteractiveMarker() }

            HStack(spacing: 4) {
                Spacer()

                Text("↵ Translate · ⇧↵ Newline · ⌘↵ Copy & Close")
                    .font(.popup(name: fontName, size: CGFloat(fontSize - 4)))
                    .foregroundStyle(.quaternary)
            }
        }
    }
}

private struct SourceTextEditor: NSViewRepresentable {
    @Binding var text: String
    let fontSize: CGFloat
    let fontName: String
    let onSubmit: () -> Void
    @Default(.defaultInputSource) private var defaultInputSource

    private var resolvedFont: NSFont {
        .popup(name: fontName, size: fontSize)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.contentView.drawsBackground = false

        let contentSize = scrollView.contentSize
        let textView = SubmitAwareTextView(frame: NSRect(origin: .zero, size: contentSize))
        textView.isRichText = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.drawsBackground = false
        textView.backgroundColor = .clear
        textView.minSize = NSSize(width: 0, height: contentSize.height)
        textView.maxSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.delegate = context.coordinator
        textView.textContainerInset = .zero
        textView.onSubmit = onSubmit
        textView.textContainer?.containerSize = NSSize(
            width: contentSize.width,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.lineFragmentPadding = 0
        textView.applyDisplayAttributes(font: resolvedFont)
        textView.setExternalText(text)

        scrollView.documentView = textView
        context.coordinator.textView = textView

        textView.initialInputSource = defaultInputSource
        textView.focusInitially()

        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = context.coordinator.textView else { return }

        textView.applyDisplayAttributes(font: resolvedFont)
        textView.updateLayout(for: nsView.contentSize)

        if textView.string != text {
            textView.setExternalText(text)
        }

        textView.onSubmit = onSubmit
        textView.initialInputSource = defaultInputSource
        textView.focusInitially()
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        @Binding var text: String
        weak var textView: SubmitAwareTextView?

        init(text: Binding<String>) {
            _text = text
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? SubmitAwareTextView else { return }
            textView.refreshDisplay()
            text = textView.string
        }
    }
}

private final class SubmitAwareTextView: NSTextView {
    var onSubmit: (() -> Void)?
    var initialInputSource = ""
    private var displayFont: NSFont = .systemFont(ofSize: NSFont.systemFontSize)
    private var didFocusInitially = false

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        focusInitially()
    }

    func focusInitially() {
        guard !didFocusInitially, let window else { return }
        window.initialFirstResponder = self
        guard window.makeFirstResponder(self) else { return }
        didFocusInitially = true
        applyInputSource(initialInputSource)
    }

    func applyDisplayAttributes(font: NSFont) {
        displayFont = font
        self.font = displayFont
        textColor = .labelColor
        insertionPointColor = .labelColor
        typingAttributes = mergedTypingAttributes()
        selectedTextAttributes = [
            .foregroundColor: NSColor.selectedTextColor,
            .backgroundColor: NSColor.selectedTextBackgroundColor,
        ]
        applyDisplayAttributesToTextStorage()
        refreshDisplay()
    }

    func setExternalText(_ newValue: String) {
        string = newValue
        typingAttributes = mergedTypingAttributes()
        applyDisplayAttributesToTextStorage()
        setSelectedRange(NSRange(location: (newValue as NSString).length, length: 0))
        refreshDisplay()
    }

    func updateLayout(for contentSize: NSSize) {
        minSize = NSSize(width: 0, height: contentSize.height)
        if let textContainer {
            textContainer.containerSize = NSSize(
                width: contentSize.width,
                height: CGFloat.greatestFiniteMagnitude
            )
            textContainer.widthTracksTextView = true
        }
        frame.size.width = contentSize.width
        refreshDisplay()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        applyDisplayAttributes(font: displayFont)
    }

    override func keyDown(with event: NSEvent) {
        let isReturnKey = event.keyCode == 36 || event.keyCode == 76
        let hasShift = event.modifierFlags.contains(.shift)

        // During IME composition (e.g. Chinese Pinyin), Enter should first commit marked text.
        // Only submit translation when composition has ended.
        if isReturnKey, !hasShift, !hasMarkedText() {
            guard !string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
            onSubmit?()
            return
        }

        super.keyDown(with: event)
    }

    private func mergedTypingAttributes() -> [NSAttributedString.Key: Any] {
        var attributes = typingAttributes
        attributes[.font] = displayFont
        attributes[.foregroundColor] = NSColor.labelColor
        return attributes
    }

    private func applyDisplayAttributesToTextStorage() {
        guard let textStorage else { return }
        let range = NSRange(location: 0, length: textStorage.length)
        textStorage.beginEditing()
        if range.length > 0 {
            textStorage.addAttributes(
                [
                    .font: displayFont,
                    .foregroundColor: NSColor.labelColor,
                ],
                range: range
            )
        }
        textStorage.endEditing()
    }

    func refreshDisplay() {
        if let textContainer, let layoutManager {
            layoutManager.ensureLayout(for: textContainer)
        }
        needsDisplay = true
        setNeedsDisplay(bounds)
        enclosingScrollView?.contentView.needsDisplay = true
        enclosingScrollView?.needsDisplay = true
    }

    func applyInputSource(_ inputSource: String) {
        guard !inputSource.isEmpty,
              let inputContext,
              inputContext.keyboardInputSources?.contains(inputSource) == true
        else { return }
        inputContext.selectedKeyboardInputSource = inputSource
    }
}
