import Foundation

/// 用于 Writing tutor 展示的结构化解析结果，不包含界面装饰或原始响应。
struct ParsingResult: Decodable, Equatable, Sendable {
    struct Word: Decodable, Equatable, Sendable {
        let word: String
        let note: String
    }

    struct Grammar: Decodable, Equatable, Sendable {
        let structure: String
        let note: String
    }

    let correctedText: String
    let naturalExpression: String?
    let notice: String?
    let words: [Word]
    let grammar: [Grammar]

    /// 解码完整 JSON（兼容包裹整个对象的 Markdown 围栏），拒绝缺少必要内容的结果。
    static func decode(_ response: String) -> ParsingResult? {
        var json = response.trimmingCharacters(in: .whitespacesAndNewlines)
        if json.hasPrefix("```") {
            let lines = json.components(separatedBy: .newlines)
            guard let first = lines.first?.lowercased(),
                  first == "```json" || first == "```",
                  lines.last == "```", lines.count >= 3 else { return nil }
            json = lines.dropFirst().dropLast().joined(separator: "\n")
        }
        guard let data = json.data(using: .utf8),
              let result = try? JSONDecoder().decode(ParsingResult.self, from: data) else { return nil }
        let corrected = result.correctedText.trimmingCharacters(in: .whitespacesAndNewlines)
        let natural = result.naturalExpression?.trimmingCharacters(in: .whitespacesAndNewlines)
        let notice = result.notice?.trimmingCharacters(in: .whitespacesAndNewlines)
        let words = result.words.map {
            Word(word: $0.word.trimmingCharacters(in: .whitespacesAndNewlines),
                 note: $0.note.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        let grammar = result.grammar.map {
            Grammar(structure: $0.structure.trimmingCharacters(in: .whitespacesAndNewlines),
                    note: $0.note.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        guard words.allSatisfy({ !$0.word.isEmpty && !$0.note.isEmpty }),
              grammar.allSatisfy({ !$0.structure.isEmpty && !$0.note.isEmpty }) else { return nil }
        let naturalExpression = natural.flatMap { $0.isEmpty || $0 == corrected ? nil : $0 }
        let message = notice.flatMap { $0.isEmpty ? nil : $0 }
        if corrected.isEmpty {
            guard message != nil, naturalExpression == nil, words.isEmpty, grammar.isEmpty else { return nil }
        }
        return ParsingResult(correctedText: corrected, naturalExpression: naturalExpression, notice: message, words: words, grammar: grammar)
    }

    /// 回填仅使用英文自然表达或正文，不包含讲解及界面标题。
    var pasteText: String? {
        let text = naturalExpression ?? correctedText
        return text.isEmpty ? nil : text
    }

    /// 复制用的纯文本，保留全部解析内容但不复制 JSON；复杂度 O(结果字符总数)。
    var plainText: String {
        var sections: [String] = []
        if !correctedText.isEmpty { sections.append(correctedText) }
        if let notice { sections.append(notice) }
        if let naturalExpression { sections.append("Natural expression\n" + naturalExpression) }
        if !words.isEmpty {
            sections.append("Words\n" + words.map { "\($0.word)  \($0.note)" }.joined(separator: "\n"))
        }
        if !grammar.isEmpty {
            sections.append("Grammar\n" + grammar.map { "\($0.structure)  \($0.note)" }.joined(separator: "\n"))
        }
        return sections.joined(separator: "\n\n")
    }
}
