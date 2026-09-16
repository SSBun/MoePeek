# 翻译面板失焦时自动关闭

Status: Completed (2026-09-16 14:47)
Kind: Task

## Target
- [x] T1: 普通翻译面板与单词翻译面板失去焦点时均自动关闭，不抢回焦点。
- [x] T2: 两类面板内部操作保持打开，不改变解析面板的关闭行为。

## Plan
1. 用户已确认同时修复普通与单词翻译面板；补齐单词面板的失焦处理，保留解析面板和共享组件。
2. Debug 构建及两类面板实机交互核验已执行，证据见 [GUI 验证](../artifacts/dismiss-translation-panel-on-focus-loss/evidence/gui-verification.md)。
3. 对当前两文件增量与 GUI 证据执行新一轮独立审查，核对 TR-1，再完成最终验证。

## Result

- T1: 实机验证两类输入面板及普通光标模式：外部 CGEvent 点击、⌘Tab、切换应用后面板计数由1变0且不抢焦点。第二轮后补齐光标模式从非激活状态开始的鼠标、键盘切换及三轮 Esc 重开；GUI 验证文档完整记录。
- T2: 两类输入面板及普通光标模式内部输入、拖动保持打开，普通语言菜单选择保持打开；仅两个控制器为任务增量，共享及解析面板未改；GUI 证据记录 AX 探查失败排除及 CGEvent 实际输入/拖动。
- Review gate: Passed — fresh read-only reviewer 6b788c03-e492-4a06-977a-7c309220632e：Findings none，TR-1 resolved，无 Target 阻塞风险；主 Agent 重新核对两源码及 GUI 证据 SHA256 均一致。
## Review Assessment

- Schema: task-review-assessment/v1
- Level: R2
- State: Current
- Reason: 保留独立审查要求，源码未变，补齐上轮光标模式证据缺口。
- Snapshot: PopupPanelController.swift SHA256 8465080bdf0de28d59ae1b5928d9cd2df92e72bc7e5e06743ee8ececc8a8631c；WordLookupPanelController.swift SHA256 664dc911cba2dc83e8fbb6a481a8968438627f5d548c29f2fa97da610676cc12；GUI evidence SHA256 3e17bbd2e68a7140c423500a9cd7c93b548e06139ae43d574c5c3c6fcc9aa463；任务增量 /tmp/moepeek-both-focus-review.diff。
- Evidence: 两控制器内容无漂移；原 Debug build 成功；新补全 GUI 矩阵覆盖光标模式 TR-1 项。未运行项目测试。
- Task fingerprint: b7ec14112ccc0750ee3ca7304017e1c2f79d878086744aea475a32dfb3734534

## Verification

- Passed: 独立复查后两源码及 GUI 文档 SHA256 与审查快照一致；swiftc -parse、git diff --check 和 Context validate 通过。当前构建的两类输入面板/普通光标模式实机矩阵已覆盖失焦、内部交互、关闭重开及最终焦点；未运行单元测试/项目套件，多显示器和 Spaces 未覆盖。
