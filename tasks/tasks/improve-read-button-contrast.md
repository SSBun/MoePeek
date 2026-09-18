# 提高复习页已读按钮状态对比度

Status: Completed (2026-09-17 13:34)
Kind: Task

## Scope

只调整复习页已学习按钮的展示状态和样式，保留已有按钮平铺改动及所有保存、禁用、收藏逻辑。

## Plan

1. 使用现有 studied 结果标记展示状态，仅为已学习按钮应用高对比样式。
2. 复用深浅主题绿色变量，取消已学习按钮的禁用透明度衰减。
3. 核对任务增量、JavaScript 语法及深浅主题颜色对比度；不运行测试。

## Target
- [x] T1: 复习网页的已读按钮状态更清晰，与未读状态更易区分，保留原有阅读状态和按钮操作行为。

## Result

- T1: 已读状态由现有 studied 结果切换 is-studied 类，绿色实底与加粗勾号且 opacity=1；按 CSS 实际变量计算深色勾号/底色对比度 8.00:1、浅色 5.13:1。去掉本任务新增两行后，CSS/JS SHA256 分别恢复为 d1b3aaa3867dea9111ca3cce34475c8323d0d565afdbdb760bccafd17a8a3094 和 a59c547196c621f72a392ca20fbb1b7751a73375536c87c5919a9256fbed5901，证明原逻辑及已有改动保留。node --check、git diff --check 与 Debug 构建通过；未运行测试、未做浏览器视觉验证。
- Review gate: Skipped — R1：受限展示变化，有数值对比度与任务增量核对证据，无独立评审义务。
## Review Assessment

- Schema: task-review-assessment/v1
- Level: R1
- State: Current
- Reason: 仅添加展示状态 class 与对应高对比 CSS，业务逻辑无变化。
- Snapshot: 当前未暂存完整文件 SHA256：Resources/parsing-history.css=2030452b702fd50ae33f59fa917d6f2cefcc6fce8a55560500fc8469ddb2acb7；Resources/parsing-history.js=1ad87b60393a5bc9d8e0fbefce738f2c5a3ec1f54b0754161b224a4acd2aba6f；任务增量为各一行，其余是任务开始前改动。
- Evidence: T1 对比度计算、逆增量哈希核对、JS 语法及 Debug 构建。
- Result clarity: 已读用绿色实底强调，未读保留原状，用户确认仅视觉调整。
- Bounded impact: 已检查 update、disabled、保存及收藏处理；class 仅依据既有 studied 切换，CSS 限定 card-actions 中该 class。
- Low risk: 仅展示，无 API、存储或安全校验改动；disabled 规则完整保留。
- Sufficient verification: 实际主题变量对比度 8.00:1 和 5.13:1；逆增量哈希验证原内容未变；语法、构建和差异检查通过。浏览器外观未人工确认。
- Task fingerprint: a730161b8589fd514e93016a443a56c14d67c8448ccd11c6533d60ad2b83c005

## Verification

- Passed: 最终 SHA256 与当前评估一致，重复 JS 语法及 git diff --check 均通过，Context 有效；构建后资源未变。未运行测试及浏览器视觉验证，未启动新应用。
