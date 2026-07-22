import NaturalLanguage

struct DetectionResult: Sendable {
    let language: String?
    let confidence: Double
    let isReliable: Bool
}

enum LanguageDetector {
    // Supported NLLanguage list matching SupportedLanguages.all (14 languages)
    private static let supportedNLLanguages: [NLLanguage] = [
        .english, .simplifiedChinese, .traditionalChinese, .japanese,
        .korean, .french, .german, .spanish, .portuguese, .russian,
        .arabic, .italian, .thai, .vietnamese,
    ]

    // Base language weight hints (inspired by Easydict, simplified)
    private static let baseHints: [NLLanguage: Double] = [
        .english: 2.0,
        .simplifiedChinese: 1.5,
        .traditionalChinese: 0.8,
        .japanese: 0.6,
        .korean: 0.5,
        .french: 0.4, .spanish: 0.4, .italian: 0.4,
        .portuguese: 0.3, .german: 0.3, .russian: 0.3,
        .arabic: 0.2, .thai: 0.2, .vietnamese: 0.2,
    ]

    /// Backward-compatible simple API.
    static func detect(_ text: String) -> String? {
        detectWithConfidence(text, threshold: 0.3).language
    }

    /// Full detection API with confidence and alternatives.
    /// `preferredSourceHints` uses BCP 47 codes as keys (e.g. "en", "zh-Hans").
    static func detectWithConfidence(
        _ text: String,
        threshold: Double = 0.3,
        preferredSourceHints: [String: Double]? = nil
    ) -> DetectionResult {
        let recognizer = NLLanguageRecognizer()
        recognizer.languageConstraints = supportedNLLanguages

        // Merge base hints + user preference hints
        var hints = baseHints
        if let extra = preferredSourceHints {
            for (code, weight) in extra {
                if let nlLang = bcp47ToNLLanguage(code) {
                    hints[nlLang, default: 0] += weight
                }
            }
        }
        recognizer.languageHints = hints

        recognizer.processString(text)

        let hypotheses = recognizer.languageHypotheses(withMaximum: 5)
        let sorted = hypotheses
            .map { (language: mapToBCP47($0.key), confidence: $0.value) }
            .sorted { $0.confidence > $1.confidence }

        guard let best = sorted.first else {
            return DetectionResult(language: nil, confidence: 0, isReliable: false)
        }

        // Hard override: NLLanguageRecognizer's statistical model overpowers hints for
        // mixed CJK+Latin text (e.g. "选中所有checkbox" detects as English at 0.89).
        // CJK characters are a deterministic signal — if present, the source is CJK.
        if !isCJKLanguage(best.language), let cjkLang = dominantCJKLanguage(text) {
            return DetectionResult(language: cjkLang, confidence: best.confidence, isReliable: true)
        }

        // Use higher threshold for very short text
        let effectiveThreshold = text.count <= 5
            ? max(threshold, 0.5)
            : threshold

        let isReliable = best.confidence >= effectiveThreshold

        return DetectionResult(
            language: isReliable ? best.language : nil,
            confidence: best.confidence,
            isReliable: isReliable
        )
    }

    private static func bcp47ToNLLanguage(_ code: String) -> NLLanguage? {
        switch code {
        case "zh-Hans": return .simplifiedChinese
        case "zh-Hant": return .traditionalChinese
        case "pt-BR": return .portuguese
        default: return NLLanguage(rawValue: code)
        }
    }

    private static func mapToBCP47(_ language: NLLanguage) -> String {
        switch language {
        case .simplifiedChinese: return "zh-Hans"
        case .traditionalChinese: return "zh-Hant"
        case .portuguese: return "pt-BR"
        default: return language.rawValue
        }
    }

    private static func isCJKLanguage(_ code: String) -> Bool {
        code.hasPrefix("zh") || code == "ja" || code == "ko"
    }

    // ponytail: CJK ideographs credited to zh-Hans only; pure-kanji Japanese could
    // lean Chinese — widen to a shared zh/ja bucket if reported
    private static func dominantCJKLanguage(_ text: String) -> String? {
        var hasIdeograph = false
        var hasKana = false
        var hasHangul = false
        for scalar in text.unicodeScalars {
            switch scalar.value {
            case 0x4E00...0x9FFF: hasIdeograph = true
            case 0x3040...0x309F, 0x30A0...0x30FF: hasKana = true
            case 0xAC00...0xD7AF: hasHangul = true
            default: break
            }
        }
        if hasHangul { return "ko" }
        if hasKana { return "ja" }
        if hasIdeograph { return "zh-Hans" }
        return nil
    }
}
