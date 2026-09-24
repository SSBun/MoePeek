# 解析结果回填失败时保留到剪贴板

| Field | Value |
| --- | --- |
| Status | Completed (2026-09-20 11:07) |
| Kind | Task |

## Target
- [x] T1: 解析结果无法粘贴回原输入框时，自动将原本要回填的结果保留在用户剪贴板，供手动粘贴。
- [x] T2: 正常回填成功时的行为不变。

## Scope

仅补充解析面板及智能翻译句子解析的回填失败处理，不调整原有目标验证、粘贴动作或取消规则。保留开始任务前已有的菜单刷新等未提交改动。

## Plan

1. 核对交接前和异步回填的失败出口。
2. 共用剪贴板兜底，在原有错误提示后说明复制结果；复制失败不声称成功。
3. 编译并检查调用路径、本地化及差异；不运行测试套件。

## Decisions

- 仅复制本次原定回填的正文，不复制整份解析说明。
- 取消及过期会话继续由既有保护拦截，不触发额外剪贴板写入。
- 空白正文不清空剪贴板；复制失败保留原有错误并提示复制失败。
- 验证限制：未实际操控外部应用输入框，未运行单元测试或项目测试套件。
- 内容 SHA-256：`Sources/Core/TextSelection/ParsingPasteTarget.swift` = `e7a5899c0baf13407db2b546e26f52c7c3e398722639e912cbb5e50f5466af59`；`Sources/UI/ParsingPanel/ParsingPanelController.swift` = `94ba60c63c635c786a7171c1372514c0ecda4b872b8ed31c16cc661f655967a2`；`Sources/UI/SmartTranslationPanel/SmartTranslationPanelController.swift` = `870510ede530d70627cac92ab25524349cf407c7268d7be68cbfe031d95e4697`；`Resources/Localizable.xcstrings` = `435aba90aad28d7202592a95d99bc1760aae5005761261e065001f21da2a91fb`。四文件均为工作区未暂存改动，无暂存差异；其中 ParsingPasteTarget 的原有 refreshPasteMenu 改动不归本任务所有。

## Result

- T1: 逐项检查两个控制器共四处失败出口，均将同一回填正文交给共享 copyAfterPasteFailure；该方法写入 NSPasteboard.general 并检查 setString 返回值，成功才提示已复制。空正文直接返回；异步取消和过期保护位于复制之前。Debug xcodebuild build 成功，xcstrings JSON 校验通过；未实机触发外部输入框失败，未运行测试。
- T2: 对比任务前差异：仅四处错误处理、共享复制方法及一条本地化新增；target.paste 成功路径、取消分支、焦点和选区验证不变，原有 refreshPasteMenu 改动保留。git diff --check 通过。
- Review gate: Skipped — R1 四项依据已记录；无独立审查要求。同步复制及全部调用点经主 Agent 对照，编译和格式校验通过。
## Review Assessment

- Schema: task-review-assessment/v1
- Level: R1
- State: Current
- Reason: 已理解的四处失败出口复用同步剪贴板复制，无回填算法或生命周期变更。
- Snapshot: 四个交付文件的 SHA-256 见 Decisions；仅未暂存差异，保留既有菜单刷新改动。
- Evidence: Result T1/T2；Debug build 成功，JSON 与 diff 检查通过。
- Result clarity: 用户确认失败复制原定回填正文，成功行为不变；调用参数仍为同一 text。
- Bounded impact: 仅解析及智能句子两个控制器的四个 catch 出口和一个共享同步复制方法；取消和过期会话不调用。
- Low risk: 只执行用户请求的本地剪贴板替换，无输入框写入策略变更、权限绕过、文件删除或网络传输；复制失败不误报成功。
- Sufficient verification: 实际 Debug 编译通过；直接逐分支对照证明失败出口调用与成功路径不变；JSON/diff 检查通过。未运行测试，外部应用 UI 仍需人工验证。
- Task fingerprint: e79482c5a1a24e8d1d4b5becabe7741ac07dbe31537e1f14f7586821875b6ff8

## Verification

- Passed: 终验四文件 SHA-256 与 Decisions 一致，无内容漂移；git diff --check 与 xcstrings JSON 复检通过，当前快照 Debug build 成功。成功/取消路径未改，四个失败出口包含复制兜底。未运行测试或外部应用交互验证。
