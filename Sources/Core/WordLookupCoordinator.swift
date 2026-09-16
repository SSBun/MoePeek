import Defaults
import Foundation
import Observation

/// 独立单词会话；只共享 Provider 注册表，不读写翻译、解析会话或历史。
@MainActor
@Observable
final class WordLookupCoordinator {
    enum ProviderState: Equatable {
        /// 正在等待完整字典条目。
        case loading
        /// 已校验、可展示和复制的结果。
        case completed(WordLookupResult)
        /// 请求或条目校验失败，可重新提交。
        case error(String)
    }

    private(set) var activeSlots: [any TranslationProvider] = []
    private(set) var providerStates: [String: ProviderState] = [:]
    private(set) var globalError: String?

    /// 单词模式专用服务选择，空值跟随已启用的 LLM。
    var selectedProviderID: String {
        didSet {
            guard selectedProviderID != oldValue else { return }
            Defaults[.wordLookupProviderID] = selectedProviderID
            reset()
        }
    }

    /// 支持单词翻译的服务，包含未启用为翻译服务的 LLM；复杂度 O(n)。
    var availableProviders: [any TranslationProvider] {
        registry.providers.filter(\.supportsWordLookup)
    }

    /// 当前会话是否有未完成请求；复杂度 O(n)。
    var isLoading: Bool {
        providerStates.values.contains { if case .loading = $0 { return true }; return false }
    }

    private let registry: TranslationProviderRegistry
    private var tasks: [String: Task<Void, Never>] = [:]
    private var generation = 0

    init(registry: TranslationProviderRegistry) {
        self.registry = registry
        selectedProviderID = Defaults[.wordLookupProviderID]
    }

    /// 用专属字典提示词请求条目，中文释义不受翻译目标语言影响。
    func lookUp(_ text: String) {
        reset()
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            globalError = String(localized: "Enter a word to look up.")
            return
        }
        if selectedProviderID.isEmpty {
            activeSlots = registry.enabledSlots.filter(\.supportsWordLookup)
        } else {
            guard let provider = registry.provider(withID: selectedProviderID), provider.supportsWordLookup else {
                globalError = String(localized: "Selected word translation provider is unavailable. Choose another provider in Settings.")
                return
            }
            activeSlots = registry.modelSlots(for: provider)
        }
        guard !activeSlots.isEmpty else {
            globalError = String(localized: "Word translation requires an LLM provider. Choose one in Settings.")
            return
        }
        let generation = generation
        for provider in activeSlots {
            providerStates[provider.id] = .loading
            tasks[provider.id] = Task { [weak self] in
                guard let self else { return }
                await self.run(provider, text: text, generation: generation)
            }
        }
    }

    /// 关闭、重新提交或更换服务时，取消旧请求并隔离迟到结果。
    func reset() {
        generation += 1
        for task in tasks.values { task.cancel() }
        tasks.removeAll()
        activeSlots = []
        providerStates = [:]
        globalError = nil
    }

    private func run(_ provider: any TranslationProvider, text: String, generation: Int) async {
        guard !Task.isCancelled, generation == self.generation else { return }
        defer {
            if generation == self.generation { tasks.removeValue(forKey: provider.id) }
        }
        do {
            var content = ""
            for try await chunk in provider.processStream(text, from: nil, to: "zh-Hans", mode: .wordLookup, model: nil) {
                guard !Task.isCancelled, generation == self.generation else { return }
                content += chunk
                guard content.utf8.count <= 65_536 else {
                    providerStates[provider.id] = .error(String(localized: "Word translation returned an invalid entry. Try another word or retry."))
                    return
                }
            }
            guard !Task.isCancelled, generation == self.generation else { return }
            if let result = WordLookupResult.decode(content) {
                providerStates[provider.id] = .completed(result)
            } else {
                providerStates[provider.id] = .error(String(localized: "Word translation returned an invalid entry. Try another word or retry."))
            }
        } catch {
            guard !Task.isCancelled, generation == self.generation else { return }
            providerStates[provider.id] = .error(error.localizedDescription)
        }
    }
}
