import AppKit
import Defaults
import Foundation
import OSLog

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
    private(set) var historyError: String?
    let historyStore: ParsingHistoryStore
    let historyServer: ParsingHistoryServer
    private static let logger = Logger(subsystem: "com.nahida.MoePeek", category: "ParsingHistory")
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
    /// 当前结果对应的提交原文，供面板生成完整纠正句；不随未提交草稿变化。
    private(set) var submittedText: String?

    init(registry: TranslationProviderRegistry, historyStore: ParsingHistoryStore = ParsingHistoryStore()) {
        self.registry = registry
        self.historyStore = historyStore
        historyServer = ParsingHistoryServer(store: historyStore)
        selectedProviderID = Defaults[.parsingProviderID]
        selectedExplanationLanguage = Defaults[.parsingExplanationLanguage]
    }

    /// 随应用启动本机复习服务，不打开浏览器；失败后仍可通过复习入口重试。
    func startHistoryService() {
        Task { [weak self] in
            guard let self else { return }
            do {
                _ = try await self.historyServer.start()
                Self.logger.info("reviewService.started")
            } catch {
                Self.logger.error("reviewService.start.failed")
            }
        }
    }

    /// 在系统浏览器中打开本地学习页，启动失败时提供可见反馈。
    func openHistory() {
        Task { [weak self] in
            guard let self else { return }
            do {
                let url = try await self.historyServer.start()
                guard NSWorkspace.shared.open(url) else { throw CocoaError(.featureUnsupported) }
            } catch {
                let alert = NSAlert()
                alert.messageText = String(localized: "Could not open parsing review.")
                alert.informativeText = String(localized: "Please try again. Your saved parsing history has not been changed.")
                alert.runModal()
            }
        }
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
        guard let submittedText, submittedText == text.trimmingCharacters(in: .whitespacesAndNewlines) else { return .parse }
        for provider in activeSlots {
            if case let .completed(result) = providerStates[provider.id], let text = result.pasteText(for: submittedText) {
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
        historyError = nil
        submittedText = nil
    }

    private func start(_ provider: any TranslationProvider, text: String, source: String?, language: String) {
        // 同一快照同时用于请求与历史，不能在结果完成后重读已变化的偏好。
        let model: String?
        if let slot = provider as? ModelSlotProvider {
            model = slot.modelOverride
        } else if let provider = provider as? any ParallelModelProvider {
            model = Defaults[provider.modelKey]
        } else {
            model = nil
        }
        let generation = generation
        providerStates[provider.id] = .waiting
        tasks[provider.id] = Task { [weak self] in
            guard let self else { return }
            await self.run(provider, text: text, source: source, language: language, model: model, generation: generation)
        }
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
            if !Task.isCancelled, generation == self.generation {
                tasks.removeValue(forKey: provider.id)
            }
        }
        providerStates[provider.id] = .parsing
        do {
            var content = ""
            for try await chunk in provider.processStream(text, from: source, to: language, mode: .parsing, model: model) {
                guard !Task.isCancelled, generation == self.generation else { return }
                guard !chunk.isEmpty else { continue }
                content += chunk
            }
            guard !Task.isCancelled, generation == self.generation else { return }
            if content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                providerStates[provider.id] = .error(String(localized: "Parsing returned empty result"))
            } else if let result = ParsingResult.decode(content) {
                let completedAt = Date()
                let providerName = provider.displayName
                let providerID = provider.id
                // 完整结果的保存拥有独立生命周期，不加入 reset() 取消的请求任务。
                // 非结构化 Task 不继承调用任务的取消；旧会话仍由下方代次检查隔离 UI。
                let save = Task { [historyStore] in
                    try await historyStore.append(
                        sourceText: text,
                        result: result,
                        providerName: providerName,
                        providerID: providerID,
                        model: model,
                        date: completedAt
                    )
                }
                do {
                    _ = try await save.value
                } catch {
                    let failure = error as NSError
                    Self.logger.error("append.failed domain=\(failure.domain, privacy: .public) code=\(failure.code)")
                    if !Task.isCancelled, generation == self.generation {
                        historyError = String(localized: "Could not save parsing history. The result is still available; copy it before closing.")
                    }
                }
                guard !Task.isCancelled, generation == self.generation else { return }
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
