# Adversarial Review: 发布 MoePeek 0.13.0

## Overall conclusion

- Result: READY
- Core conclusion: Apple Development 签名的 `0.13.0 (2)` App 与 DMG 已生成、验证、打开并获批作为本地构建结果使用。
- Remaining risk: 未安装到 `/Applications`；未使用 Developer ID Application 签名、未 notarize；不通过 Sparkle 自动更新分发。

## Topics reviewed

- CI DMG 生成与验证
- 版本与 build number source of truth
- 发布说明完整性与仓库元数据一致性
- Codex 流式完成语义
- 用户可见功能的发布验证证据

## Debate results

### R1 — CI 吞掉 DMG 失败且不验证工件

- Reviewer position: `.github/workflows/release.yml` 接受 `create-dmg` 的退出码 1，且不检查文件、验证 DMG 或生成 checksum。
- Editor response: 已删除退出码 1 的豁免，并在 CI 中显式检查 DMG 存在、执行 `hdiutil verify` 与输出 SHA-256。
- Evidence: workflow 的 Create DMG step 现在失败即停止，验证逻辑与本地脚本一致。
- Debate conclusion: ACCEPTED_AND_FIXED
- Final impact: CI 不再继续发布缺失或未验证的 DMG。
- Status: RESOLVED

### R2 — CI 覆盖已审查的 build number

- Reviewer position: workflow 用 `github.run_number` 覆盖 `Project.swift` 的 build `2`。
- Editor response: 已移除 workflow 的 `CURRENT_PROJECT_VERSION=${{ github.run_number }}` 覆盖，让 `Project.swift` 的 build `2` 成为 source of truth。
- Evidence: CI 仍从 tag 注入 marketing version，但 build number 只来自项目版本文件。
- Debate conclusion: ACCEPTED_AND_FIXED
- Final impact: 本地与 CI 工件使用同一 build number。
- Status: RESOLVED

### R3 — CHANGELOG 漏掉用户可见变更

- Reviewer position: 自 `v0.12.1` 后的翻译历史、错误 toast 和首字母大写设置未记录。
- Editor response: 已补充翻译历史、结果首字母大小写选项和错误 toast 三项用户可见变更。
- Evidence: `CHANGELOG.md` 的 0.13.0 Added 条目覆盖上述功能。
- Debate conclusion: ACCEPTED_AND_FIXED
- Final impact: 发布说明覆盖自上一版本以来的主要用户可见变更。
- Status: RESOLVED

### R4 — canonical 发布仓库不一致

- Reviewer position: CHANGELOG/`origin` 指向 `SSBun/MoePeek`，README、Sparkle feed 和 workflow 指向 `cosZone/MoePeek`。
- Editor response: 用户确认 fork `SSBun/MoePeek` 是 canonical 项目；已迁移 README、Sparkle feed、GitHub Actions、发布文档、PopClip 文档、OpenRouter referer 和应用内项目链接。
- Evidence: 两组发布元数据不能同时描述同一公开版本。
- Debate conclusion: ACCEPTED_AND_FIXED
- Final impact: 应用更新链路、下载链接、文档与远端发布目标统一指向 `SSBun/MoePeek`。
- Status: RESOLVED

### R5 — Codex incomplete 事件被当作成功

- Reviewer position: `response.incomplete` 与 `response.completed` 共用成功路径且无回归测试。
- Editor response: 已将 `response.incomplete` 改为抛出 Provider 错误，不再设置完成状态，并新增回归断言。
- Evidence: `CodexProviderTests.testStreamRejectsMalformedAndErrorEvents` 覆盖 incomplete；全量测试通过。
- Debate conclusion: ACCEPTED_AND_FIXED
- Final impact: 不完整响应进入错误 UI，不会作为成功译文展示。
- Status: RESOLVED

### R6 — 两项用户功能缺少发布验证证据

- Reviewer position: 当前测试未覆盖默认输入法及 `⌘1…9` 与可见结果映射、复制、关闭行为。
- Editor response: 已新增默认输入源聚焦应用测试，以及错误/完成结果混排时快捷键仍按可见卡片序号映射的测试。
- Evidence: 全量测试增至 9 个并全部通过；输入源测试在 `defer` 中恢复系统输入源与 Defaults。
- Debate conclusion: ACCEPTED_AND_FIXED
- Final impact: 两项用户可见功能具有可复现回归证据。
- Status: RESOLVED

