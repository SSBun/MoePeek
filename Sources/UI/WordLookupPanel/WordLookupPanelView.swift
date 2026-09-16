import AppKit
import Defaults
import SwiftUI

/// 沿用翻译浮窗的输入区和卡片布局，但不显示语言操作栏。
struct WordLookupPanelView: View {
    let coordinator: WordLookupCoordinator
    @State private var draft = ""
    @State private var inputHeight = CGFloat(Defaults[.popupInputHeight])
    @State private var containerHeight = CGFloat(Defaults[.popupDefaultHeight])
    private let contentPadding: CGFloat = 14

    private var maxInputHeight: CGFloat { max(36, containerHeight - 100) }

    /// 编辑先取消旧会话，避免输入提交后延迟的 onChange 清除新请求。
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

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SourceInputView(
                text: inputText,
                onSubmit: submit,
                shortcutHint: "↵ Look Up · ⇧↵ Newline · ⌘↵ Copy & Close"
            )
            .frame(height: min(max(36, inputHeight), maxInputHeight))
            .padding(.horizontal, contentPadding)
            .padding(.top, contentPadding)
            .padding(.bottom, 4)

            DraggableDividerView(
                inputHeight: $inputHeight,
                minHeight: 36,
                maxHeight: maxInputHeight,
                horizontalPadding: contentPadding,
                onDragEnd: { Defaults[.popupInputHeight] = Int(inputHeight) }
            )

            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    if let error = coordinator.globalError {
                        Label(error, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                    }
                    ForEach(Array(coordinator.activeSlots.enumerated()), id: \.element.id) { index, provider in
                        if let state = coordinator.providerStates[provider.id] {
                            WordLookupProviderCard(
                                provider: provider,
                                state: state,
                                shortcutIndex: index < 9 ? index + 1 : nil
                            )
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, contentPadding)
                .padding(.vertical, 6)
            }
        }
        .padding(.bottom, contentPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background {
            GeometryReader { geometry in
                Color.clear
                    .onAppear { containerHeight = geometry.size.height }
                    .onChange(of: geometry.size.height) { _, height in containerHeight = height }
            }
        }
        .overlay(alignment: .bottomTrailing) { ResizeGripView() }
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onChange(of: maxInputHeight) { _, height in
            inputHeight = min(max(36, inputHeight), height)
        }
    }

    private func submit() {
        guard !coordinator.isLoading, !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        coordinator.lookUp(draft)
    }
}

/// 与翻译结果卡片相同的服务标题、状态与复制位置，正文仍使用字典结构。
private struct WordLookupProviderCard: View {
    let provider: any TranslationProvider
    let state: WordLookupCoordinator.ProviderState
    let shortcutIndex: Int?
    @State private var isExpanded = true
    @Default(.popupFontSize) private var fontSize
    @Default(.popupFontName) private var fontName

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: CGFloat(fontSize - 4)))
                        .foregroundStyle(.tertiary)
                        .frame(width: 10)
                    ProviderIconView(provider: provider, font: .system(size: CGFloat(fontSize - 2)), size: CGFloat(fontSize + 2))
                        .foregroundStyle(.secondary)
                    Text(provider.displayName)
                        .font(.popup(name: fontName, size: CGFloat(fontSize - 2)))
                        .fontWeight(.medium)
                    Spacer()
                    if case .completed = state, let shortcutIndex {
                        Text("⌘\(shortcutIndex)")
                            .font(.popup(name: fontName, size: CGFloat(fontSize - 4)))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 4))
                            .help("Copy result and close")
                    }
                    switch state {
                    case .loading:
                        ProgressView().controlSize(.mini)
                    case .completed:
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                    case .error:
                        Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.red)
                    }
                }
                .font(.system(size: CGFloat(fontSize - 2)))
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .background { InteractiveMarker() }

            if isExpanded {
                Divider().padding(.horizontal, 8)
                VStack(alignment: .leading, spacing: 4) {
                    switch state {
                    case .loading:
                        Text("Looking up…").foregroundStyle(.secondary)
                    case let .completed(result):
                        WordLookupResultView(result: result)
                            .textSelection(.enabled)
                        HStack {
                            Spacer()
                            Button {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(result.plainText, forType: .string)
                            } label: {
                                Label("Copy", systemImage: "doc.on.doc")
                                    .font(.popup(name: fontName, size: CGFloat(fontSize - 2)))
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.mini)
                        }
                    case let .error(message):
                        Label(message, systemImage: "exclamationmark.triangle").foregroundStyle(.red)
                    }
                }
                .font(.popup(name: fontName, size: CGFloat(fontSize)))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background { InteractiveMarker() }
            }
        }
        .background(Color.primary.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay {
            RoundedRectangle(cornerRadius: 6).stroke(Color.primary.opacity(0.06), lineWidth: 0.5)
        }
    }
}

/// 按参考图顺序展示条目；模型文本只作为纯文本渲染。
private struct WordLookupResultView: View {
    let result: WordLookupResult

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(result.word).fontWeight(.semibold)
            Text(verbatim: "[\(result.language)] · \(result.phonetic)")
            ForEach(Array(result.meanings.enumerated()), id: \.offset) { _, meaning in
                Text(verbatim: "[\(meaning.partOfSpeech)] \(meaning.definition)")
            }
            Text("例句：")
            ForEach(Array(result.examples.enumerated()), id: \.offset) { index, example in
                Text(verbatim: "\(index + 1). \(example.sentence)（\(example.translation)）")
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
