import Defaults
import Foundation
import Observation

/// 独立智能会话：语义路由后处理词条，或复用原解析协议处理句子。
@MainActor
@Observable
final class SmartTranslationCoordinator {
    enum ProviderState: Equatable {
        /// 正在分类、查询或解析，不展示中间 JSON。
        case loading
        /// 完整且已验证的结果。
        case completed(SmartTranslationResult)
        /// 当前服务失败，可重新提交。
        case error(String)
    }

    enum EnterAction {
        /// 新输入或失败后的重试。
        case process
        /// 请求仍在执行，无需重复请求。
        case wait
        /// 已完成结果含可复制的英文词语或句子。
        case copy(String)
        /// 仅有提示，没有英文正文。
        case noContent
    }

    private(set) var activeSlots: [any TranslationProvider] = []
    private(set) var providerStates: [String: ProviderState] = [:]
    private(set) var globalError: String?
    private(set) var historyError: String?
    var selectedProviderID: String {
        didSet {
            guard selectedProviderID != oldValue else { return }
            Defaults[.smartTranslationProviderID] = selectedProviderID
            reset()
        }
    }

    /// 智能模式要求同一服务支持路由和原有解析；复杂度 O(服务数)。
    var availableProviders: [any TranslationProvider] {
        registry.providers.filter { $0.supportsSmartTranslation && $0.supportsParsing }
    }

    private let registry: TranslationProviderRegistry
    private let historyStore: ParsingHistoryStore
    private var tasks: [String: Task<Void, Never>] = [:]
    private var generation = 0
    /// 当前结果对应的提交原文，供面板生成完整纠正句。
    private(set) var submittedText: String?

    init(registry: TranslationProviderRegistry, historyStore: ParsingHistoryStore) {
        self.registry = registry
        self.historyStore = historyStore
        selectedProviderID = Defaults[.smartTranslationProviderID]
    }

