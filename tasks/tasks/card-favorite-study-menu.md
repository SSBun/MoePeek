# 为卡片增加收藏与学习菜单

Status: Completed (2026-09-16 13:46)
Kind: Task

## Target
- [x] T1: 每张卡片右侧提供菜单，支持 Favorite 收藏及取消收藏。
- [x] T2: Study 按本机日期每张卡片每天仅可打卡一次，当天禁用，次日恢复。
- [x] T3: 持久化收藏状态、累计学习次数和每次打卡具体时间，刷新及重启后保留。

## Scope

不新增学习页面；保留已有解析历史内容和其他未提交工作。

## Plan

1. 核对复习页、历史存储与本机服务的数据链路。
2. 实现卡片菜单和持久化学习记录。
3. 进行授权范围内的非测试验证并完成风险分级与必要审查。

## Result

- T1: 卡片生成 details 菜单并提供收藏/取消收藏；隔离 HTTP 写入返回 true/false，JS 语法与 Debug 构建通过；见 ../artifacts/card-favorite-study-menu/evidence/verification.md，视觉待人工验收。
- T2: 真实服务重复及四个并发打卡均保持一条；昨日样例可新增今日事件；服务端日期限制与前端禁用/日期校准已检查；见验证记录。
- T3: 独立 review.json 保留收藏与全部事件时间，次数由事件数组派生；重启隔离服务后可读取，JSONL 哈希不变；见验证记录。
- Review gate: Passed — fresh 只读 reviewer dbc9f6ad-1443-4354-a4a6-5d33f2fdb20d 无发现或阻断风险；输出 /Users/caishilin/.pi/agent/sessions/--Users-caishilin-Desktop-personal-MoePeek--/subagent-artifacts/outputs/dbc9f6ad-1443-4354-a4a6-5d33f2fdb20d/card-menu-review.md；父会话复算四文件哈希与快照一致。
## Review Assessment

- Schema: task-review-assessment/v1
- Level: R2
- State: Current
- Reason: 新增本机认证写 API、持久化状态与跨日并发交互，需独立审查。
- Snapshot: tasks/artifacts/card-favorite-study-menu/evidence/verification.md 中四文件 SHA-256
- Evidence: 逐目标结果、严格并发类型检查、Debug 构建、隔离 HTTP 冒烟；未执行测试套件及浏览器视觉验收。
- Task fingerprint: 5506296fe78421dc4bcdb6c64cbc7acfed169899cad662fc81f42d8f3b963194

## Verification

- Passed: 审查后四文件 SHA-256 与证据一致，JS 语法、Swift 6 严格并发类型检查、diff 检查及 Context 验证再次通过；Debug 构建和真实 HTTP 冒烟见验证记录。未运行测试套件，浏览器视觉验收未执行。
