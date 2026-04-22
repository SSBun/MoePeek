import Defaults
import SwiftUI

struct HistoryListView: View {
    let entries: [TranslationHistoryEntry]
    let onSelect: (TranslationHistoryEntry) -> Void
    @Default(.popupFontSize) private var fontSize
    @Default(.popupFontName) private var fontName

    private let contentHorizontalPadding: CGFloat = 14

    var body: some View {
        if entries.isEmpty {
            VStack {
                Spacer()
                Text("No translation history yet")
                    .font(.popup(name: fontName, size: CGFloat(fontSize)))
                    .foregroundStyle(.tertiary)
                Spacer()
            }
            .frame(maxWidth: .infinity)
        } else {
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                        HistoryRowView(
                            entry: entry,
                            index: index,
                            fontSize: fontSize,
                            fontName: fontName,
                            onSelect: { onSelect(entry) }
                        )
                    }
                }
                .padding(.horizontal, contentHorizontalPadding - 8)
                .padding(.vertical, 4)
            }
        }
    }
}

private struct HistoryRowView: View {
    let entry: TranslationHistoryEntry
    let index: Int
    let fontSize: Int
    let fontName: String
    let onSelect: () -> Void

    private var timeString: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: entry.timestamp, relativeTo: Date())
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // Text area: Button for selection
            Button(action: onSelect) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.sourceText)
                        .font(.popup(name: fontName, size: CGFloat(fontSize)))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    if let translated = entry.translatedText {
                        Text(translated)
                            .font(.popup(name: fontName, size: CGFloat(fontSize - 1)))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .multilineTextAlignment(.leading)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            // Controls
            VStack(alignment: .trailing, spacing: 4) {
                Text(timeString)
                    .font(.popup(name: fontName, size: CGFloat(fontSize - 3)))
                    .foregroundStyle(.tertiary)

                Text("⌘\(index + 1)")
                    .font(.popup(name: fontName, size: CGFloat(fontSize - 3)))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(.primary.opacity(0.03))
        )
    }
}
