# 按参考图实现解析历史卡片

Status: Completed (2026-09-16 11:44)
Kind: Task

## Plan

1. 以用户提供的深色圆角卡片截图和当前 StyledParsingResultView 为展示依据。
2. 调整独立[测试页](../artifacts/parsing-history-reference-cards/specs/preview.html)：沿用之前的日期侧栏，原文与解析同卡片展开，字号恢复此前示例设计的 14px。
3. 实际浏览器检查深浅色、侧栏日期、搜索、原文与解析共同显示及窄屏布局，提供截图与本地页面。

## Decisions

- 原文与解析放在同一卡片中直接显示，不使用“查看原文”折叠；桌面恢复日期侧栏。
- 保留参考图的配色和圆角，内容字号按此前示例的 14px，而不是放大到 17px。
- 默认深色，提供浅色切换；不引入网络资源或运行时依赖。
- 本次不修改前一任务的三份已完成示例，也不接入真实历史。

## Target
- [x] T1: 仅在测试示例页将每条解析以参考图的简洁圆角卡片呈现，使用等宽字体、青色标题和术语、黄色例句、灰色说明，内容直接展开。
- [x] T2: 内容结构遵循当前原生解析面板的 check/tutor/skip 展示规则，保留日期浏览和搜索，去掉宣传性大标题与额外学习流程。
- [x] T3: 使用虚构内容并保留原文可查看，提供浏览器实际效果预览；不修改正式复习页、原生面板、存储、本地服务或真实历史数据。
- [x] T4: 测试页桌面使用之前的左侧日期栏，原文与解析在同一卡片中默认可见，卡片内容字号恢复此前示例的 14px，不再放大。

## Result

- T1: 当前preview.html保留参考图圆角配色，解析默认展开；Chrome实测22px圆角、5px内容间距，截图已刷新至当前侧栏与14px版。
- T2: 保留check/tutor/skip顺序；当前Chrome运行验证搜索、无匹配、侧栏日期及窄屏日期选择器同步，深浅色可切换，390px无横向溢出。证据：tasks/artifacts/parsing-history-reference-cards/evidence/browser-check.txt。
- T3: 静态虚构数据，原文在同一卡片内直接可见，无details折叠；Chrome外部资源请求为零，7个正式文件哈希未变。
- T4: Chrome计算样式：桌面sidebar=block，5条示例原文均为.card直属子元素，details数量0，卡片/原文/标题均14px；侧栏可切日期，窄屏切换为日期选择器。
- Review gate: Skipped — R1静态预览改动，当前实际浏览器检查覆盖要求，无独立审查义务。
## Review Assessment

- Schema: task-review-assessment/v1
- Level: R1
- State: Current
- Reason: 仅调整独立静态预览的布局与字号。
- Snapshot: tasks/artifacts/parsing-history-reference-cards/evidence/preview.sha256
- Evidence: tasks/artifacts/parsing-history-reference-cards/evidence/browser-check.txt
- Result clarity: 用户明确要求日期侧栏、同卡片直接显示原文解析与14px字号，均有浏览器可观察值。
- Bounded impact: 单HTML示例与证据更新，正式文件未修改。
- Low risk: 无网络或真实数据IO；筛选仅修改虚构DOM可见性。
- Sufficient verification: 实际Chrome检查同卡片结构、字号、侧栏和窄屏日期联动、搜索、主题与截图，正式文件哈希一致。
- Task fingerprint: 89b3ba46ce61936d60102d797da4a762ac5372545ffb2d62899fa5667fea07da

## Verification

- Passed: 当前示例哈希、7个正式文件哈希及diff检查通过；浏览器实测和截图已更新，不再沿用旧原文折叠证据。未运行单元测试或项目测试套件。
