import AppKit
import Defaults
import SwiftUI

/// 与解析面板共用输入区和句子结果，词条按已确认原型紧凑展开。
struct SmartTranslationPanelView: View {
    let coordinator: SmartTranslationCoordinator
    let onContentHeightChange: (CGFloat) -> Void
    let onCopyResult: (String) -> Void

    @State private var draft = ""
    @State private var resultsHeight: CGFloat = 0
    @Default(.popupFontSize) private var fontSize
    @Default(.popupFontName) private var fontName

    private var inputText: Binding<String> {
        Binding(
            get: { draft },
            set: { value in
                guard value != draft else { return }
                coordinator.reset()
                draft = value
            }
        )
    }

    private var hasResults: Bool {
        coordinator.globalError != nil || !coordinator.activeSlots.isEmpty
    }

    private var showsDivider: Bool {
        !coordinator.providerStates.values.contains {
            if case .completed(.sentence(translation: .some, parsing: _)) = $0 { return true }
            return false
        }
    }

    private var preferredHeight: CGFloat {
        ParsingPanelView.collapsedHeight + (hasResults ? (showsDivider ? 21 : 10) + max(24, resultsHeight) : 0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ParsingTextEditor(
                text: inputText,
                font: .popup(name: fontName, size: CGFloat(fontSize)),
                onSubmit: submit,
                placeholder: String(localized: "Type or paste a word or sentence, then press Return."),
                accessibilityLabel: String(localized: "Text for smart translation")
            )
            .frame(height: ParsingPanelView.inputHeight)

            if hasResults {
                if showsDivider { Divider() }
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
        .padding(ParsingPanelView.contentPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .onPreferenceChange(ParsingResultsHeightKey.self) { height in
            guard height.isFinite else { return }
            resultsHeight = max(0, ceil(height))
        }
        .onChange(of: hasResults) { _, visible in
            if !visible { resultsHeight = 0 }
        }
        .onChange(of: preferredHeight) { _, height in onContentHeightChange(height) }
        .onAppear { onContentHeightChange(preferredHeight) }
    }

    private func submit() {
        switch coordinator.enterAction(for: draft) {
        case .process:
            resultsHeight = 0
            coordinator.process(draft)
        case .wait: break
        case let .copy(text): onCopyResult(text)
        case .noContent: coordinator.showCopyFailure(String(localized: "No English text to copy."))
        }
    }

    private var results: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let error = coordinator.globalError { Text(error).foregroundStyle(.red) }
            if let error = coordinator.historyError { Text(error).foregroundStyle(.red) }
            ForEach(coordinator.activeSlots, id: \.id) { provider in
                if let state = coordinator.providerStates[provider.id] {
                    VStack(alignment: .leading, spacing: 4) {
                        if coordinator.activeSlots.count > 1 {
                            Text(provider.displayName).font(.caption).foregroundStyle(.secondary)
                        }
                        switch state {
                        case .loading:
                            Text("Translating and analyzing…").foregroundStyle(.secondary)
                        case let .error(message):
                            Text(message).foregroundStyle(.red)
                        case let .completed(result):
                            resultView(result)
                                .textSelection(.enabled)
                                .contextMenu {
                                    Button("Copy") {
                                        NSPasteboard.general.clearContents()
                                        NSPasteboard.general.setString(result.plainText, forType: .string)
                                    }
                                }
                        }
                    }
                }
            }
        }
        .font(.system(size: CGFloat(fontSize), design: .monospaced))
    }

    @ViewBuilder
    private func resultView(_ result: SmartTranslationResult) -> some View {
        switch result {
        case let .words(entries):
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(entries.enumerated()), id: \.offset) { index, entry in
                    if index > 0 { Divider() }
                    SmartDictionaryEntryView(entry: entry, fontSize: CGFloat(fontSize), fontName: fontName)
                }
            }
        case let .sentence(translation, parsing):
            VStack(alignment: .leading, spacing: 5) {
                if let translation {
                    Text(verbatim: translation).foregroundStyle(.secondary)
                } else if coordinator.globalError == nil, case .copy = coordinator.enterAction(for: draft) {
                    Text("Press Return again to copy the English result.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                StyledParsingResultView(result: parsing, sourceText: coordinator.submittedText)
            }
        case .skip:
            Text(result.plainText).foregroundStyle(.secondary)
        }
    }
}

private struct SmartDictionaryEntryView: View {
    let entry: SmartTranslationResult.Entry
    let fontSize: CGFloat
    let fontName: String
    @Environment(\.colorScheme) private var colorScheme

    private var accent: Color {
        colorScheme == .dark ? .teal : Color(red: 0, green: 0.40, blue: 0.45)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            // 一个 Text 保留窄窗口和长词条的自然换行，不让音标挤压标题。
            (Text(verbatim: entry.word).font(.popup(name: fontName, size: fontSize + 3)).fontWeight(.semibold)
                + Text(verbatim: "  " + entry.phonetic).foregroundColor(.secondary))
            ForEach(Array(entry.meanings.enumerated()), id: \.offset) { _, meaning in
                Text(verbatim: meaning.partOfSpeech).foregroundColor(accent)
                    + Text(verbatim: "  " + meaning.definition)
            }
            if let usage = entry.usage, !usage.isEmpty {
                Text(verbatim: usage).foregroundStyle(.secondary)
            }
            ForEach(Array(entry.examples.enumerated()), id: \.offset) { index, example in
                VStack(alignment: .leading, spacing: 0) {
                    Text(verbatim: "\(index + 1). \(example.sentence)")
                    Text(verbatim: example.translation).foregroundStyle(.secondary)
                }
                .padding(.top, 1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
