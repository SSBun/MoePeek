# 新增单词翻译模式

Status: Completed (2026-09-16 13:55)
Kind: Task

## Target
- [x] T1: 用户可在 MoePeek 使用与 Translation、Parsing 平级的独立单词翻译模式，并由该模式所选 Provider 解析输入单词。
- [x] T2: 解析结果按参考图展示单词、语言与音标、词性与中文释义，以及三条附中文翻译的例句。
- [x] T3: 设置页提供类似 Parsing 的单词翻译模式专属配置，可选择该模式使用的 Provider。
- [x] T4: 新模式不替换现有 Translation 与 Parsing 功能。
- [x] T5: 单词翻译浮窗采用新参考图中普通翻译浮窗的相似外观与布局，包括无标题栏圆角背景、顶部输入区及 Provider 结果卡片；不显示黄色框标出的源语言、交换、目标语言和齿轮操作栏。

## Scope

- 独立菜单入口、快捷键、浮窗、会话与 Provider 偏好；中文释义固定，不写入翻译或解析历史。
- 保留开始前已有未提交改动；实现前源码与本地化基线位于 /tmp/moepeek-word-baseline.IyYMdx。

## Plan

1. 增加独立单词请求模式、结构化结果校验与会话生命周期。
2. 接入独立窗口、菜单、快捷键和设置页 Provider 选择，补齐中文本地化；按用户补充截图复用普通翻译浮窗的无标题栏材质、输入区、缩放控件和结果卡片视觉，不显示语言操作栏。
3. 执行构建、静态检查和主 Agent 自查；不运行单元测试或测试套件。
4. 按实际风险进行独立只读审查，修复问题并记录最终验证与限制。

## Result

- T3: GeneralSettingsView 增加平级 Word Translation section 和独立 wordLookupProviderID 持久化；可选未启用为翻译服务的 LLM，失效 ID 有提示；快捷键默认未绑定。Settings 场景注入编译通过，新增中英本地化 JSON 解析通过。
- T2: 当前卡片保留WordLookupResult结构化正文及plainText复制，新增同翻译卡片的图标、折叠标题、状态与复制位置；专属Prompt/解码器未改，仍要求全部词条字段及三组双语例句。构建通过；未运行测试/真实Provider或已完成卡片GUI验证。
- T5: 复用原PopupPanel/SourceInputView/ResizeGripView/DraggableDividerView，单词布局不包含LanguageBarView和齿轮；结果卡片尺寸/字体/材质参照ProviderResultCard。构建成功；实际临时实例窗口截图word-ui-empty.png、word-ui-input.png确认圆角半透明无标题栏、顶部输入/快捷键提示、分隔线、右下缩放角且无语言栏。AX确认输入attenuation；退出前验证Cmd-W关闭至0窗口。Esc脚本存在焦点/输入法时序不确定性，不宣称完整键盘验收；完整结果卡片未实测。
- T1: 当前20文件快照：菜单/独立快捷键→WordLookupPanelController→WordLookupCoordinator→processStream(.wordLookup) 链路与五类LLM能力已静态核对，Debug build成功。临时启动产物，通过菜单打开独立Word Translation窗口并输入attenuation；未提交真实请求，临时实例已退出，用户原实例保留。
- T4: 本次20文件scope.diff不修改翻译/Parsing会话、历史和原提示词分支；SourceInputView保持默认提示，PopupView开放两个共享控件并限定复制事件窗口，PopupDismissMonitor限定本地Esc所属窗口，避免翻译窗口吞掉单词窗口按键。历史store/server其他并发修改排除范围且未覆盖。最后构建及diff检查通过。
- Review gate: Passed — fresh只读reviewer 519cf556-1d83-4c8d-b604-a1c3f10ac58e，reports/review-ui.md无确认问题或阻断风险；主会话重算20文件和manifest SHA256完全一致。保留真实Provider/完整卡片/键盘全路径未实测的限制。
## Review Assessment

- Schema: task-review-assessment/v1
- Level: R2
- State: Current
- Reason: 用户补充要求改为翻译浮窗样式，涉及共享输入/缩放控件及跨窗口键盘事件隔离，维持独立审查义务。
- Snapshot: tasks/artifacts/word-translation-mode/evidence/snapshot.json sha256:aa259046d03b180cd033c0eb32f792749838b57fa1f6a3f2a93c55cdacfecadd
- Evidence: T1–T5 Result；/tmp/moepeek-word-ui-build.log BUILD SUCCEEDED；word-ui-empty.png/word-ui-input.png为实际窗口截图；git diff --check和JSON解析通过。未运行测试/真实Provider；完整结果卡片与键盘全流程未实测。
- Task fingerprint: 2a7ae5388bc71752b7b4913f600781ac4d68206765f285c5680dff2ab426f327

## Verification

- Passed: 审查后20文件及manifest哈希一致；最终Debug build成功（/tmp/moepeek-word-ui-final-build.log）；diff/JSON/Context校验通过。实际输入态截图符合新UI要求；无测试或真实Provider请求，不宣称完整卡片及键盘全路径实测。
