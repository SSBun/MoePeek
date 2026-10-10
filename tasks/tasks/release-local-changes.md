# 提交全部本地改动并发布新版本

| Field | Value |
| --- | --- |
| Status | Completed (2026-10-10 16:09) |
| Kind | Task |

## Target
- [x] T1: 全部本地改动经检查后提交到 Git，新版本包含这些改动。
- [x] T2: 发布 0.15.0（build 5），版本信息与远程发布产物一致且经过验证；采用开发签名、未公证，本次不提供 Sparkle 自动更新。

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
- 发布提交：4b052fb1a71031ccdf46a979649ca61fe413f197（release: prepare v0.15.0）；用户确认具体远程操作清单后执行发布。
- 已临时停用 workflow 254194530，推送 annotated tag v0.15.0，创建非草稿、非预发布 Release；四个附件独立下载后 SHA256SUMS 检查通过，与本地逐字节一致，公开 URL 均 HTTP 200。远程下载 DMG 的 hdiutil verify 与 App ZIP 的 unzip -tq 通过。
- 远端 main 与 v0.15.0 解引用均为发布提交 4b052fb1a71031ccdf46a979649ca61fe413f197；workflow 已恢复 active。本次没有上传 appcast，也没有执行公证。
- Release：https://github.com/SSBun/MoePeek/releases/tag/v0.15.0。
- 发布完成后的任务验证记录将用单独 bookkeeping commit 推送；不会修改 v0.15.0 标签或安装产物。

## Result

- T1: 全部原有未提交文件及版本/CHANGELOG/任务记录已提交至 4b052fb1a71031ccdf46a979649ca61fe413f197；此前 34 个提交连同发布提交已推送 origin/main，远端读取确认 main 与 v0.15.0 解引用相同。最终任务记录另作 bookkeeping 提交，不改变发布字节。
- T2: GitHub v0.15.0 非 draft、非 prerelease；4 个公开附件均 HTTP 200，独立下载 SHA256SUMS 通过并与本地逐字节一致；DMG/ZIP 完整性通过；实际 App 0.15.0(5)、macOS14、x86_64+arm64、深度签名验证通过。开发签名/未公证/无 Sparkle 更新已获用户确认并写入发布说明。workflow 254194530 已恢复 active。未运行测试及 GUI 验收。
- Review gate: Skipped — R1：既有构建/发布流程与版本元数据，四项具体依据及本地/远程验证已记录；未要求独立审查。
## Review Assessment

- Schema: task-review-assessment/v1
- Level: R1
- State: Current
- Reason: 本任务增量为版本、发布说明及既有构建流程的已授权发布；已有智能复制代码沿用此前已验证成果，不新增签名、权限或发布基础设施实现。
- Snapshot: release commit 4b052fb1a71031ccdf46a979649ca61fe413f197; tag object d942e3ea2a17e09072b4045888fb848d36d95dde; DMG sha256 2696940b310d772a7cadd8ca0354c7478a47a537a19b051a85aa39eeea4df0e6; ZIP sha256 41ea68ec599585817e4f4e3743aa0e7821544a43183d249c60551ea145ce8f9b; PopClip sha256 520c9868d77fd188da0ff07d04de98da00f6994c69258cbb917811e8418ec896; SHA256SUMS sha256 5e92dd7af8f1b7051176cfe1616f256fc1edd31a4642dec6a8df7e97c67edc15
- Evidence: Preparation 与 T1/T2；本地 Release 构建、挂载验证、深度签名、远程附件逐字节对照及远端 refs/API。
- Result clarity: 版本0.15.0(5)、全部本地提交、开发签名、未公证及无自动更新均已获得明确接受和具体发布确认。
- Bounded impact: 本任务仅版本/文案更新、已有源代码打包与首次版本发布；没有覆盖旧附件或旋转更新密钥，未修改 release workflow 文件。
- Low risk: 没有生产数据迁移或客户端自动更新投放，下载者需主动手动安装；签名限制公开，workflow 临时停用已恢复，常见凭据模式扫描未匹配。
- Sufficient verification: 全量 Release archive 成功；实际包版本架构及签名有效，远端四附件大小非零、SHA256和逐字节对比一致，公开HTTP200、refs一致；不声称测试或GUI验收通过。
- Task fingerprint: 4226f676c2cfd4495ad6f91f8d345834fc31627cc93936dc053c466970e5c7e4

## Verification

- Passed: 最终 GitHub API 复查 tag=v0.15.0、draft=false、prerelease=false，四附件 digest 与 assessment 一致；安装代码及产物自验证后未变化，Context 与 diff 检查通过。发布无 Sparkle、未公证限制已披露。
