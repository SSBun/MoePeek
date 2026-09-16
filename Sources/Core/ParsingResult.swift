import Foundation

/// 与 Perch 一致的 check/tutor/skip 结果；JSON 使用显式 mode 区分字段。
enum ParsingResult: Codable, Equatable, Sendable {
    struct Correction: Codable, Equatable, Sendable {
        let wrong: String
        let right: String
        let reason: String
    }

    struct Word: Codable, Equatable, Sendable {
        let word: String
        let note: String
    }

    struct Grammar: Codable, Equatable, Sendable {
        let structure: String
        let note: String
    }

    /// 英文检查，只包含真实纠错及必要的可选改写。
    case check(items: [Correction], rephrase: String?)
    /// 非英文输入的一份自然英文表达及讲解。
    case tutor(sentence: String, words: [Word], grammar: [Grammar])
    /// 内容不适合语言分析，不提供回填正文。
    case skip

    private enum CodingKeys: String, CodingKey {
        case mode, items, rephrase, sentence, words, grammar
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(String.self, forKey: .mode) {
        case "check":
            let items = try container.decode([Correction].self, forKey: .items)
            guard items.allSatisfy({ !$0.wrong.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !$0.right.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
                throw DecodingError.dataCorruptedError(forKey: .items, in: container, debugDescription: "Empty correction fragment")
            }
            let rephrase = try container.decodeIfPresent(String.self, forKey: .rephrase)?.trimmingCharacters(in: .whitespacesAndNewlines)
            self = .check(items: Array(items.prefix(5)), rephrase: rephrase.flatMap { $0.isEmpty ? nil : $0 })
        case "tutor":
            let sentence = try container.decode(String.self, forKey: .sentence).trimmingCharacters(in: .whitespacesAndNewlines)
            let words = try container.decode([Word].self, forKey: .words)
            let grammar = try container.decode([Grammar].self, forKey: .grammar)
            guard !sentence.isEmpty,
                  words.allSatisfy({ !$0.word.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !$0.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }),
                  grammar.allSatisfy({ !$0.structure.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !$0.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
                throw DecodingError.dataCorruptedError(forKey: .sentence, in: container, debugDescription: "Incomplete tutor result")
            }
            self = .tutor(sentence: sentence, words: Array(words.prefix(5)), grammar: Array(grammar.prefix(3)))
        case "skip":
            self = .skip
        default:
            throw DecodingError.dataCorruptedError(forKey: .mode, in: container, debugDescription: "Unknown parsing mode")
        }
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .check(items, rephrase):
            try container.encode("check", forKey: .mode)
            try container.encode(items, forKey: .items)
            if let rephrase { try container.encode(rephrase, forKey: .rephrase) }
            else { try container.encodeNil(forKey: .rephrase) }
        case let .tutor(sentence, words, grammar):
            try container.encode("tutor", forKey: .mode)
            try container.encode(sentence, forKey: .sentence)
            try container.encode(words, forKey: .words)
            try container.encode(grammar, forKey: .grammar)
        case .skip:
            try container.encode("skip", forKey: .mode)
        }
    }

    /// 保留对完整 Markdown JSON 围栏的兼容；不把无效结果默认为无错或跳过。
    static func decode(_ response: String) -> ParsingResult? {
        var json = response.trimmingCharacters(in: .whitespacesAndNewlines)
        if json.hasPrefix("```") {
            let lines = json.components(separatedBy: .newlines)
            guard let first = lines.first?.lowercased(), first == "```json" || first == "```",
                  lines.last == "```", lines.count >= 3 else { return nil }
            json = lines.dropFirst().dropLast().joined(separator: "\n")
        }
        guard let data = json.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(Self.self, from: data)
    }

    /// 与 Perch 正文复制相同：优先改写，否则仅应用唯一、不重叠的精确纠错；复杂度 O(原文长度 × 纠错项数)。
    func pasteText(for sourceText: String) -> String? {
        switch self {
        case let .tutor(sentence, _, _): return sentence
        case .skip: return nil
        case let .check(items, rephrase):
            if let rephrase { return rephrase }
            let source = sourceText as NSString
            var replacements: [(range: NSRange, text: String)] = []
            for item in items {
                guard !item.wrong.isEmpty else { return nil }
                let range = source.range(of: item.wrong, options: .literal)
                guard range.location != NSNotFound else { return nil }
                let remainder = NSRange(location: range.location + 1, length: source.length - range.location - 1)
                guard source.range(of: item.wrong, options: .literal, range: remainder).location == NSNotFound,
                      !replacements.contains(where: { NSIntersectionRange($0.range, range).length > 0 }) else { return nil }
                replacements.append((range, item.right))
            }
            let corrected = NSMutableString(string: sourceText)
            for replacement in replacements.sorted(by: { $0.range.location > $1.range.location }) {
                corrected.replaceCharacters(in: replacement.range, with: replacement.text)
            }
            return corrected.length == 0 ? nil : corrected as String
        }
    }

    /// 全部可见解析内容的纯文本，用于右键复制；复杂度 O(结果字符总数)。
    var plainText: String {
        switch self {
        case let .check(items, rephrase):
            var sections = items.map { "\($0.wrong) → \($0.right)\n\($0.reason)" }
            if let rephrase { sections.append(rephrase) }
            return sections.isEmpty ? "表达自然，无需修改。" : sections.joined(separator: "\n\n")
        case let .tutor(sentence, words, grammar):
            var sections = [sentence]
            if !words.isEmpty { sections.append("Words\n" + words.map { "\($0.word)  \($0.note)" }.joined(separator: "\n")) }
            if !grammar.isEmpty { sections.append("Grammar\n" + grammar.map { "\($0.structure)  \($0.note)" }.joined(separator: "\n")) }
            return sections.joined(separator: "\n\n")
        case .skip:
            return "内容过短、代码较多或不适合语言分析。"
        }
    }
}
