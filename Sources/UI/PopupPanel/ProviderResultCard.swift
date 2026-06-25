import Defaults
import SwiftUI

/// A collapsible card showing a single provider's translation result.
struct ProviderResultCard: View {
    let provider: any TranslationProvider
    let state: TranslationCoordinator.ProviderState
    let shortcutIndex: Int?
    @Binding var isExpanded: Bool
    var onRetry: (() -> Void)?
    @Default(.popupFontSize) private var fontSize
    @Default(.popupFontName) private var fontName
    @Default(.capitalizeFirstLetter) private var capitalizeFirstLetter

    /// Formats text, optionally capitalizing the first letter if enabled.
    private func formatText(_ text: String) -> String {
        TextFormatter.format(text, capitalizeFirstLetter: capitalizeFirstLetter)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header — always visible
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
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

                    shortcutBadge
                    statusIndicator
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .background { InteractiveMarker() }

            // Body — visible when expanded
            if isExpanded {
                Divider()
                    .padding(.horizontal, 8)

                bodyContent
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
            }
        }
        .background(Color.primary.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.primary.opacity(0.06), lineWidth: 0.5)
        )
    }

    // MARK: - Status Indicator

    @ViewBuilder
    private var shortcutBadge: some View {
        if case .completed = state, let shortcutIndex {
            Text("⌘\(shortcutIndex)")
                .font(.popup(name: fontName, size: CGFloat(fontSize - 4)))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(Color.primary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .help("Copy result and close")
        }
    }

    @ViewBuilder
    private var statusIndicator: some View {
        switch state {
        case .waiting:
            Circle()
                .fill(.tertiary)
                .frame(width: 6, height: 6)
        case .translating:
            ProgressView()
                .controlSize(.mini)
        case .streaming:
            ProgressView()
                .controlSize(.mini)
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: CGFloat(fontSize - 2)))
                .foregroundStyle(.green)
        case .error:
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: CGFloat(fontSize - 2)))
                .foregroundStyle(.red)
        }
    }

    // MARK: - Body Content

    @ViewBuilder
    private var bodyContent: some View {
        switch state {
        case .waiting:
            Text("Waiting…")
                .font(.popup(name: fontName, size: CGFloat(fontSize)))
                .foregroundStyle(.tertiary)
        case .translating:
            Text("Translating…")
                .font(.popup(name: fontName, size: CGFloat(fontSize)))
                .foregroundStyle(.secondary)
        case let .streaming(partial):
            VStack(alignment: .leading, spacing: 4) {
                Text(formatText(partial))
                    .font(.popup(name: fontName, size: CGFloat(fontSize)))
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background { InteractiveMarker() }
        case let .completed(text):
            VStack(alignment: .leading, spacing: 4) {
                Text(formatText(text))
                    .font(.popup(name: fontName, size: CGFloat(fontSize)))
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack {
                    Spacer()
                    Button {
                        let formattedText = formatText(text)
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(formattedText, forType: .string)
                    } label: {
                        Label("Copy", systemImage: "doc.on.doc")
                            .font(.popup(name: fontName, size: CGFloat(fontSize - 2)))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                }
            }
            .background { InteractiveMarker() }
        case let .error(message):
            VStack(alignment: .leading, spacing: 4) {
                Label(message, systemImage: "exclamationmark.triangle")
                    .font(.popup(name: fontName, size: CGFloat(fontSize)))
                    .foregroundStyle(.red)

                if let onRetry {
                    HStack {
                        Spacer()
                        Button(action: onRetry) {
                            Label("Retry", systemImage: "arrow.clockwise")
                                .font(.popup(name: fontName, size: CGFloat(fontSize - 2)))
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.mini)
                    }
                }
            }
            .background { InteractiveMarker() }
        }
    }
}
