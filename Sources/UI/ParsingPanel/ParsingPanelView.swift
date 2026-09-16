import AppKit
import Defaults
import SwiftUI

/// 初始仅显示输入框；结果出现后由内容测量驱动窗口向下扩展。
struct ParsingPanelView: View {
    static let inputHeight: CGFloat = 54
    static let contentPadding: CGFloat = 12
    static let collapsedHeight = inputHeight + contentPadding * 2

    let coordinator: ParsingCoordinator
    let onContentHeightChange: (CGFloat) -> Void
    let onPasteResult: (String) -> Void

    @State private var draft = ""
    @State private var resultsHeight: CGFloat = 0
    @Default(.popupFontSize) private var fontSize
    @Default(.popupFontName) private var fontName

    private var hasResults: Bool {
        coordinator.globalError != nil || !coordinator.activeSlots.isEmpty
    }

    private var preferredHeight: CGFloat {
        Self.collapsedHeight + (hasResults ? 21 + max(24, resultsHeight) : 0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ParsingTextEditor(text: $draft, font: .popup(name: fontName, size: CGFloat(fontSize)), onSubmit: submit)
            .frame(height: Self.inputHeight)

            if hasResults {
                Divider()
                ScrollView {
                    results
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .background {
                            GeometryReader { geometry in
                                Color.clear.preference(key: ParsingResultsHeightKey.self, value: geometry.size.height)
                            }
                            .allowsHitTesting(false)
                        }
                }
            }
        }
        .padding(Self.contentPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .help("Return parses; Return again pastes a ready result back. Shift-Return adds a line; Esc closes.")
        .onPreferenceChange(ParsingResultsHeightKey.self) { height in
            guard height.isFinite else { return }
            resultsHeight = max(0, ceil(height))
        }
        .onChange(of: hasResults) { _, visible in
            if !visible { resultsHeight = 0 }
        }
        .onChange(of: preferredHeight) { _, height in
            onContentHeightChange(height)
        }
        .onAppear {
            onContentHeightChange(preferredHeight)
        }
    }

    private func submit() {
        switch coordinator.enterAction(for: draft) {
        case .parse:
            resultsHeight = 0
            coordinator.parse(draft)
        case .wait:
            break
        case let .paste(text):
            onPasteResult(text)
        case .noContent:
            coordinator.showPasteFailure(String(localized: "No English text to paste."))
        }
    }

    private var results: some View {
        VStack(alignment: .leading, spacing: 12) {
            if coordinator.globalError == nil, case .paste = coordinator.enterAction(for: draft) {
                Text("Press Return again to paste the English result back.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let error = coordinator.globalError {
                Text(error).foregroundStyle(.red)
            }
            ForEach(coordinator.activeSlots, id: \.id) { provider in
                if let state = coordinator.providerStates[provider.id] {
                    VStack(alignment: .leading, spacing: 4) {
                        if coordinator.activeSlots.count > 1 {
                            Text(provider.displayName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        switch state {
                        case .waiting, .parsing:
                            Text("Parsing…").foregroundStyle(.secondary)
                        case let .completed(result):
                            StyledParsingResultView(result: result)
                                .textSelection(.enabled)
                                .contextMenu {
                                    Button("Copy") {
                                        NSPasteboard.general.clearContents()
                                        NSPasteboard.general.setString(result.plainText, forType: .string)
                                    }
                                }
                        case let .error(message):
                            Text(message).foregroundStyle(.red)
                        }
                    }
                }
            }
        }
        .font(.system(size: CGFloat(fontSize), design: .monospaced))
    }
}

/// 与参考图一致的分组与语义配色，不把模型返回的 JSON 直接显示给用户。
private struct StyledParsingResultView: View {
    let result: ParsingResult
    @Environment(\.colorScheme) private var colorScheme

    private var accentColor: Color {
        colorScheme == .dark ? .teal : Color(red: 0, green: 0.40, blue: 0.45)
    }

    private var sentenceColor: Color {
        colorScheme == .dark ? .yellow : Color(red: 0.55, green: 0.40, blue: 0)
    }

    private var explanationColor: Color {
        colorScheme == .dark ? .secondary : Color(white: 0.36)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            switch result {
            case let .check(items, rephrase):
                header("Writing check", symbol: "pencil.and.outline")
                if items.isEmpty, rephrase == nil {
                    Text(result.plainText).foregroundStyle(explanationColor)
                }
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    VStack(alignment: .leading, spacing: 1) {
                        Text(item.wrong).foregroundStyle(.red).strikethrough()
                            + Text(" → ").foregroundStyle(explanationColor)
                            + Text(item.right).foregroundStyle(.green)
                        if !item.reason.isEmpty {
                            Text(item.reason).foregroundStyle(explanationColor)
                        }
                    }
                }
                if let rephrase {
                    Text(verbatim: "◇ " + rephrase).foregroundStyle(sentenceColor)
                }
            case let .tutor(sentence, words, grammar):
                header("Writing tutor", symbol: "character.book.closed")
                Text(verbatim: "◇ " + sentence).foregroundStyle(sentenceColor)
                if !words.isEmpty {
                    Text(verbatim: "Words").foregroundStyle(explanationColor)
                    ForEach(Array(words.enumerated()), id: \.offset) { _, item in
                        annotatedText(term: item.word, note: item.note)
                    }
                }
                if !grammar.isEmpty {
                    Text(verbatim: "Grammar").foregroundStyle(explanationColor)
                    ForEach(Array(grammar.enumerated()), id: \.offset) { _, item in
                        annotatedText(term: item.structure, note: item.note)
                    }
                }
            case .skip:
                header("MoePeek", symbol: "forward")
                Text(result.plainText).foregroundStyle(explanationColor)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func header(_ title: String, symbol: String) -> some View {
        Label { Text(verbatim: title) } icon: { Image(systemName: symbol) }
            .fontWeight(.semibold)
            .foregroundStyle(accentColor)
    }

    private func annotatedText(term: String, note: String) -> Text {
        Text(verbatim: term).foregroundStyle(accentColor)
            + Text(verbatim: "  " + note).foregroundStyle(explanationColor)
    }
}

private struct ParsingResultsHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        // 保留有效内容高度，避免其它子树的默认零值覆盖测量结果。
        value = max(value, nextValue())
    }
}

/// 保留原输入区的原生 NSTextView 交互，但不修改旧 SourceInputView。
private struct ParsingTextEditor: NSViewRepresentable {
    @Binding var text: String
    let font: NSFont
    let onSubmit: () -> Void
    @Default(.defaultInputSource) private var defaultInputSource

    func makeCoordinator() -> Coordinator { Coordinator(text: $text) }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.contentView.drawsBackground = false
        let editor = ParsingTextView(frame: NSRect(origin: .zero, size: scrollView.contentSize))
        editor.isRichText = false
        editor.importsGraphics = false
        editor.allowsUndo = true
        editor.drawsBackground = false
        editor.isAutomaticQuoteSubstitutionEnabled = false
        editor.isAutomaticDashSubstitutionEnabled = false
        editor.isAutomaticTextReplacementEnabled = false
        editor.isVerticallyResizable = true
        editor.isHorizontallyResizable = false
        editor.autoresizingMask = [.width]
        editor.minSize = NSSize(width: 0, height: scrollView.contentSize.height)
        editor.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        editor.textContainerInset = .zero
        editor.textContainer?.lineFragmentPadding = 0
        editor.textContainer?.widthTracksTextView = true
        editor.textContainer?.containerSize = NSSize(width: scrollView.contentSize.width, height: .greatestFiniteMagnitude)
        editor.delegate = context.coordinator
        editor.string = text
        editor.font = font
        editor.textColor = .labelColor
        editor.insertionPointColor = .labelColor
        editor.initialInputSource = defaultInputSource
        editor.typingAttributes = [.font: font, .foregroundColor: NSColor.labelColor]
        editor.onSubmit = onSubmit
        editor.setAccessibilityLabel(String(localized: "Text to parse"))
        scrollView.documentView = editor
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let editor = scrollView.documentView as? ParsingTextView else { return }
        context.coordinator.text = $text
        if !editor.hasMarkedText(), editor.string != text { editor.string = text }
        if editor.font != font {
            editor.font = font
            editor.typingAttributes = [.font: font, .foregroundColor: NSColor.labelColor]
        }
        editor.onSubmit = onSubmit
        editor.initialInputSource = defaultInputSource
        editor.updateLayout(for: scrollView.contentSize)
        editor.needsDisplay = true
        editor.focusInitially()
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var text: Binding<String>

        init(text: Binding<String>) { self.text = text }

        func textDidChange(_ notification: Notification) {
            guard let editor = notification.object as? NSTextView else { return }
            text.wrappedValue = editor.string
        }
    }
}

private final class ParsingTextView: NSTextView {
    var onSubmit: (() -> Void)?
    var initialInputSource = ""
    private var didFocusInitially = false
    private var submitsOnReturnUp = false

    /// 占位提示直接读取原生内容，包含尚未提交到 SwiftUI 的输入法组字。
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard string.isEmpty, !hasMarkedText(), let font else { return }
        let rect = NSRect(
            origin: textContainerOrigin,
            size: NSSize(width: max(0, bounds.width - textContainerOrigin.x), height: ceil(font.ascender - font.descender + font.leading))
        )
        let placeholder = String(localized: "Type or paste text, then press Return to parse.") as NSString
        placeholder.draw(
            with: rect,
            options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine],
            attributes: [.font: font, .foregroundColor: NSColor.tertiaryLabelColor]
        )
    }

