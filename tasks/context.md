# 工作区上下文

- 本项目的 canonical 发布仓库是 `SSBun/MoePeek`；README、Sparkle feed、GitHub Actions、应用内项目链接和 release metadata 均应指向该 fork。
- `SourceInputView.SubmitAwareTextView` 在 `viewDidMoveToWindow()` 中把自身设为 `PopupPanel` 的 initial/current first responder；这是手动翻译输入框的原生聚焦生命周期点。
- Codex 模型选择使用 Pi 随包生成的静态 OpenAI Codex 模型目录；默认模型与额外选择分别存入 Defaults，额外模型通过 `ParallelModelProvider` 与默认模型并行执行。
- `CodexProvider` 是独立于 OpenAI API Key Provider 的实验性 Provider：使用 ChatGPT Codex Device Code OAuth、Keychain 凭据和 `chatgpt.com/backend-api/codex/responses` SSE。
- Codex OAuth 凭据由 actor 串行管理；过期 token 的并发刷新共享同一个任务，设置窗口关闭会取消尚未完成的 Device Code 轮询。
- 手动输入翻译链路：`AppDelegate` 的 `.inputTranslation` 快捷键先调用 `TranslationCoordinator.prepareInputMode()`，再调用 `PopupPanelController.showAtScreenCenter()`。
- `PopupPanelController.showAtScreenCenter()` 负责激活应用并将 `PopupPanel` 置为 key window；`SourceInputView.SourceTextEditor` 负责把内部 `NSTextView` 设为 first responder。
- `PopupPanel` 使用 `.nonactivatingPanel`，但覆盖 `canBecomeKey` 返回 `true`。
