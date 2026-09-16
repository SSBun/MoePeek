# 收藏与学习打卡验证

## 范围与内容身份

基线 HEAD：`ae2a110fcdafb00d32c4081296315188c1d5c1fd`。工作区原有大量未提交内容；以下四个文件原已存在但未跟踪，本任务只增加菜单、复习状态存储和 API，没有修改其他业务文件。

SHA-256：

- `Sources/Utilities/ParsingHistoryStore.swift`: `a544791e8d842411af26ee2178218f01002a3c923c9490b03fd0ca5124d4bf00`
- `Sources/Utilities/ParsingHistoryServer.swift`: `cb9e77e1ad216d05f053135c91a2674a0019c2e9cc04ba8069dfd42ee8f96a30`
- `Resources/parsing-history.js`: `fa10804ac9b0868d30411a0ba583fc3ee44f09f523f755137d92e2a8889050f0`
- `Resources/parsing-history.css`: `b1b642dd8a4e7a17737cc975ad432b6cdb4845cf177d7468fff647f033166c0b`

## 需求来源

用户要求每张卡片增加 Favorite 和 Study。随后明确 Study 表示今天已学习，每天仅能点击一次；增加学习次数和具体时间记录。用户确认的完整目标：卡片右侧菜单，支持收藏/取消收藏；本机日期每天一次；记录累计次数与每次时间；刷新、重启后保留；不新增学习页面。

## 已执行的检查

- `node --check Resources/parsing-history.js`：成功。
- `xcrun swiftc -typecheck -swift-version 6 -strict-concurrency=complete Sources/Core/ParsingResult.swift Sources/Utilities/ParsingHistoryStore.swift Sources/Utilities/ParsingHistoryServer.swift`：成功。
- `xcodebuild -workspace MoePeek.xcworkspace -scheme MoePeek -configuration Debug -destination 'platform=macOS' build`：成功；最新输出 `/tmp/moepeek-card-menu-build.log`。
- `git diff --check`：成功；四个业务文件为未跟踪文件，另行检查其末尾空白。
- 隔离的真实 HTTP 服务冒烟操作：临时入口 `/tmp/moepeek-card-menu.M4mFxC/Preview.swift`，使用当前真实 store/server 源码，数据仅在临时目录，不访问用户历史。不是单元测试或项目测试套件。

## 观察结果

- 初始 GET 返回空复习状态；收藏 POST 返回 `isFavorite=true`，取消收藏返回 false。
- 首次 Study 返回一条事件，含 `day=2026-09-16`、`studiedAt=2026-09-16T05:40:34Z`；当天再次点击仍是一条且保留原时间。
- 重启隔离服务并重新读取，前述事件与取消收藏状态保留。
- 四个并发 Study 请求返回的事件数量均为 1。
- 仅将隔离样例元数据设置为一条昨天的事件后，再点击 Study，保留昨天记录并新增今天记录，累计为 2。
- 无令牌或外域 Origin 的写操作均返回 403；GET 写路由及未知操作均返回 400。
- 比较写操作前后 JSONL SHA-256，一致；元数据单独落盘。
- 代码检查：每张 card 创建原生 details/summary 菜单；按钮具备禁用状态、收藏状态、保存反馈；学习次数由完整事件数组长度派生，菜单显示最近时间，完整时间列表写入提示；跨日通过 30 秒校准、窗口聚焦和打开菜单读取服务端日期。

## 限制

没有运行单元测试或项目测试套件。未执行浏览器自动化、实际视觉验收或真实跨午夜等待；次日分支使用隔离的昨日事件验证。未替换或重启用户正在运行的应用。跨午夜菜单日期最多等待下一次校准，重新聚焦或打开菜单也触发校准。
