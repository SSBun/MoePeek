# 支持书签直接访问本机复习页

Status: Completed (2026-09-17 17:34)
Kind: Task

## Target
- [x] T1: MoePeek 运行时，从书签或新标签页直接打开复习网站无需临时令牌。
- [x] T2: 保留仅回环监听及 Host／Origin 校验，阻止外部网页读取或修改记录。

## Result

- T1: Server.start 返回固定无 fragment 地址，移除 token 属性/生成/验证；JS 不再读 sessionStorage 或要求 token。README 同步书签用法。xcodebuild Debug build 成功，node --check 与 swiftc -parse 通过；未重启用户正在运行的应用，未进行真实浏览器验证。
- T2: 静态核对 requiredLocalEndpoint 仍为 127.0.0.1:18765，路由之前精确检查 Host、Origin、Sec-Fetch-Site；POST 强制同源 Origin，GET 允许书签无 Origin 导航；未增加 CORS 放行，CSP/nosniff 等保留。未运行测试或操作真实历史记录。
- Review gate: Passed — 独立只读审查 889d3dd0-39c1-487f-94da-baa9e34898a5 无发现，round-01.md 已保存并索引；审查返回后主会话重算三文件与 scoped diff 哈希均一致。
## Review Assessment

- Schema: task-review-assessment/v1
- Level: R2
- State: Current
- Reason: 移除本地 API 临时凭据，需独立核对同源保护和写操作边界。
- Snapshot: HEAD d380d64657690dac6a8a806eb965fac9585071ae; scoped unstaged diff sha256:599269950a890cdfd889e574c7371b6b107eba63eec57a48268e778f9dfe1b5c; Server e4d8f8e5d463c30c3b0052b77f7c29eea9e741e238268de18f794550d9bb7cd1; JS 6978179989996736b8a3fd2b9825302a2f30d5c3c6bc5e05e8ec0e2a20e15751; README_zh 120b63dd4e367165b04b7ac07c33c356a569133beda2b9d3235b7ba8085e20d9
- Evidence: Result T1/T2；Debug build 成功（5.073 sec），Swift/JS 语法及 diff 检查通过。
- Task fingerprint: 8afc2137bdabd67ef482b1a5e2e7029a3382eee714a0c9421622622be955d3b1

## Review Reports

| Round | Report | Snapshot | Outcome |
| --- | --- | --- | --- |
| 01 | [第 01 轮](../artifacts/bookmark-local-review-access/reviews/round-01.md) | scoped diff sha256:599269950a890cdfd889e574c7371b6b107eba63eec57a48268e778f9dfe1b5c；完整文件哈希见报告 | 无阻塞发现；仅静态审查 |

## Verification

- Passed: Debug build 成功；最终 node --check、swiftc -parse、git diff --check、Context validate 通过。交付内容与独立审查快照一致。未运行测试、重启用户应用或进行浏览器实机验证。
