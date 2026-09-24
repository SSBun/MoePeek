# 应用启动时自动启动复习服务

| Field | Value |
| --- | --- |
| Status | Completed (2026-09-20 10:24) |
| Kind | Task |

## Target
- [x] T1: MoePeek 启动时自动启动本机复习服务，无需先点击英语复习入口。
- [x] T2: 自动启动不打开浏览器，应用退出时仍停止服务。
- [x] T3: 重新核实并确保当前 MoePeek 启动后自动启动本机历史复习服务，无需点击复习入口，也不自动打开浏览器。

## Plan

1. 重新核实当前应用启动、服务监听、浏览器打开及退出清理调用链；已有实现满足目标时不重复修改。
2. 只读检查运行进程、本机监听及复习页 HTTP 响应，记录未重启实测的限制，不运行测试套件。

## Result

- T1: 当前 MoePeekApp 使用 NSApplicationDelegateAdaptor(AppDelegate.self)；AppDelegate.applicationDidFinishLaunching 第48行无条件调用 startHistoryService，后者后台 await historyServer.start，不依赖复习入口或权限分支。本次未修改源码、未构建、未重启实测冷启动。
- T2: 当前 startHistoryService 无浏览器调用；NSWorkspace.shared.open 仅在手动 openHistory 中；applicationWillTerminate 第68行保留 historyServer.stop。本次为源码核对，未实际退出应用。
- T3: 启动调用链现已满足自动启动且不打开浏览器；lsof 确认运行中的 MoePeek PID 91563 监听 127.0.0.1:18765，curl 读取 /index.html 返回 HTTP 200。已有实现无需修改；当前监听不能单独证明冷启动，本次未重启应用或运行测试。
- Review gate: Skipped — R0 无交付变更；源码调用链与当前服务 HTTP 响应已核实，无独立审查要求。
## Review Assessment

- Schema: task-review-assessment/v1
- Level: R0
- State: Current
- Reason: 本次仅重新核实已有实现及只读 HTTP 可用性，无交付文件变更；保留用户原有未提交改动。
- Snapshot: R0只读核实；AppDelegate SHA256=df7d801a79873a907223694f054511fef6bde69003b93c9a5d1a7bc5a6e06d15；ParsingCoordinator SHA256=ffa9ca3d22be2e57fae9298466b6d35d8e27a89c92da45ae4c649390b90f9fa2；ParsingHistoryServer SHA256=64285ff55d1a7030a6f5454fd81bcba6f7ad2d96f141c76928bfed92c7d8d532
- Evidence: T1-T3：启动/退出/浏览器调用链源码核对；运行 PID 91563 监听回环端口18765，复习页 HTTP 200；未冷启动实测、构建或测试。
- Task fingerprint: cb9b17f1e09860819c5bad5a70a6f28743a40be73b070ef9393afd94d286c615

## Verification

- Passed: 最终三个源码 SHA256 与评估一致；复习页再次 HTTP 200；本次任务记录 diff --check 与 Context validate 通过。源码已具备启动服务、不打开浏览器及退出停止链路，无需代码变更；未重启、未构建、未运行测试。
