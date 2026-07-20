# 使用本地 Apple Development 证书签名

- 状态：已完成（2026-07-20）
- 记录：[任务详情](todo/local-development-signing.md)

# 发布 MoePeek 0.13.0

- 状态：进行中（2026-07-20）
- 记录：[任务详情](todo/release-0.13.0.md)

# 对抗审查多语义翻译 Prompt

- 状态：已完成（2026-07-20）
- 记录：[任务详情](todo/semantic-translation-prompt-review.md)

# 修复快捷键打开翻译窗口时输入框不聚焦

## 状态

- 已完成（2026-07-20）

## 目标

- [x] 复现并定位快捷键打开手动翻译窗口后输入框未自动聚焦的根因。
- [x] 在共享打开链路做最小修复，不影响菜单栏打开与其他翻译模式。
- [x] 运行针对性验证和无签名 Debug 构建。
- [x] 通过独立对抗审查。

## Review status

- Gate: APPROVED
- Reviewer: `/root/focus_lifecycle_reviewer`
- Round: 2/3
- Scope: `SourceInputView.swift` 的聚焦生命周期修复与 `SourceInputViewFocusTests.swift` 回归测试
- Resolved: none
- Unresolved: none

## 审查结果

- 根因是旧实现异步尝试聚焦时，`NSTextView` 可能尚未挂载到窗口；失败后又提前停止重试。
- 改为在 `viewDidMoveToWindow()` 中设置 `initialFirstResponder` 与当前 `firstResponder`，失败时保留后续重试机会。
- 新增真实 `SourceInputView` + `NSHostingView` + `PopupPanel` 回归测试，断言文本区成为初始及当前 first responder。
- `git diff --check`、Swift 语法解析和 `tuist generate` 成功。
- 无签名 Debug 完整测试成功：7 个测试、0 失败。
- 独立 Reviewer 在 RE-REVIEW（2/3）返回 `APPROVED`，无未解决发现。

# 补齐 Codex 模型列表与多模型选择

## 状态

- 进行中（2026-07-20）

## 目标

- [x] Codex 设置页展示 Pi 当前维护的 Codex 模型目录。
- [x] 用户可选择额外模型并与默认模型并行翻译。
- [x] 默认模型与多模型偏好在设置变化后保持同步。
- [x] 构建、测试并通过独立对抗审查。

## 边界

- Pi 使用随包发布的静态 Codex 模型目录；不虚构未公开的账户模型列表接口。
- 实际模型可用性仍取决于用户的 ChatGPT 订阅。

## Review status

- Gate: APPROVED
- Reviewer: `/root/codex_provider_reviewer`
- Round: 1/3
- Scope: Codex 模型目录、设置界面、多模型执行与相关测试
- Resolved: none
- Unresolved: none

## 审查结果

- 失败用例先确认 `CodexProvider` 缺少模型目录，修复后全量测试成功：6 个测试、0 失败。
- `git diff --check` 成功。
- 独立 Reviewer 在 INITIAL（1/3）返回 `APPROVED`，确认目录与 Pi 0.80.10 一致，设置同步和并行执行链路正确。

# 添加 Codex 实验性翻译 Provider

## 状态

- 已完成（2026-07-20）

## 目标

- [x] 用户可通过设置页的 Connect Codex 按钮完成 ChatGPT/Codex Device Code 授权。
- [x] OAuth access/refresh token 仅存入 macOS Keychain，并在过期前自动刷新。
- [x] 使用 Codex Responses 流式接口调用订阅包含的 Codex 模型完成翻译。
- [x] 保留现有 OpenAI API Key Provider，不共享或覆盖其配置。
- [x] 构建验证并通过独立对抗审查。

## 边界

- Provider 标记为 Experimental；所用 Codex OAuth client 和 ChatGPT backend 并非面向第三方应用承诺的稳定公共 API。
- 首版仅支持 Pi 已实现的 Device Code 流程，不实现 localhost callback 浏览器 OAuth。
- 不读取或复用 `~/.codex/auth.json`，避免接触其他应用保存的凭据。

## Review status

