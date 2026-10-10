# 智能翻译改为仅复制结果而不回填

| Field | Value |
| --- | --- |
| Status | Completed (2026-10-10 10:33) |
| Kind | Task |

## Target
- [x] T1: SmartTranslate 不再将译文回填到原输入框。
- [x] T2: 翻译完成后再次按 Enter／Return，原本用于回填的结果直接复制到剪贴板，首次回车仍触发翻译，其他功能不变。

## Scope

仅调整智能翻译的回车结果操作，不修改独立解析模式及显式复制快捷键的内容。

## Plan

1. 将智能翻译回车结果出口改为剪贴板写入，移除该模式不再需要的回填状态。
2. 更新智能翻译提示文案，保留原有结果选择和首次提交行为。
3. 构建并检查调用链、差异和本地化，不运行测试套件。

## Result

- T1: 检查智能面板完整调用链与差异：已删除 ParsingPasteTarget 捕获、验证与异步粘贴；回车结果仅写 NSPasteboard 后关闭窗口，不再有原输入框写入路径。独立 ParsingPanel 未修改。
- T2: 检查 ParsingTextEditor 的 Enter/Return keyUp→submit→enterAction→copyResult 链路，正文提取不变、首次 process/loading/retry/词条分支不变；剪贴板写入失败保留面板并显示错误。MoePeek Debug xcodebuild build 成功，Swift parse、JSON 解析与 git diff --check 通过；未运行测试或实际 GUI 交互。
- Review gate: Skipped — R1 四项依据已记录；单一结果出口替换及清理，无独立审查要求。
## Review Assessment

- Schema: task-review-assessment/v1
- Level: R1
- State: Current
- Reason: 将单一已完成结果出口从自动回填改为系统剪贴板，删除对应异步状态，未改变翻译或内容选择。
- Snapshot: HEAD=e1165ec927ca7d32d4d44f08ba2cbb8edbeb44ab; unstaged git diff -- Sources Resources sha256=1c1f2c2501048ed5c8f91a1edc28f29e98a10b2ddd4d7df3bfc2eb804ff9df69; no staged or untracked deliverables
- Evidence: T1/T2 调用链对比；xcodebuild Debug BUILD SUCCEEDED；Swift parse、JSON、diff 检查通过。
- Result clarity: 用户已确认 Enter/Return 替代 Center，复制原本回填正文，首次翻译不变。
- Bounded impact: 仅智能协调器动作标签、面板回调和剪贴板出口及专用文案；共享解析代码无改动。
- Low risk: 删除跨应用写入，改为用户触发剪贴板复制；失败保留结果可重试，无持久数据格式或权限机制变更。
- Sufficient verification: 全项目 Debug 编译链接成功，逐分支对比首次提交、加载、失败重试、词条、显式快捷键未变；搜索无智能回填调用残留。未运行测试及 GUI 实测。
- Task fingerprint: 821ef6e3ccdcf12df0e095f3bad4a420f144eef579bd025ca1668b405f171eda

## Verification

- Passed: 最终差异哈希仍为 1c1f2c2501048ed5c8f91a1edc28f29e98a10b2ddd4d7df3bfc2eb804ff9df69，构建后代码未变化；diff 检查再次通过，Context 校验通过。编译及源码链路验证完成；未运行单元测试或 GUI 实测。
