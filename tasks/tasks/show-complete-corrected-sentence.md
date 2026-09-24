# 纠错面板同时展示完整修正句子

| Field | Value |
| --- | --- |
| Status | Completed (2026-09-18 14:35) |
| Artifacts | [Artifacts](../artifacts/show-complete-corrected-sentence/) |
| Kind | Task |

## Scope

仅修改原生解析结果展示及必要的数据传递，覆盖共用结果视图的解析与智能面板；保留原文、翻译、纠错项和语法说明，不修改复习网页、模型请求协议、历史存储或回填算法。

## Plan

1. 向共用结果视图传入协调器持有的提交原文快照，不使用可能已编辑的草稿。
2. 使用既有 pasteText 规则展示完整英文：优先模型改写，否则应用唯一且不重叠的精确纠错；继续保留逐项说明及原有无修改提示。
3. 构建并核对两个调用入口、改写去重与快照绑定，验证截图中的句子展示；不运行测试套件，不重启用户应用。

## Decisions

- 共用 StyledParsingResultView 同时用于解析和智能句子面板；两处都要传入各自会话原文。
- 复用现有保守合成规则：纠错片段缺失、重复或重叠且没有模型完整改写时，不猜测或展示可能错误的整句；继续显示原纠错说明。
- 当前存在其他会话的历史自动刷新改动，保持原样，不纳入本任务。

## Target
- [x] T1: 纠错面板在逐项纠错和语法说明之外，同时显示完整的修正后英文句子。
- [x] T2: 保留现有原文、翻译及逐项纠错说明，不以完整修正句子替代这些内容。

## Result

- T1: 共用结果视图接收两协调器 submittedText 快照；有纠错时优先显示模型 rephrase，否则复用现有 pasteText 合成整句。截图示例实际得到 So I can use an ESP32 chip as a Bluetooth keyboard?；使用当前源码提取的 StyledParsingResultView 经 SwiftUI ImageRenderer 生成深浅色预览并人工查看，整句在原纠错说明下方显示。证据见 ../artifacts/show-complete-corrected-sentence/evidence/dark.png 与 light.png；不是运行中完整面板截图。
- T2: 逐项 diff 核对：仅开放提交原文的只读访问、两个视图传参及整句渲染条件；原输入、中文翻译、逐项纠错/说明、tutor/skip、无修改提示和文本选择均保留；改写仅显示一次。协调器 reset 与 generation 原逻辑未改，合成不用草稿。Debug xcodebuild build 成功（5.055秒），git diff --check 与 Context validate 通过；无模型请求/JSON协议/回填算法/网页改动。重复、缺失或重叠片段且无完整改写时仍不猜测整句。未运行测试或重启应用。
- Review gate: Skipped — R1：已核对共享视图两入口、快照生命周期及既有合成边界，编译与原生组件预览充分支持局部展示改动，无独立评审要求。
## Review Assessment

- Schema: task-review-assessment/v1
- Level: R1
- State: Current
- Reason: 在既有共享视图中展示已经由回填规则支持的完整英文，算法和业务状态转换不变。
- Snapshot: tasks/artifacts/show-complete-corrected-sentence/evidence/snapshot.json：四个Swift交付文件及两张原生结果视图预览的SHA256；源码为当前未暂存改动，图片为新增证据。
- Evidence: T1/T2 当前 Result；Debug build 成功，深浅色真实 SwiftUI 组件渲染、提交快照与两个调用入口静态核对。
- Result clarity: 用户确认保留逐项说明并展示完整修正句；预览已显示完整句而不是只有局部替换。
- Bounded impact: 四文件仅只读状态暴露、共享视图参数及条件展示；两个入口已检查，无新增请求或模型字段。
- Low risk: 纯展示增量，复用原保守替换规则，不改变存储、外部回填或网络；不可靠片段保持不合成。
- Sufficient verification: 完整应用Debug构建通过；当前组件深浅色渲染均见整句和既有说明；两个调用者使用submittedText而非draft，模型有改写时不会重复展示。未跑测试或验证实际窗口高度/焦点。
- Task fingerprint: 9cb596bfe953f7061130794d63a54ea4c2ba8d8854df6464e08de6d275a6d397

## Verification

- Passed: 最终六文件哈希与snapshot.json一致；构建后Swift源码未变，git diff --check和Context校验通过。深浅色组件预览已查看；未运行单元测试/测试套件、未重启用户应用或验证完整窗口交互。
