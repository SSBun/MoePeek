# 发布 MoePeek 0.13.0

## 状态

- 进行中（2026-07-20）

## 目标

- [x] 将 marketing version 从 `0.12.1` 升级到 `0.13.0`，build number 从 `1` 升级到 `2`。
- [x] 为本次用户可见变更新增发布说明。
- [x] 修正并执行现有 DMG 打包脚本，验证 Release App、DMG、版本、build number 与签名。
- [x] 对最终变更执行独立对抗审查并提交全部本地改动。
- [x] 将现有 `AGENTS.md` 纳入仓库，并从远端 Release 流程移除 Sparkle appcast 生成与上传。
- [x] 使用本地 Apple Development 证书重建、验证并打开 DMG。
- [ ] 在明确确认后创建 `v0.13.0` tag、push 并发布远端 Release。

## 边界

- 本次提交包含 `origin/main..HEAD` 的 3 个本地提交及当前工作区全部项目改动。
- 远端动作必须在列出 tag、remote/branch 和上传命令后再次确认。
- 未执行 Apple notarization 时必须在发布结果中明确说明。

## Review status

- Gate: APPROVED
- State: APPROVED
- Reviewer: release-0-13-0-reviewer
- Round: 5
- Scope: `v0.13.0` 版本元数据、发布说明、DMG 脚本、应用改动、测试与发布工件
- Summary: Apple Development 签名 DMG 已生成、验证、打开并通过 Reviewer 复审。
- Unresolved: none
- Report: [Adversarial review report](../../reports/adversarial-review/release-0.13.0.md)

## 验证

- `tuist generate` 成功。
- Debug 完整测试成功：9 个测试、0 失败。
- Release archive 成功；App 为 `0.13.0 (2)`、universal `arm64+x86_64`。
- `codesign --verify --deep --strict` 成功；当前为 Apple Development 签名，TeamIdentifier 为 `Z4PKY44Q98`，未 notarize。
- DMG 验证成功，SHA-256：`f2d959aaa49bb312737e5fb453d308097b00607f9354b83ab92859f14fc69191`。
- DMG 已通过 `open` 挂载到 `/Volumes/MoePeek`。
- `SSBun/MoePeek` 的 `Prod` 环境存在但没有可见 secrets；当前 tag 工作流要求四个代码签名 secrets，远端发布前必须补齐。
- Follow-up 全量测试成功：9 个测试、0 失败；workflow YAML 解析、`tuist generate` 与 `git diff --check` 成功。
- Sparkle appcast 已移出发布流程；远端只需四个代码签名 secrets。