    override func setMarkedText(_ string: Any, selectedRange: NSRange, replacementRange: NSRange) {
        super.setMarkedText(string, selectedRange: selectedRange, replacementRange: replacementRange)
        needsDisplay = true
    }

    override func unmarkText() {
        super.unmarkText()
        needsDisplay = true
    }

    override func didChangeText() {
        super.didChangeText()
        needsDisplay = true
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        focusInitially()
    }

    func focusInitially() {
        guard !didFocusInitially, let window else { return }
        window.initialFirstResponder = self
        didFocusInitially = window.makeFirstResponder(self)
        if didFocusInitially, !initialInputSource.isEmpty,
           let inputContext, inputContext.keyboardInputSources?.contains(initialInputSource) == true {
            inputContext.selectedKeyboardInputSource = initialInputSource
        }
    }

    func updateLayout(for contentSize: NSSize) {
        minSize = NSSize(width: 0, height: contentSize.height)
        textContainer?.containerSize = NSSize(width: contentSize.width, height: .greatestFiniteMagnitude)
        frame.size.width = contentSize.width
        if let textContainer { layoutManager?.ensureLayout(for: textContainer) }
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 36 || event.keyCode == 76 {
            if hasMarkedText() {
                submitsOnReturnUp = false
                super.keyDown(with: event)
                return
            }
            let modifiers = event.modifierFlags.intersection([.command, .option, .control, .shift])
            if modifiers.isEmpty {
                if !event.isARepeat {
                    submitsOnReturnUp = !string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                }
                return
            }
            submitsOnReturnUp = false
            if modifiers == .shift {
                insertNewline(nil)
                return
            }
        }
        super.keyDown(with: event)
    }

    override func keyUp(with event: NSEvent) {
        guard event.keyCode == 36 || event.keyCode == 76 else {
            super.keyUp(with: event)
            return
        }
        let shouldSubmit = submitsOnReturnUp
        submitsOnReturnUp = false
        guard shouldSubmit else {
            super.keyUp(with: event)
            return
        }
        guard !hasMarkedText(),
              event.modifierFlags.intersection([.command, .option, .control, .shift]).isEmpty else { return }
        onSubmit?()
    }

    override func resignFirstResponder() -> Bool {
        submitsOnReturnUp = false
        return super.resignFirstResponder()
    }
}
