# 复习卡片操作按钮直接平铺显示

Status: Completed (2026-09-17 11:09)
Kind: Task

## Plan

1. 将折叠菜单替换为常驻的小图标按钮，不展示操作文字标签，保留原有功能及可访问名称。
2. 使用原有右侧窄列直接展示星标和勾选图标，文字说明及学习次数移至悬停提示，保留可访问名称与失败反馈。
3. 执行语法和差异检查，核对按钮及状态逻辑，记录验证边界；不运行测试套件。

## Target
- [x] T1: 复习页面每张卡片原省略号菜单中的操作以紧凑小图标按钮直接平铺显示，无需打开菜单，不展示按钮文字标签。
- [x] T2: 保留原有操作功能，不改变其他页面布局或记录内容。
- [x] T3: 缩小收藏和学习图标，保持直接展示、无文字标签及原有操作功能。
- [x] T4: 缩小收藏与学习按钮之间的垂直留白，保留当前图标大小及功能。

## Result

- T1: 最终源码保持右侧常驻星标与勾选，无省略号或文字标签；JS 哈希与前版一致。本轮只收紧按钮留白，未重新截图。
- T2: 本轮 CSS 全量比较仅操作区 gap 和按钮高度变化；保留 34px 右列、16px 图标以及其余页面样式。JS SHA256 a59c547196c621f72a392ca20fbb1b7751a73375536c87c5919a9256fbed5901 不变，保存及状态规则不变。未运行测试或构建应用。
- T3: 当前 .card-actions button 字号保持 16px，较最初 22px 缩小；JS 不变，图标内容、无标签与原有操作保持。
- T4: CSS 差异核对：操作区 gap 从 6px 减至 2px，按钮高度从 34px 减至 28px，并设置 min-height 28px 覆盖通用控件最小高度；中心垂直间距由 40px 减至 30px。宽度 34px、字号 16px 不变。git diff --check 通过。
- Review gate: Skipped — R1：局部尺寸调整，影响和结果由完整 CSS 差异确认，无独立评审要求。
## Review Assessment

- Schema: task-review-assessment/v1
- Level: R1
- State: Current
- Reason: 局部图标展示微调，本轮仅收紧按钮留白。
- Snapshot: Resources/parsing-history.js sha256=a59c547196c621f72a392ca20fbb1b7751a73375536c87c5919a9256fbed5901; Resources/parsing-history.css sha256=d1b3aaa3867dea9111ca3cce34475c8323d0d565afdbdb760bccafd17a8a3094; 两文件未暂存。
- Evidence: T1–T4 当前 Result；修改前后 CSS 全量差异及 JS 哈希核对。
- Result clarity: 用户要求缩小按钮间留白，gap 和按钮高度直接减小，图标字号保留。
- Bounded impact: 只修改 .card-actions 及其按钮的垂直尺寸，其余 CSS 与 JS 不变。
- Low risk: 可逆局部展示变更，无数据、权限或服务端变更；点击区域仍为 34×28px。
- Sufficient verification: 直接比较 CSS，确认 min-height 覆盖通用 34px 限制；JS 语法和 diff 检查通过。未重新截图、未跑测试。
- Task fingerprint: 5c288d1fd310f1f8676d9f72812773eb11559333bf73e371ca22499bd772fdd7

## Verification

- Passed: 最终哈希与 assessment 一致；CSS 为 gap 2px、高度及最小高度 28px、字号 16px。JS 语法和 diff 检查通过，未跑测试、未重新截图或构建。