## Final conclusion

- Confirmed: R1–R6 已解决并通过 9/9 测试；独立 Reviewer 在 RE-REVIEW（3）返回 `APPROVED`。
- Changed: CI DMG/build 流程、CHANGELOG、Codex incomplete 处理及两项针对性测试。
- Unresolved: none
- User decision required: none

## Verification

- `tuist generate` — 成功。
- `xcodebuild test -workspace MoePeek.xcworkspace -scheme MoePeek -configuration Debug` — 9 个测试、0 失败。
- `scripts/create-dmg.sh 0.13.0` — Release archive 与 DMG 生成成功。
- `hdiutil verify disk/MoePeek-v0.13.0-2026-07-20.dmg` — 通过。
- `codesign --verify --deep --strict build/app/MoePeek.app` — 通过；Authority 为 Apple Development，TeamIdentifier 为 `Z4PKY44Q98`。
- DMG SHA-256 — `f2d959aaa49bb312737e5fb453d308097b00607f9354b83ab92859f14fc69191`。
- `open disk/MoePeek-v0.13.0-2026-07-20.dmg` — 成功挂载到 `/Volumes/MoePeek`。
- Limitations: 未执行 Developer ID 签名、Apple notarization、tag、push 或远端 Release。
- Remote readiness: `SSBun/MoePeek` 的 `Prod` 环境存在但没有可见 secrets；workflow 要求 `SIGNING_CERTIFICATE_P12`、`SIGNING_CERTIFICATE_PASSWORD`、`SIGNING_IDENTITY`、`DEVELOPMENT_TEAM`、`SPARKLE_ED_PUBLIC_KEY`，Sparkle 私钥可选。

## Technical appendix

### Review metadata

- Gate: APPROVED
- Review state: APPROVED
- Stop reason: approved
- Reviewer: `release-0-13-0-reviewer`
- Current round: RE-REVIEW (5)
- Updated: 2026-07-20 22:45:00 +0800

### Reviewed scope

- Task: [tasks/todo/release-0.13.0.md](../../tasks/todo/release-0.13.0.md) — 发布 MoePeek 0.13.0
- Base or revision: `origin/main` (`d3064b2`) 到当前 `HEAD` (`5c711a5`) 加工作区变更
- Artifacts: `origin/main..HEAD` 的 3 个本地提交、当前 tracked/untracked 项目文件、`build/app/MoePeek.app`、`disk/MoePeek-v0.13.0-2026-07-20.dmg`
- Fingerprint: SHA-256 `227309b8886c3ea822ffd26eaa08226828a0f5ea0386d0307b6891a16cbf83d5`（排除 `tasks/` 与 `reports/` 管理记录）
- Follow-up fingerprint: SHA-256 `f13a094f7deb15b3cc9b94836389cdd6c8423b15ab27c5fbf0b00fdaeadbef71`（`a605fc5` 后新增修订，排除 `tasks/` 与 `reports/` 管理记录）
- Non-goals: 安装到 `/Applications`、Developer ID 签名、notarization、远端 tag/push/Release

### Round history

| Round | State | New findings | Resolved | Unresolved |
|---|---|---|---|---|
| INITIAL (1) | CONTINUE | R1–R6 | none | R1–R6 |
| RE-REVIEW (2) | NEEDS_USER | none | R1–R3, R5–R6 | R4 |
| RE-REVIEW (3) | APPROVED | none | R4 | none |
| RE-REVIEW (4) | APPROVED | none | follow-up | none |
| RE-REVIEW (5) | APPROVED | none | 新 DMG 工件 | none |

### Unresolved items

none

### Approval boundary

- Approval covers only the identified revision and scope.
- Reviewed-artifact changes invalidate approval and resume the same numbered history.
- Report and task-summary synchronization are administrative review records.
- External action authorization: 用户已要求发布，但具体 remote/branch/tag/upload 命令仍待确认。
