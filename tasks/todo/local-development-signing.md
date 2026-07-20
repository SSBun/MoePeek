# 使用本地 Apple Development 证书签名

## 状态

- 已完成（2026-07-20）

## 目标

- [x] 将本机忽略的 `Configurations/Signing.xcconfig` 从 ad-hoc 切换到有效的 Apple Development 证书。
- [x] 生成项目并成功构建 Debug App。
- [x] 验证 App 的签名链、Team ID 与稳定 designated requirement。
- [x] 通过独立对抗审查。

## 边界

- 签名配置保持在 `.gitignore` 中，不提交个人证书信息。
- 不安装或启动 App，不修改 TCC 权限数据库。
- 本地开发签名不替代公开分发所需的 Developer ID Application 签名。

## Review status

- Gate: APPROVED
- State: APPROVED
- Reviewer: focus-lifecycle-reviewer
- Round: 1
- Scope: 本机签名配置与 Debug App 签名产物
- Summary: Apple Development 签名构建与验证成功，独立审查无发现。
- Unresolved: none
- Report: [Adversarial review report](../../reports/adversarial-review/local-development-signing.md)

## 验证

- `tuist generate` 成功。
- Debug build 成功。
- `codesign --verify --deep --strict` 成功。
- App 签名 Authority 为 Apple Development，TeamIdentifier 为 `Z4PKY44Q98`。
- designated requirement 由 Bundle ID、Apple 信任链与证书 CN 构成，不再绑定构建 CDHash。
