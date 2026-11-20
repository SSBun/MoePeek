# 在本机安装 MoePeek 0.15.0

| Field | Value |
| --- | --- |
| Status | Completed (2026-10-10 16:27) |
| Kind | Task |

## Target
- [x] T1: 本机 Applications 中安装已发布的 MoePeek 0.15.0（build 5），验证安装版本与签名并启动新版本。
- [x] T2: 替换前退出旧实例并备份已有应用，保留用户设置和历史数据。

## Result

- T1: 已从发布DMG安装到 /Applications/MoePeek.app；PlistBuddy读取0.15.0(5)，codesign --verify --deep --strict通过，可执行文件与DMG内逐字节一致；open成功，进程97720路径为已安装应用。仅验证启动进程，未进行GUI功能验收。
- T2: 通过AppleScript正常退出原0.14.0实例并等待退出；旧包保存在 /Applications/MoePeek-backup-20261010-162732.app。只替换应用包，未操作用户设置、历史数据或Gatekeeper。DMG已卸载。
- Review gate: Skipped — R1可回滚本地安装，已验证产物身份、签名、版本及启动，无独立审查要求。
## Review Assessment

- Schema: task-review-assessment/v1
- Level: R1
- State: Current
- Reason: 安装已发布且校验一致的应用包，旧应用完整备份，未修改源代码或用户数据。
- Snapshot: DMG SHA256=2696940b310d772a7cadd8ca0354c7478a47a537a19b051a85aa39eeea4df0e6; installed=/Applications/MoePeek.app; version=0.15.0(5); backup=/Applications/MoePeek-backup-20261010-162732.app
- Evidence: T1/T2；DMG哈希、包版本、深度签名、cmp与pgrep观测。
- Result clarity: 用户已确认安装0.15.0(5)、备份旧版本并启动。
- Bounded impact: 仅旧包改名与新包复制，不写用户设置或历史。
- Low risk: 可通过完整旧应用备份恢复；开发签名未公证限制已告知，无安全策略绕过。
- Sufficient verification: 发布DMG哈希匹配，安装包版本与签名通过，cmp一致，实际进程来自安装路径；未执行GUI功能测试。
- Task fingerprint: f8ebb1a0e6fbbdbc3c5c5abff16625475ae90634cebdd2a5f5f10213a6c0f462

## Verification

- Passed: 最终再次验证已安装应用深度签名通过、进程97720仍在运行；版本为0.15.0(5)，备份保留，未执行测试套件或GUI验收。
