# 正式复习页采用确认卡片并排除无修改结果

Status: Completed (2026-09-16 13:13)
Kind: Task

## Scope

- 修改正式复习网页、无修改 check 的历史写入策略、当前确认的测试页和相关中文说明。
- 不修改原生面板、解析提示词、服务请求、回填或本机 HTTP 服务访问边界；不清理真实历史。
- 不运行单元测试或项目测试套件；使用构建和隔离数据的实际存储/浏览器操作验证。

## Plan

1. 核对当前 check/tutor/skip 与旧 schemaVersion 1 的读取兼容性，并保存本次改动前基线。
2. 存储层在文件 IO 前排除无纠错项且无有效改写的 check，网页读取同样过滤已存 v2 记录。
3. 正式页面采用已确认侧栏卡片布局，保留鉴权、安全文本渲染、日期搜索、分页和旧格式内容。
4. 同步当前测试页和说明，完成实际 Debug 构建、隔离存储/HTTP/浏览器验证及独立只读审查。

## Decisions

- 空白改写视为没有建议；tutor 和 skip 沿用既有保存策略。旧 schemaVersion 1 没有 check 模式，不靠原文相同或说明文案猜测是否应丢弃。
- 日期目录仅按现存文件列出；某日旧记录全部被过滤时显示空状态，不删除文件或目录项。
- 当前工作区有先前未提交功能改动；本次修改前文件副本保存于临时基线目录，最终审查使用本次 scoped diff。

## Target
- [x] T1: 正式复习页采用已确认测试页样式：左侧日期栏，原文与解析同一卡片默认展开，14px内容字号，保留语义配色、圆角、搜索和深浅色支持。
- [x] T2: Writing check没有纠错项且没有改写建议时不再写入JSONL，正式复习页和当前测试页不展示此类结果；有学习内容的其他结果保持正常记录和展示。
- [x] T3: 既有历史文件不删除或重写，原生解析面板行为保留，本地服务和每日JSONL功能正常；完成与改动相称的构建及浏览器验证。

## Result

- T1: evidence/self-check.md、runtime-check.txt及formal-dark/light.png：真实HTTP资源在Chrome中呈现侧栏、同卡片原文解析及14px；日期/搜索/主题/分页/窄屏运行观察通过。
- T2: 实际Swift存储调用：无修改check返回nil且未创建目录或改变既有文件；其他四类示例正常写入。Chrome过滤旧v2空/空白/缺省改写且保留有效内容，当前测试页无不变条目。
- T3: runtime-check.txt：v1全部字段保留、服务重启可读、全部历史文件哈希未变、无令牌403；四个原生模型/协调器/面板/服务文件哈希未变。Debug build和JS语法通过，构建产物三个网页资源与源码逐字一致。
- Review gate: Passed — Fresh独立只读reviewer run 8a119931-5e8b-4d4b-ba61-9533df8c7d05无findings、无阻断风险，报告tasks/artifacts/parsing-history-final-cards/reports/review-1.md；接收后snapshot 10/10及原生4/4哈希均匹配。
## Review Assessment

- Schema: task-review-assessment/v1
- Level: R2
- State: Current
- Reason: 正式持久化策略及历史兼容读取、鉴权页面交互跨模块改变，需要独立检查遗漏。
- Snapshot: tasks/artifacts/parsing-history-final-cards/evidence/snapshot.sha256
- Evidence: tasks/artifacts/parsing-history-final-cards/evidence/self-check.md
- Task fingerprint: 47072a810484e1b2138f556a5aad17040496759e6b95547ad67d0f448bf485fa

## Verification

- Passed: 审查后源码身份匹配、原生消费方未变，JS语法和git diff --check通过。相同版本已完整Debug构建及隔离真实Swift/HTTP/Chrome验证；未运行测试套件，未替换已运行应用。
