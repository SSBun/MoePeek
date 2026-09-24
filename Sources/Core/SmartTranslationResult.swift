import Foundation

/// 智能模式的最终结果；句子部分保留原有 ParsingResult，不重写解析语义。
enum SmartTranslationResult: Equatable, Sendable {
    /// 一个英文词条，或两个中文词语的英文候选。
    case words([Entry])
    /// 可选中文译文后紧接原解析结果。
    case sentence(translation: String?, parsing: ParsingResult)
    /// 输入不适合词典或句子解析。
    case skip

    struct Entry: Codable, Equatable, Sendable {
        struct Meaning: Codable, Equatable, Sendable {
            let partOfSpeech: String
            let definition: String
        }

        struct Example: Codable, Equatable, Sendable {
            let sentence: String
            let translation: String
        }

        let word: String
        let phonetic: String
        let meanings: [Meaning]
        let usage: String?
        let examples: [Example]

        /// 完整词条必须含词性、释义和三组非空双语例句；复杂度 O(字段总字符数)。
        var isValid: Bool {
            guard !meanings.isEmpty, examples.count == 3 else { return false }
            let fields = [word, phonetic]
                + meanings.flatMap { [$0.partOfSpeech, $0.definition] }
                + examples.flatMap { [$0.sentence, $0.translation] }
            return fields.allSatisfy { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        }

        /// 与紧凑词条内容一致的复制文本；复杂度 O(词条字符数)。
        var plainText: String {
            var lines = ["\(word)  \(phonetic)"]
            lines += meanings.map { "[\($0.partOfSpeech)] \($0.definition)" }
            if let usage, !usage.isEmpty { lines.append(usage) }
            lines += examples.enumerated().map { index, example in
                "\(index + 1). \(example.sentence)\n\(example.translation)"
            }
            return lines.joined(separator: "\n")
        }
    }

    /// 复制全部可见内容，不包含展示标签；复杂度 O(结果字符数)。
    var plainText: String {
        switch self {
        case let .words(entries): entries.map(\.plainText).joined(separator: "\n\n")
        case let .sentence(translation, parsing):
            [translation, parsing.plainText].compactMap { $0 }.joined(separator: "\n\n")
        case .skip: String(localized: "Enter an English or Chinese word or sentence to translate.")
        }
    }

    /// 只有句子结果参与原有英文回填，词条通过复制操作取出。
    func pasteText(for source: String) -> String? {
        guard case let .sentence(_, parsing) = self else { return nil }
        return parsing.pasteText(for: source)
    }
}

/// 首次请求只分类并生成词典或中文译文；句子解析必须走原有 parsing 请求。
enum SmartTranslationRoute: Decodable {
    /// 单个英文词条或词典短语。
    case englishWord(SmartTranslationResult.Entry)
    /// 两个不同的英文候选，均有用法说明。
    case chineseWord([SmartTranslationResult.Entry])
    /// 英文句子的中文译文，后续仍需解析原英文输入。
    case englishSentence(String)
    /// 中文句子，后续直接采用原解析服务。
    case chineseSentence
    /// 不支持的语言、代码或无法分析的输入。
    case skip

    private enum CodingKeys: String, CodingKey {
        case mode, entry, candidates, translation
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(String.self, forKey: .mode) {
        case "englishWord":
            let entry = try container.decode(SmartTranslationResult.Entry.self, forKey: .entry)
            guard entry.isValid else {
                throw DecodingError.dataCorruptedError(forKey: .entry, in: container, debugDescription: "Incomplete dictionary entry")
            }
            self = .englishWord(entry)
        case "chineseWord":
            let entries = try container.decode([SmartTranslationResult.Entry].self, forKey: .candidates)
            guard entries.count == 2,
                  entries.allSatisfy({ $0.isValid && !($0.usage ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }),
                  Set(entries.map { $0.word.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }).count == 2 else {
                throw DecodingError.dataCorruptedError(forKey: .candidates, in: container, debugDescription: "Expected two distinct complete candidates")
            }
            self = .chineseWord(entries)
        case "englishSentence":
            let translation = try container.decode(String.self, forKey: .translation).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !translation.isEmpty else {
                throw DecodingError.dataCorruptedError(forKey: .translation, in: container, debugDescription: "Empty Chinese translation")
            }
            self = .englishSentence(translation)
        case "chineseSentence": self = .chineseSentence
        case "skip": self = .skip
        default:
            throw DecodingError.dataCorruptedError(forKey: .mode, in: container, debugDescription: "Unknown smart translation mode")
        }
    }

    /// 仅接受完整 JSON 或完整 JSON 代码围栏，任何缺失字段均返回失败。
    static func decode(_ response: String) -> Self? {
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
}
