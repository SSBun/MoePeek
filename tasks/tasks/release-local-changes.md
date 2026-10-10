# 提交全部本地改动并发布新版本

| Field | Value |
| --- | --- |
| Status | In Progress (2026-10-10 15:58) |
| Kind | Task |

## Target

- [ ] T1: 全部本地改动经检查后提交到 Git，新版本包含这些改动。
- [ ] T2: 发布 0.15.0（build 5），版本信息与远程发布产物一致且经过验证；采用开发签名、未公证，本次不提供 Sparkle 自动更新。

## Scope

包含全部本地改动及当前分支已有未推送提交。用户已明确接受开发签名、未公证及无自动更新的发布限制。不得输出或提交密钥；不运行测试套件。远程修改需独立具体清单确认。

## Plan

1. 更新版本与发布说明，检查全部待提交内容。
2. 使用已有脚本构建 Release DMG，验证实际版本、签名、架构与校验值，准备 ZIP 和 PopClip 产物。
3. 提交本地改动，展示远程操作与产物清单；经确认后临时停用自动 Release workflow，发布标签和产物，再恢复 workflow。
4. 独立下载验证远程产物，核对 main、tag 与发布版本并记录结果。

## Decisions

- 用户确认发布 0.15.0（build 5），接受开发签名、未公证且无 Sparkle 自动更新。
- origin 为公开仓库 SSBun/MoePeek，main 有 34 个尚未推送提交；远端 main 查询为 cdb57379769d84be9d1500991a11d25acb1a1222。
- 远端 Prod 环境未列出 secrets，现有 tag workflow 会自动构建并发布；本次拟采用本机产物手动发布，临时停用与恢复 workflow 必须列入远程确认。

## Preparation

- 既有 scripts/create-dmg.sh 0.15.0 执行成功；最终 App 为 0.15.0（5）、macOS 14.0、x86_64 + arm64。
- 实际 App 与只读挂载 DMG 的 codesign --verify --deep --strict 通过；挂载包内版本正确且主可执行文件与构建产物一致。签名为 Apple Development，非 Developer ID，未公证。
- DMG hdiutil verify 与两个 ZIP 的 unzip -tq 通过；未运行测试套件。34 个未推送提交差异的常见凭据模式扫描未匹配，不代表完整秘密检测。
- disk/MoePeek-v0.15.0-2026-10-10.dmg：6166880 bytes；SHA256 2696940b310d772a7cadd8ca0354c7478a47a537a19b051a85aa39eeea4df0e6。
- disk/MoePeek-v0.15.0-macOS.zip：6316937 bytes；SHA256 41ea68ec599585817e4f4e3743aa0e7821544a43183d249c60551ea145ce8f9b。
- disk/MoePeek.popclipext.zip：1078 bytes；SHA256 520c9868d77fd188da0ff07d04de98da00f6994c69258cbb917811e8418ec896。
- disk/SHA256SUMS 包含上述三个产物的 SHA256。产物目录被 Git 忽略，仅作为 Release 附件，不提交二进制。
- 下一步：本地提交后请求具体远程动作确认；尚未创建或推送标签、创建 Release、上传或修改 workflow 状态。
