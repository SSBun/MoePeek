# 应用启动时自动启动复习服务

Status: Completed (2026-09-16 14:09)
Kind: Task

## Target
- [x] T1: MoePeek 启动时自动启动本机复习服务，无需先点击英语复习入口。
- [x] T2: 自动启动不打开浏览器，应用退出时仍停止服务。

## Plan

1. 将既有服务启动接入应用启动生命周期，保留手动打开与退出清理路径。
2. 核对任务差异、构建和生命周期调用链，不运行测试套件。

## Result

- T1: 逐行对比任务前副本 /tmp/moepeek-review-autostart-before：AppDelegate.applicationDidFinishLaunching 无条件新增 startHistoryService 调用；该方法在 MainActor Task 中调用既有 historyServer.start，不依赖用户点击或权限分支。Debug xcodebuild 成功（/tmp/moepeek-review-autostart-build.log）。
- T2: 任务差异仅为启动调用及13行后台启动方法；无 NSWorkspace.open/弹窗调用，openHistory 及 applicationWillTerminate 中 historyServer.stop 均原样保留。已有 MoePeek 进程运行，未重启用户应用；未实测启动日志、浏览器或退出。
- Review gate: Skipped — R1：两处局部接入，现有 server 生命周期及安全边界不变；任务前后差异和 Debug 构建足以验证该接入，未要求独立审查。
## Review Assessment

- Schema: task-review-assessment/v1
- Level: R1
- State: Current
- Reason: 仅接入既有幂等服务的启动生命周期，不修改网络、认证、存储或退出实现。
- Snapshot: AppDelegate.swift SHA256=1de7cbad80fe3dc536cb4ad829b67539d29574538cc915dc33cd17be84ca0a89; ParsingCoordinator.swift SHA256=238fb446bd9efe5ac107e3ef9a51334befd771aaf42f3b165670f9eff63b4188; 任务前副本 /tmp/moepeek-review-autostart-before
- Evidence: 任务前后精确 diff、现有 service.start/stop 调用链核对、Debug 构建成功、git diff --check 通过。
- Result clarity: 目标是应用启动即调用现有服务，不打开浏览器，需求无歧义。
- Bounded impact: 两处局部新增，无条件启动入口加后台 Task，消费者仍共享同一 server。
- Low risk: 复用既有 loopback/令牌校验及幂等 start；启动失败仅固定日志，不改变数据，手动入口可重试。
- Sufficient verification: 源码差异确认启动挂接及无浏览器调用、退出清理未变；Debug 编译链接通过。未执行运行中应用重启或测试套件，日志与运行效果未直接观察。
- Task fingerprint: 5b41c6a66b7e3a8aa02eb385253e79d09762abf01a6a83c7f9ddff617c5e0ad9

## Verification

- Passed: 最终两文件 SHA256 与评估一致；Debug 构建成功，任务前后差异、无浏览器启动路径、退出 stop 保留均已核对；diff 与 Context 校验通过。未重启正在运行的用户应用，未运行测试套件或实测日志。
