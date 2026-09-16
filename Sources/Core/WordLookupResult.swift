import Foundation

/// 单词翻译的完整字典条目，与句子解析和翻译结果相互独立。
struct WordLookupResult: Decodable, Equatable, Sendable {
    struct Meaning: Decodable, Equatable, Sendable {
        let partOfSpeech: String
        let definition: String
    }

    struct Example: Decodable, Equatable, Sendable {
        let sentence: String
        let translation: String
    }

    let word: String
    let language: String
    let phonetic: String
    let meanings: [Meaning]
    let examples: [Example]

    /// 仅接收完整条目与三组双语例句，不展示中间 JSON 或缺失字段的结果。
    static func decode(_ response: String) -> WordLookupResult? {
        var json = response.trimmingCharacters(in: .whitespacesAndNewlines)
        if json.hasPrefix("```") {
            let lines = json.components(separatedBy: .newlines)
            guard let first = lines.first?.lowercased(), first == "```json" || first == "```",
                  lines.last == "```", lines.count >= 3 else { return nil }
            json = lines.dropFirst().dropLast().joined(separator: "\n")
        }
        guard let data = json.data(using: .utf8),
              let result = try? JSONDecoder().decode(Self.self, from: data),
              !result.meanings.isEmpty, result.examples.count == 3 else { return nil }
        let fields = [result.word, result.language, result.phonetic]
            + result.meanings.flatMap { [$0.partOfSpeech, $0.definition] }
            + result.examples.flatMap { [$0.sentence, $0.translation] }
        guard fields.allSatisfy({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else { return nil }
        return result
    }

    /// 与卡片相同的纯文本内容，用于复制；复杂度 O(结果字符总数)。
    var plainText: String {
        var lines = [word, "[\(language)] · \(phonetic)"]
        lines += meanings.map { "[\($0.partOfSpeech)] \($0.definition)" }
        lines.append("例句：")
        lines += examples.enumerated().map { index, example in
            "\(index + 1). \(example.sentence)（\(example.translation)）"
        }
        return lines.joined(separator: "\n")
    }
}
