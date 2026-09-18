# 固定内置解析历史复习网站端口

Status: Completed (2026-09-17 11:18)
Kind: Task

## Scope

仅修改本机复习服务端口及对应说明；保留回环绑定、会话令牌、来源校验和现有启动失败处理，不触碰已有前端未提交改动。

## Plan

1. 将监听端口固定为 18765，不提供随机端口回退。
2. 同步现有端口说明并核对启动入口、地址生成和来源校验。
3. 执行 Debug 构建、差异检查及非测试验证，记录限制后完成。

## Target
- [x] T1: MoePeek 内置解析历史复习网站使用固定端口，重启应用或复习服务后端口保持一致。

## Result

- T1: 源码对照确认每次 startListener 都将 requiredLocalEndpoint 绑定至 IPv4 loopback:18765，不再使用 .any；URL、Host、Origin 继续取 listener.port，所有启动入口共用此实现且无随机回退。Debug xcodebuild build 成功，git diff --check 与 Context validate 通过。未运行测试或实际重启应用，重启端口不变由固定绑定路径直接核对。
- Review gate: Skipped — R1 四项依据完整；固定端口参数及对应说明已对照，安全校验无差异，无独立评审要求。
## Review Assessment

- Schema: task-review-assessment/v1
- Level: R1
- State: Current
- Reason: 固定监听端点参数并同步说明；未改生命周期、授权或数据读写逻辑。
- Snapshot: 未暂存差异；Sources/Utilities/ParsingHistoryServer.swift SHA256=124b37ee69eaed8d557021827c99a0788b090c5a901a00d78bfbfc035e293919；README_zh.md SHA256=61c25bb7dd69acc3bd87e3252d87cc9d0edde8ed57ac0503f19b5cbc12c53c92
- Evidence: T1 源码对照、Debug 构建成功及 git diff --check。
- Result clarity: 用户确认固定端口且重启保持一致；唯一绑定参数现为 18765。
- Bounded impact: 检查完整 server 和 coordinator 启动/打开入口；URL 和来源校验仍读取实际监听端口，冲突沿用既有失败路径。
- Low risk: 只改变端口选择；回环限制、令牌、来源校验及存储完全保留；冲突仅导致可恢复的服务不可用。
- Sufficient verification: Debug 构建成功；直接差异核对固定端点在每次启动均使用同一字面量，没有备用随机端口。未运行测试及 GUI 重启验证。
- Task fingerprint: d1b0810ec26310c211e54007384036d030dc94000fed6c0089ff69cceb3ecea6

## Verification

- Passed: 最终文件 SHA256 与评估一致；git diff --check、swiftc -parse 成功；Debug 构建通过后源码未变。未运行测试、未启动或重启 GUI 应用。
