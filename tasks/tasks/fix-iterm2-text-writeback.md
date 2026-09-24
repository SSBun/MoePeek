# 修复 iTerm2 中 Pi 输入区自动回填失败

| Field | Value |
| --- | --- |
| Status | In Progress (2026-09-20 11:21) |
| Artifacts | [Artifacts](../artifacts/fix-iterm2-text-writeback/) |
| Kind | Task |

## Target
- [x] T1: 修复 iTerm2 中 Pi 会话的解析正文自动回填失败，使正文可写回原输入区。
- [x] T2: 回填不自动提交输入，不误写其他窗口或覆盖无关内容。

- [ ] T3: 恢复 iTerm2 中 Pi 回填的同时，保留 ChatWise 回填和失败时剪贴板兜底。

## Decisions

- 用户新反馈：修复 ChatWise 场景后，iTerm2 中 Pi 会话再次无法回填；此前菜单诊断和构建不能作为本次端到端成功证据。
- 当前恢复故障定位，原独立审查义务及 TR-1 端到端证据缺口继续保留。

## Plan

1. 区分 Paste 菜单不可用是剪贴板类型导致的旧状态，还是其他运行时限制。
2. 在保留窗口、控件、选区和剪贴板保护的前提下修复已证实的失败路径。
3. 构建、自查并独立审查；不运行未经用户明确要求的测试。

## Result

- T1: 真实 iTerm2 重现：空剪贴板菜单验证后 disabled，写入文本等待350ms仍 disabled；当前生产 helper 打开/关闭 Edit 后 enabled。只在检测到 Paste 不可用时刷新菜单，保留原有单次 Paste 操作和等待。证据 ../artifacts/fix-iterm2-text-writeback/evidence/menu-refresh.txt；未执行完整正文插入。
- T2: 菜单刷新前后均 validate 原应用/窗口/输入区/选区；真实 iTerm2 诊断验证通过。最终 Paste 前仍检查取消、前台身份、剪贴板 changeCount；无全局键盘事件、Return 或整框赋值。诊断只打开/关闭菜单且恢复原剪贴板，未向 Pi 写入内容。Debug build 及 diff 检查通过；未运行测试。
- Review gate: Required — R2 独立只读审查
## Review Assessment

- Schema: task-review-assessment/v1
- Level: R2
- State: Stale
- Reason: 跨应用原生菜单动作涉及焦点和剪贴板，需独立检查目标保护及单次粘贴边界。
- Snapshot: HEAD 6c7d15526bff997e37daa89b16017d59535929a0; Sources/Core/TextSelection/ParsingPasteTarget.swift sha256:a0175cdaae1148a04064041707eaeb8ade0bfa89a55e4be3bc3e5cf517b4887b; scoped diff ../artifacts/fix-iterm2-text-writeback/evidence/change.diff
- Evidence: Result T1/T2；真实 iTerm2 菜单 helper 诊断、Debug BUILD SUCCEEDED (2.566 sec)、git diff --check；未运行测试或端到端插入。
- Task fingerprint: 7a3b02d638e1d6cdca32cc3c8ce8578c8936e7970035a2ddef8623f23b67ae2d
## Review Reports

| Round | Report | Snapshot | Outcome |
| --- | --- | --- | --- |
| 01 | [第 01 轮](../artifacts/fix-iterm2-text-writeback/reviews/round-01.md) | ParsingPasteTarget.swift sha256:a0175cdaae1148a04064041707eaeb8ade0bfa89a55e4be3bc3e5cf517b4887b | 无已证实代码缺陷；TR-1 端到端证据不足 |

## Review

- Schema: task-review-ledger/v1
- Pass: 1
- Next finding: 2
- `TR-1` | no-progress=0 | T1/T2；evidence/menu-refresh.txt | 补充新版面板到 Pi 的实际正文回填、未自动提交及未影响无关内容的观察或用户复测记录。
