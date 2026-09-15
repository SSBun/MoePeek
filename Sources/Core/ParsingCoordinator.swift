import Defaults
import Foundation

/// 独立解析会话；只共享服务注册表，不读写翻译会话或翻译历史。
@MainActor
@Observable
final class ParsingCoordinator {
    enum ProviderState: Sendable, Equatable {
        /// 已排队，尚未开始请求。
        case waiting
        /// 已开始解析，等待完整结构化结果；不展示中间 JSON。
        case parsing
        /// 已取得并验证完整解析结果，可按字段呈现。
        case completed(ParsingResult)
        /// 当前服务解析失败。
        case error(String)
    }

    enum EnterAction {
        /// 新输入或上次失败，需要解析。
        case parse
        /// 当前输入仍在解析，不重复提交。
        case wait
        /// 当前输入已有可回填正文。
        case paste(String)
        /// 已完成但只有提示，没有英文正文。
        case noContent
    }

    private(set) var activeSlots: [any TranslationProvider] = []
    private(set) var providerStates: [String: ProviderState] = [:]
    private(set) var globalError: String?
    /// 解析专用选择；变更时保存并立即取消旧会话，空值保留原有跟随行为。
    var selectedProviderID: String {
        didSet {
            guard selectedProviderID != oldValue else { return }
            Defaults[.parsingProviderID] = selectedProviderID
            reset()
        }
    }

    /// 基础设置中的解析说明语言，空值沿用翻译目标语言。
    var selectedExplanationLanguage: String {
        didSet {
            guard selectedExplanationLanguage != oldValue else { return }
            Defaults[.parsingExplanationLanguage] = selectedExplanationLanguage
            reset()
        }
    }

    /// 可独立选择的解析服务，包含未启用为翻译服务的 LLM；复杂度 O(n)。
    var availableProviders: [any TranslationProvider] {
        registry.providers.filter(\.supportsParsing)
    }

    private let registry: TranslationProviderRegistry
    private var tasks: [String: Task<Void, Never>] = [:]
    private var generation = 0
    private var submittedText: String?

    init(registry: TranslationProviderRegistry) {
        self.registry = registry
        selectedProviderID = Defaults[.parsingProviderID]
        selectedExplanationLanguage = Defaults[.parsingExplanationLanguage]
    }

    /// 仅处理新面板明确提交的文本，不读取辅助功能控件或剪贴板。
    func parse(_ text: String) {
        reset()
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            globalError = String(localized: "Empty text")
            return
        }
        submittedText = text
        let sourceLanguage = LanguageDetector.detectWithConfidence(
            text,
            threshold: Defaults[.detectionConfidenceThreshold]
        ).language
        let explanationLanguage = selectedExplanationLanguage.isEmpty
            ? Defaults[.targetLanguage]
            : selectedExplanationLanguage
        if selectedProviderID.isEmpty {
            activeSlots = registry.enabledSlots.filter(\.supportsParsing)
        } else {
            guard let provider = registry.provider(withID: selectedProviderID), provider.supportsParsing else {
                globalError = String(localized: "Selected parsing provider is unavailable. Choose another provider.")
                return
            }
            activeSlots = registry.modelSlots(for: provider)
        }
        guard !activeSlots.isEmpty else {
            globalError = String(localized: "Parsing requires an enabled LLM provider. Enable one in Settings.")
            return
        }
        for provider in activeSlots {
            start(provider, text: text, source: sourceLanguage, language: explanationLanguage)
        }
    }

    /// 仅选择与当前输入匹配的完成结果；优先顺序与面板中的服务顺序一致。
    func enterAction(for text: String) -> EnterAction {
        guard submittedText == text.trimmingCharacters(in: .whitespacesAndNewlines) else { return .parse }
        for provider in activeSlots {
            if case let .completed(result) = providerStates[provider.id], let text = result.pasteText {
                return .paste(text)
            }
        }
        if providerStates.values.contains(where: {
            switch $0 {
            case .waiting, .parsing: true
            default: false
            }
        }) { return .wait }
        if providerStates.values.contains(where: {
            if case .completed = $0 { return true }
            return false
        }) { return .noContent }
        return .parse
    }

    /// 回填失败时保留已有正文，便于用户手动复制。
    func showPasteFailure(_ message: String) {
        globalError = message
    }

    /// 关闭面板或改变说明语言时，仅取消本解析会话。
    func reset() {
        generation += 1
        for task in tasks.values { task.cancel() }
        tasks.removeAll()
        activeSlots = []
        providerStates = [:]
        globalError = nil
        submittedText = nil
    }

    private func start(_ provider: any TranslationProvider, text: String, source: String?, language: String) {
        let generation = generation
        providerStates[provider.id] = .waiting
        tasks[provider.id] = Task { [weak self] in
            guard let self else { return }
            await self.run(provider, text: text, source: source, language: language, generation: generation)
        }
    }

    private func run(
        _ provider: any TranslationProvider,
        text: String,
        source: String?,
        language: String,
        generation: Int
    ) async {
        guard !Task.isCancelled, generation == self.generation else { return }
        defer {
            if !Task.isCancelled, generation == self.generation {
                tasks.removeValue(forKey: provider.id)
            }
        }
        providerStates[provider.id] = .parsing
        do {
            var content = ""
            for try await chunk in provider.processStream(text, from: source, to: language, mode: .parsing, model: nil) {
                guard !Task.isCancelled, generation == self.generation else { return }
                guard !chunk.isEmpty else { continue }
                content += chunk
            }
            guard !Task.isCancelled, generation == self.generation else { return }
            if content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                providerStates[provider.id] = .error(String(localized: "Parsing returned empty result"))
            } else if let result = ParsingResult.decode(content) {
                providerStates[provider.id] = .completed(result)
            } else {
                providerStates[provider.id] = .error(String(localized: "Parsing returned an invalid result format. Please submit again."))
            }
        } catch {
            guard !Task.isCancelled, generation == self.generation else { return }
            providerStates[provider.id] = .error(error.localizedDescription)
        }
    }
}
