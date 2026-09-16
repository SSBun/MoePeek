# JSONL 解析历史与本地英语复习页面

Status: Completed (2026-09-16 10:56)
Kind: Task

## Scope

- 延续用户已确认的 JSONL、本地服务、浏览器学习页范围；旧 Markdown 保留，不迁移。
- 保留开始时已有未提交改动；不运行单元测试或项目测试套件，不调用付费模型生成验证数据。

## Plan

1. 将现有完整解析结果按日持久化为结构化 JSONL。
2. 添加仅本机可访问的只读服务及应用入口，实现离线学习页面。
3. 通过 Debug 构建、语法检查及隔离数据的手动运行检查验证；完成独立只读审查。

## Decisions

- 现有结果字段是英文正文、自然表达、提示、词汇和语法；页面展示已有内容，不为了“译文”额外请求模型或虚构字段。
- 服务按需启动，动态端口、令牌鉴权、来源检查和固定资源路由；退出应用关闭。
- 开始时已有未提交变更涉及解析存储、协调器、面板、设置、本地化和中文 README。
- StyleKit 参考站访问被网络安全过滤拒绝，采用无外部依赖的简洁阅读样式，不宣称套用了该站主题。

## Target
- [x] T1: 新解析按日追加 JSONL，重启后可读取，停止新增 Markdown 历史且保留既有文件。
- [x] T2: 从 MoePeek 打开浏览器复习页面，支持按日期浏览、搜索及展开译文与解析。
- [x] T3: HTTP 服务只监听本机回环地址，仅暴露复习资源和历史读取接口，随应用退出停止。

## Result

- T1: evidence/self-check.md：实际 Swift 存储与 HTTP 预览验证 JSONL 完整字段、损坏尾行隔离、重启字节一致及旧 Markdown 保留；snapshot.sha256 绑定源码。
- T2: evidence/self-check.md 与 browser-preview.png：Debug build、JS/JSON 语法检查通过；Chrome 实际日期切换、搜索、折叠、刷新、重新加载和窄屏观察通过；原生入口仅源码和构建验证。
- T3: evidence/self-check.md：lsof 确认 127.0.0.1，HTTP 越权/跨站/方法/路径穿越/符号链接检查与 stop 后端口关闭观察符合预期；退出钩子调用 stop。
- Review gate: Passed — 独立 fresh 只读 reviewer run 8661a319-2f71-4a7b-8bc6-7e69ee5aa988 无 findings、无阻断风险；报告 tasks/artifacts/parsing-history-web-review/reports/review-1.md。审查前后及接收时 manifest 13/13 哈希一致。
## Review Assessment

- Schema: task-review-assessment/v1
- Level: R2
- State: Current
- Reason: 持久化、HTTP 隐私边界、浏览器渲染和原生生命周期跨模块改动。
- Snapshot: tasks/artifacts/parsing-history-web-review/evidence/snapshot.sha256
- Evidence: tasks/artifacts/parsing-history-web-review/evidence/self-check.md
- Task fingerprint: a578fd4e0deab081af688e7bafa8112cc09ff796fa7515a8d659073552b2b3db

## Verification

- Passed: 最终 manifest 13/13 哈希匹配，node --check、JSON 语法、git diff --check 通过；相同代码已通过完整 Debug 构建及隔离真实 Swift/HTTP/Chrome 运行检查（self-check.md），独立审查无问题。未运行单元测试或项目套件，原生菜单交互未手动验证。
