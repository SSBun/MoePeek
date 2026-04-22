import Defaults
import Foundation

struct TranslationHistoryEntry: Codable, Hashable, Defaults.Serializable, Identifiable, Sendable {
    let id: String
    let sourceText: String
    let sourceLanguage: String?
    let targetLanguage: String
    let translatedText: String?
    let timestamp: Date
}

@MainActor
@Observable
final class TranslationHistoryManager {
    private static let maxEntries = 50

    var entries: [TranslationHistoryEntry] = []

    init() {
        entries = Defaults[.translationHistory]
    }

    func record(
        sourceText: String,
        sourceLanguage: String?,
        targetLanguage: String,
        translatedText: String?
    ) {
        let trimmed = sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let normalized = trimmed.lowercased()
        entries.removeAll { $0.sourceText.lowercased() == normalized }

        let entry = TranslationHistoryEntry(
            id: UUID().uuidString,
            sourceText: trimmed,
            sourceLanguage: sourceLanguage,
            targetLanguage: targetLanguage,
            translatedText: translatedText,
            timestamp: Date()
        )
        entries.insert(entry, at: 0)

        if entries.count > Self.maxEntries {
            entries.removeLast(entries.count - Self.maxEntries)
        }

        Defaults[.translationHistory] = entries
    }

    func removeAll() {
        entries.removeAll()
        Defaults[.translationHistory] = entries
    }
}
