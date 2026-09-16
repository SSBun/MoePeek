# 自检证据

## 检查范围

- 验证本次每日 JSONL、本机 HTTP 服务、HTML 学习页及应用入口；未运行单元测试或项目测试套件。
- 开始时 README_zh.md、本地化、ParsingCoordinator、ParsingPanelView、GeneralSettingsView 已修改，ParsingHistoryStore 是已有未跟踪文件。本次保留解析请求及保存失败展示链，扩展存储和复习功能。
- 源码快照见同目录 snapshot.sha256；包含受影响消费方及资源的完整文件哈希，不只依赖 HEAD。

## T1：持久化

- 使用实际 ParsingResult、ParsingHistoryStore 和 ParsingHistoryServer 编译隔离命令行预览程序，Swift 6 完整严格并发检查通过。
- 临时目录中预置不完整 JSONL 尾行和旧 Markdown，调用实际 append 保存包含换行、中文及 HTML 标签的完整解析。
- HTTP 读取结果含 schemaVersion=1、独立完整 JSON 行、原文、服务和全部解析字段；不完整尾行由新增换行隔离。
- 停止预览进程，再用同一目录启动但不写入新数据，读取字节完全一致。旧 Markdown 内容保持一致，符号链接不进入日期索引。
- 未触碰用户真实历史数据或调用外部模型。

## T2：页面和接线

- tuist generate --no-open 成功；xcodebuild -workspace MoePeek.xcworkspace -scheme MoePeek -configuration Debug -destination 'platform=macOS' build 成功。
- 构建产物包含三个页面资源。唯一观察到的构建警告是没有 AppIntents.framework 导致元数据提取跳过，与本次逻辑无关。
- node --check 检查页面 JS，python3 -m json.tool 检查本地化 JSON，git diff --check 均通过。
- 在独立 Chrome headless 进程中通过真实 HTTP 服务加载页面，以 DevTools 执行浏览器交互观察：两个日期可切换；语法说明文本可搜索；无匹配时卡片数为零且显示明确提示；点击 summary 展开内容；刷新和整页重新加载均可继续鉴权读取；390 像素视口的内容宽度为 390，无横向溢出。
- 原文含 <script>alert(1)</script>，页面原样显示文本，卡片内 script 元素数为零。
- 损坏行页面显示跳过数量，不阻止完整记录呈现。浏览器截图 browser-preview.png 为隔离示例，不含真实用户数据。
- 源码检查菜单栏和设置按钮均调用同一 ParsingCoordinator.openHistory，后者启动服务并通过 NSWorkspace 打开返回地址，失败时 NSAlert 提示。
- 限制：没有替换用户正在运行的应用，也没有人工点击原生菜单或设置窗口；原生入口接线通过源码和完整构建验证。浏览器截图并非原生 UI 验证。

## T3：访问边界和退出

- lsof 观察实际监听地址为 127.0.0.1，随机端口，无通配地址监听。
- HTTP 实际观察：三个静态资源、日期和日记录为 200；无令牌、跨站 Origin、伪造 Host、跨站 Fetch Metadata 均为 403；POST 为 405；路径穿越和旧 Markdown 路由为 404；符号链接日文件读取为 503。
- 调用实际 stop 后进程结束，端口连接被拒绝；AppDelegate.applicationWillTerminate 调用同一 stop。
- 源码检查请求头 16 KiB 上限、16 连接上限、15 秒连接超时、10 秒启动超时、固定路由、只读文件接口、CSP、no-store 和 DOM textContent 渲染。
- 限制：未执行高负载压测、浏览器矩阵验证或真实应用退出 UI 操作；HTTP 错误统一不暴露本地路径和数据。