- Gate: APPROVED
- Reviewer: `/root/codex_provider_reviewer`
- Round: 2/3
- Scope: Codex Provider、OAuth、设置界面、注册与任务相关 diff
- Resolved: R1、R2、R3
- Unresolved: none

## 审查结果

- `tuist generate` 成功。
- `xcodebuild -workspace MoePeek.xcworkspace -scheme MoePeek -configuration Debug CODE_SIGNING_ALLOWED=NO test` 成功：4 个测试、0 失败，并完成宿主 App 构建。
- 独立 Reviewer 在 RE-REVIEW（2/3）返回 `APPROVED`，无未解决发现。

# 修复手动翻译输入框偶发失焦

## 状态

- 已完成（2026-07-19）

## 目标

- [x] 追踪快捷键、面板激活与输入框聚焦的完整调用链。
- [x] 找到偶发失焦的根因。
- [x] 让初始聚焦等待应用激活且面板成为 key window。
- [x] 构建验证并通过独立对抗审查。

## Review status

- Gate: APPROVED
- Reviewer: `/root/focus_fix_reviewer`
- Round: 1/3
- Scope: `Sources/UI/PopupPanel/SourceInputView.swift` 及任务相关 diff
- Resolved: none
- Unresolved: none

## 审查结果

- `showAtScreenCenter()` 同步连续调用 `NSApp.activate` 与 `makeKeyAndOrderFront`，未等待应用激活完成。
- `SourceTextEditor` 仅异步尝试聚焦；它在确认 `makeFirstResponder` 成功前就将 `didFocusInitially` 置为 `true`，失败后没有重试。
- 两段独立时序形成竞态，可解释“偶发”而非稳定失焦。
- 修复后会同时等待应用激活和面板成为 key window，仅在 `makeFirstResponder` 成功后停止监听并应用默认输入源。
- `git diff --check`、`swiftc -parse Sources/UI/PopupPanel/SourceInputView.swift` 和无签名 Debug 构建均成功。
- 独立 Reviewer 在 INITIAL（1/3）返回 `APPROVED`，无未解决发现。

# 默认输入法设置计划

## 假设
- “input method” 指 macOS 键盘输入源，例如 ABC、拼音、日文输入法。
- 该设置只影响 MoePeek 手动翻译弹窗里的输入框，不全局切换用户其他 App 的输入源。
- 默认值为跟随系统当前输入源。

## 计划
- [x] 增加一个 Defaults 偏好，用字符串保存默认输入源 identifier。
- [x] 在 General 设置页增加 Picker：System Default + 当前可用键盘输入源。
- [x] 手动输入框获得焦点时读取偏好并应用到 `NSTextView.inputContext`。
- [x] 构建验证。

## 审查结果
- `tuist generate` 成功。
- `xcodebuild -workspace MoePeek.xcworkspace -scheme MoePeek -configuration Debug CODE_SIGNING_ALLOWED=NO build` 成功。
- 将本地未跟踪的 `Configurations/Signing.xcconfig` 改为 ad-hoc 签名后，常规 `xcodebuild -workspace MoePeek.xcworkspace -scheme MoePeek -configuration Debug build` 成功。
- `venom-cli build --run --debug` 构建成功并启动 App；日志监控已手动停止。

# 翻译结果快捷键计划

## 假设
- `⌘1`、`⌘2` 等数字快捷键在结果列表显示时复制对应完成结果并关闭弹窗。
- 空输入显示历史记录时，保留现有 `⌘1..9` 选择历史记录行为。
- 未完成、失败、等待中的结果不响应对应数字快捷键。

## 计划
- [x] 从当前 provider 顺序中取出已完成翻译结果。
- [x] 调整本地 key monitor：结果态复制对应结果并关闭，历史态保留重译。
- [x] 给完成状态的结果卡显示 `⌘1`、`⌘2` 等快捷键 badge。
- [x] 构建验证。

## 审查结果
- `xcodebuild -workspace MoePeek.xcworkspace -scheme MoePeek -configuration Debug build` 成功。
- 用户指出 badge 未显示后，补充结果卡 header badge，并让数字快捷键与可见卡片序号对齐。