    /// 仅提交当前输入；每个服务独立返回一种完整结果，不修改普通翻译或解析会话。
    func process(_ text: String) {
        reset()
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            globalError = String(localized: "Empty text")
            return
        }
        submittedText = text
        if selectedProviderID.isEmpty {
            activeSlots = registry.enabledSlots.filter { $0.supportsSmartTranslation && $0.supportsParsing }
        } else {
            guard let provider = registry.provider(withID: selectedProviderID),
                  provider.supportsSmartTranslation, provider.supportsParsing else {
                globalError = String(localized: "Selected smart translation provider is unavailable. Choose another provider in Settings.")
                return
            }
            activeSlots = registry.modelSlots(for: provider)
        }
        guard !activeSlots.isEmpty else {
            globalError = String(localized: "Smart translation requires an LLM provider. Choose one in Settings.")
            return
        }
        let source = LanguageDetector.detectWithConfidence(text, threshold: Defaults[.detectionConfidenceThreshold]).language
        let language = Defaults[.parsingExplanationLanguage].isEmpty ? Defaults[.targetLanguage] : Defaults[.parsingExplanationLanguage]
        let generation = generation
        for provider in activeSlots {
            let model: String?
            if let slot = provider as? ModelSlotProvider {
                model = slot.modelOverride
            } else if let provider = provider as? any ParallelModelProvider {
                model = Defaults[provider.modelKey]
            } else {
                model = nil
            }
            providerStates[provider.id] = .loading
            tasks[provider.id] = Task { [weak self] in
                guard let self else { return }
                await self.run(provider, text: text, source: source, language: language, model: model, generation: generation)
            }
        }
    }

    /// 复制当前输入的已完成英文结果，词条和句子使用相同回车入口。
    func enterAction(for text: String) -> EnterAction {
        guard let submittedText, submittedText == text.trimmingCharacters(in: .whitespacesAndNewlines) else { return .process }
        for provider in activeSlots {
            if case let .completed(result) = providerStates[provider.id], let text = result.pasteText(for: submittedText) {
                return .copy(text)
            }
        }
        if providerStates.values.contains(where: {
            if case .loading = $0 { return true }
            return false
        }) { return .wait }
        // 没有可复制结果且所有请求结束后，允许失败服务重试。
        if providerStates.values.contains(where: {
            if case .error = $0 { return true }
            return false
        }) { return .process }
        if providerStates.values.contains(where: {
            if case .completed = $0 { return true }
            return false
        }) { return .noContent }
        return .process
    }

    func showCopyFailure(_ message: String) {
        globalError = message
    }

    /// 关闭、编辑或切换服务时取消请求，隔离迟到的分类与解析结果。
    func reset() {
        generation += 1
        for task in tasks.values { task.cancel() }
        tasks.removeAll()
        activeSlots = []
        providerStates = [:]
        globalError = nil
        historyError = nil
        submittedText = nil
    }

    private func run(
        _ provider: any TranslationProvider,
        text: String,
        source: String?,
        language: String,
        model: String?,
        generation: Int
    ) async {
        guard !Task.isCancelled, generation == self.generation else { return }
        defer {
            if generation == self.generation { tasks.removeValue(forKey: provider.id) }
        }
        do {
            let response = try await collect(provider, text: text, source: source, language: language, mode: .smartTranslation, model: model)
            guard !Task.isCancelled, generation == self.generation else { return }
            guard let route = SmartTranslationRoute.decode(response) else { throw SmartTranslationError.invalidResult }
            let result: SmartTranslationResult
            switch route {
            case let .englishWord(entry): result = .words([entry])
            case let .chineseWord(entries): result = .words(entries)
            case .skip: result = .skip
            case .englishSentence, .chineseSentence:
                let translation: String?
                if case let .englishSentence(value) = route { translation = value } else { translation = nil }
                let content = try await collect(provider, text: text, source: source, language: language, mode: .parsing, model: model)
                guard !Task.isCancelled, generation == self.generation else { return }
                guard let parsing = ParsingResult.decode(content) else { throw SmartTranslationError.invalidResult }
                result = .sentence(translation: translation, parsing: parsing)
            }
            // 已完成的词条和解析独立保存，关闭面板不取消落盘。
            let completedAt = Date()
            let providerName = provider.displayName
            let providerID = provider.id
            let save = Task<URL?, Error> { [historyStore] in
                switch result {
                case let .words(entries):
                    return try await historyStore.append(
                        sourceText: text, words: entries, providerName: providerName,
                        providerID: providerID, model: model, date: completedAt
                    )
                case let .sentence(_, parsing):
                    return try await historyStore.append(
                        sourceText: text, result: parsing, providerName: providerName,
                        providerID: providerID, model: model, date: completedAt
                    )
                case .skip:
                    return nil
                }
            }
            do {
                _ = try await save.value
            } catch {
                if !Task.isCancelled, generation == self.generation {
                    historyError = String(localized: "Could not save parsing history. The result is still available; copy it before closing.")
                }
            }
            guard !Task.isCancelled, generation == self.generation else { return }
            providerStates[provider.id] = .completed(result)
        } catch {
            guard !Task.isCancelled, generation == self.generation else { return }
            providerStates[provider.id] = .error(error.localizedDescription)
        }
    }

    /// 有界收集完整结果；消费取消会终止 Provider 的底层流任务。
    private func collect(
        _ provider: any TranslationProvider,
        text: String,
        source: String?,
        language: String,
        mode: TextProcessingMode,
        model: String?
    ) async throws -> String {
        var content = ""
        for try await chunk in provider.processStream(text, from: source, to: language, mode: mode, model: model) {
            try Task.checkCancellation()
            content += chunk
            guard content.utf8.count <= 65_536 else { throw SmartTranslationError.invalidResult }
        }
        try Task.checkCancellation()
        return content
    }
}

private enum SmartTranslationError: LocalizedError {
    /// 无效或超过大小限制的模型输出。
    case invalidResult

    var errorDescription: String? {
        String(localized: "Smart translation returned an invalid result. Please try again.")
    }
}
