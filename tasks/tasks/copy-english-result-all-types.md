# 智能翻译所有结果类型支持仅复制英文结果

| Field | Value |
| --- | --- |
| Status | Completed (2026-10-10 11:02) |
| Kind | Task |

## Target
- [x] T1: SmartTranslate 所有包含英文结果的已完成结果类型均支持再次按 Enter／Return 复制英文结果，不复制释义、解释、例句或中文译文。
- [x] T2: 复制不回填原输入框，首次回车仍触发翻译。

## Scope

仅统一智能模式的 Enter／Return 结果复制；保留现有右键及组合快捷键的完整内容复制，不修改独立解析模式。没有英文结果或无法安全合成纠错整句时不复制说明文字冒充结果。

## Plan

1. 扩展结果正文提取，使词条返回英文词语，多候选逐行保留；句子继续使用既有安全提取规则。
2. 让回车对已完成词条走复制分支，保留首次提交与请求进行中行为。
3. 构建、静态对比全部结果分支及更新项目事实；不运行测试。

## Result

- T1: 逐分支检查 SmartTranslationResult.pasteText：words 仅取 entry.word，去首尾空白、多候选换行，不读取释义、音标、usage、examples；sentence 仍委托 ParsingResult.pasteText，tutor 取英文句子、check 优先改写或安全合成完整纠错句；skip/空词条返回 nil。协调器已移除词条完成后 wait 分支，优先复制已完成英文结果。
- T2: 源码对比确认首次 submittedText 不匹配仍 process，无可用结果且 loading 仍 wait；复用上个任务的 onCopyResult→NSPasteboard→dismiss，不新增输入框操作。Debug xcodebuild build 成功；Swift parse、git diff --check、Context validate 均通过。未运行测试、未实际操作 GUI。
- Review gate: Skipped — 当前 R1 四项依据充分，无独立审查要求；变更为确定性字段提取与对应回车分支简化。
## Review Assessment

- Schema: task-review-assessment/v1
- Level: R1
- State: Current
- Reason: 扩展纯结果文本提取并删除词条专属等待分支，复用既有剪贴板出口。
- Snapshot: HEAD=e1165ec927ca7d32d4d44f08ba2cbb8edbeb44ab; git diff -- Sources Resources sha256=6ce526c017d0eeed881e8bde314ef61d10da65acb02052d7f55ad5aeba94693a; 当前任务仅增量修改两个 Core 文件，其余源码差异属于前一任务；无暂存或未跟踪交付代码。
- Evidence: T1/T2 分支检查与 Debug BUILD SUCCEEDED；Swift parse、diff 与 Context 校验通过。
- Result clarity: 用户已确认全部含英文结果类型的再次回车复制，只取英文词语或完整句子。
- Bounded impact: 改动局限于智能结果的 words 文本提取与协调器 words 等待分支；句子提取、输入编辑、网络请求和剪贴板控制器不变。
- Low risk: 仅用户触发的本地文本复制，无原输入框写入、数据存储或权限改动；空结果不冒充正文。
- Sufficient verification: 穷举源码 words/sentence/skip 及共享 tutor/check/skip 分支，核对结果选择与首次提交保留；Debug 全项目构建与 Swift 解析通过；未运行测试或 GUI 实测。
- Task fingerprint: 9a643c58fa6530a86c1914cfe098f0b7ebbe832acc90e2ad8878c8d1cfff0ce3

## Verification

- Passed: 最终源码差异哈希 6ce526c017d0eeed881e8bde314ef61d10da65acb02052d7f55ad5aeba94693a 与构建后快照一致；diff 再次通过；正文来源与首次提交链路已核对，未运行测试和 GUI 验证。
