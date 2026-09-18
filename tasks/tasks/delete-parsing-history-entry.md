# 为复习记录添加本地删除入口并解释跳过记录来源

Status: In Progress (2026-09-17 14:27)
Kind: Task

## Scope

解释 skip 记录来源并增加单条删除入口；不改变 append 的记录筛选规则，不批量清理历史，验证只用临时目录中的合成数据。保留已有未提交改动。

## Plan

1. 增加按日期及 UUID 定位的本地删除能力，保留其他 JSONL 行的原始字节并清理对应复习状态。
2. 保证删除和追加、复习状态修改的写入互斥，历史文件原子替换，拒绝非法路径及非普通文件。
3. 提供经现有令牌和来源校验保护的删除接口；前端添加图标、确认、失败提示与成功刷新。
4. 使用临时数据进行构建与 HTTP 手工冒烟核对，不运行测试套件、不读取或删除真实历史。
5. 记录主 Agent 自查证据，执行 R2 独立只读评审并处理发现。
6. 针对用户现场失败核对运行进程与构建产物；确认安全重启后更新实际进程，重新核对接口与页面版本，不操作真实历史。

## Target
- [x] T1: 说明截图中未执行解析的记录为何进入复习历史。
- [x] T2: 复习卡片提供删除图标，用户操作后对应记录从本地持久化存储删除，刷新或重启后不再出现，其他记录不受影响。
- [ ] T3: 用户现场报告的删除失败得到定位和修正，重新验证删除功能可用，仍不操作用户真实历史。

## Decisions

- 现场只读核对：监听 18765 的 MoePeek PID 63898 于 13:35:07 启动；当前磁盘 debug dylib 于 14:04:54 构建。运行进程映射 dylib 的 inode 为 478357224，而磁盘文件为 478426990，证明实际进程仍加载旧代码；其 GET /history.js 已返回含删除路径的新资源，前后端版本错配。
- 未向真实历史接口发送删除或读取历史内容。下一步需退出并启动当前构建；重启会中断正在进行的解析，先让用户确认。

## Result

- T1: 源码链路确认 skip 是完整结果，append 只排除无修改 check；页面也接受 skip。说明已写入 README_zh.md，本任务保留原筛选规则。详见 ../artifacts/delete-parsing-history-entry/evidence/observations.md。
- T2: 当前快照通过 Debug 构建与 JS 语法/差异检查；临时服务浏览器确认删除、取消、其他原始字节保留、状态清理、拒绝无令牌/错误 Origin、并发追加不丢失及重启持久化均已观察。证据与限制见 ../artifacts/delete-parsing-history-entry/evidence/observations.md，未运行测试套件或操作真实历史。
- Review gate: Required — Task reopened; rerun the applicable review after revisions
## Review Assessment

- Schema: task-review-assessment/v1
- Level: R2
- State: Stale
- Reason: 新增破坏性单条持久化删除接口及跨进程写入锁，涉及数据完整性与授权边界，需独立只读评审。
- Snapshot: tasks/artifacts/delete-parsing-history-entry/evidence/snapshot.json：六文件 SHA256；current.patch 为当前总差异，pre-task.patch 标识任务前差异。
- Evidence: ../artifacts/delete-parsing-history-entry/evidence/observations.md：逐 Target 核对、临时浏览器/HTTP/并发/重启观察及验证限制。
- Task fingerprint: 7ab5bec12e51c3d4068098c8656240bd2033f9c50de7a8c79c2227152a2c451c
