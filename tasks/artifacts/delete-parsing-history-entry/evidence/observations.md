# 删除解析历史：主 Agent 核对记录

## 需求及范围

用户原话：Why does it record unparsed items? I want to add a delete icon that users click to remove this record from the local storage。

用户确认的目标：解释跳过解析记录的来源；卡片提供删除图标，删除对应本地持久化记录，刷新或重启后不再出现，其他记录不受影响。不自动清理、不改变新记录筛选规则、不操作真实历史。

## 内容身份

- `snapshot.json` 标识六个交付文件的完整内容及 HEAD。
- `current.patch` 是这些文件相对 HEAD 的总差异；`pre-task.patch` 是任务开始前已有改动，不能归为本任务。前置改动包含固定端口、平铺操作和已学习高对比状态。
- 快照之外的 Context 和任务状态属于生命周期记录。

## T1：来源

- `ParsingResult` 明确支持 `.skip`，返回没有可回填正文的结果。
- `ParsingCoordinator` 对完整返回结果调用 historyStore.append。
- `ParsingHistoryStore.append` 仅提前返回无需修改的 check，未排除 skip。
- 网页 validRecord 接受 skip，hasReviewContent 只排除无修改 check，因此该类记录会显示。本任务未改变这些筛选逻辑。

## T2：实际检查及观察

执行环境：只使用临时目录中的合成 JSONL 与复习状态。Swift CLI 冒烟服务直接编译当前 ParsingHistoryStore、ParsingResult；ParsingHistoryServer 副本仅将端口从 18765 改为 18766，最终逐字对照确认无其他改动。真实 MoePeek 占用 18765，未停止或调用它的历史接口。临时服务和独立 Chrome 均已关闭。

1. Debug 构建：`xcodebuild -workspace MoePeek.xcworkspace -scheme MoePeek -configuration Debug -destination platform=macOS build` 成功；`node --check Resources/parsing-history.js`、`git diff --check` 和 Context validate 成功。
2. Chrome Headless + CDP 操作真实页面：2 张合成卡片均有垃圾桶 SVG 和可访问标签；点击出现“永久删除及不可撤销”确认；取消后仍为 2 张；确认后剩 1 张，原文为 keep synthetic skip。截图见 after-delete.png，浏览器操作载体见 browser.mjs。
3. 持久化：删除后 JSONL 精确等于原文件去掉指定第一行的字节，包括另一条 CRLF 记录及损坏行；关联状态中只移除了目标 UUID。JSONL 权限仍为 0600。
4. 幂等：再次发送同一删除请求返回 HTTP 200，JSONL 字节未变。
5. 拒绝危险或不可解析输入：同日重复目标 UUID、JSONL 符号链接、损坏复习状态均返回 503，原历史字节未变；非法日期返回 405。
6. 安全边界：无令牌及错误 Origin 的删除请求均返回 403；GET 删除路径返回 404。拒绝请求未删除数据。
7. 并发：8 个独立进程通过当前 store 同时追加合成 skip 记录，同时 HTTP 删除另一指定记录。8 个进程退出码全部为 0，8 条新增记录完整保留，删除目标不存在，损坏行保留。
8. 持久化重启：关闭并重新启动临时服务，GET 当日历史中两个已删除 UUID 均不存在。
9. 最后一行：另一临时日期文件仅含一条无尾换行的记录，删除返回 200，文件大小为 0。

## 失败与限制

- 首次构建发现文件描述符返回类型误写为 Int；修为 Int32 后最终构建通过。
- 未运行单元测试或项目测试套件；上述为临时数据下的 API/浏览器冒烟和文件核对。
- 未模拟进程在两次原子写入之间崩溃、磁盘满或所有系统调用错误。实现先清理目标复习状态，再原子替换历史；后者失败时历史仍可显示并再次点击删除，错误文案不承诺完全未修改。
- 新增稳定日期锁由新版 append/updateReview/deleteEntry 共同遵守，旧版进程不识别它；不保证新旧版本同时写入同一目录时的互斥，使用新版时需退出旧版。
- 验证未启动新构建的完整 GUI 应用，未对真实历史进行任何读写。原生菜单入口未重走；独立服务仅替换验证端口。
- 自动截图仅覆盖深色主题；图标样式复用既有深浅色主题变量。
