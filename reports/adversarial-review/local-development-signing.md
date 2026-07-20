# 对抗审查：使用本地 Apple Development 证书签名

## Overall conclusion

- Result: READY
- Core conclusion: 本地开发签名已配置、构建并通过独立审查。
- Remaining risk: 首次从 ad-hoc 切换后仍需用户重新授权一次；本地开发证书不可用于公开分发。

## Topics reviewed

- 证书有效性与 Team ID 匹配
- 本地配置隔离
- 构建产物签名链与 designated requirement

## Debate results

Reviewer 未提出问题，签名配置与产物符合目标。

## Final conclusion

- Confirmed: 证书有效，配置 Team ID 与产物一致，designated requirement 不再绑定 CDHash。
- Changed: 本机忽略的签名配置从 ad-hoc 改为 Apple Development。
- Unresolved: none
- User decision required: none

## Verification

- `tuist generate` — 成功。
- Debug build — 成功。
- `codesign --verify --deep --strict` — 成功。
- `codesign -dv --verbose=4` — Authority 为 Apple Development，TeamIdentifier 为 `Z4PKY44Q98`。
- `codesign -d -r-` — designated requirement 不包含 CDHash。
- Limitations: 未安装、启动 App 或修改 TCC；未验证 Developer ID 分发签名。

## Technical appendix

### Review metadata

- Gate: APPROVED
- Review state: APPROVED
- Stop reason: approved
- Reviewer: `focus-lifecycle-reviewer`
- Current round: INITIAL (1)
- Updated: 2026-07-20 22:15:00 +0800

### Reviewed scope

- Task: [tasks/todo/local-development-signing.md](../../tasks/todo/local-development-signing.md) — 使用本地 Apple Development 证书签名
- Base or revision: `43a33ba` 加本机忽略配置
- Artifacts: `Configurations/Signing.xcconfig`、Debug `MoePeek.app`
- Fingerprint: 配置 SHA-256 `b790528c6b1ff6a55598e86f862ef4a97478a267ec3d204988a1af5345b3d1f2`；CodeResources SHA-256 `3d3eeb24f9f87c9204c29afaf2950cb7a80c34ed5912fd45d106dd09b24d3582`
- Non-goals: App 安装、启动、TCC 授权、Developer ID 分发签名

### Round history

| Round | State | New findings | Resolved | Unresolved |
|---|---|---|---|---|
| INITIAL (1) | APPROVED | none | none | none |

### Unresolved items

None.

### Approval boundary

- Approval covers only the identified revision and scope.
- Reviewed-artifact changes invalidate approval and resume the same numbered history.
- Report and task-summary synchronization are administrative review records.
- External action authorization: 不安装、启动 App，也不修改 TCC。
