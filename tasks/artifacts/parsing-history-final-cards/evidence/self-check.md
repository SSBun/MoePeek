# 正式卡片与无修改过滤：自检

## 范围与基线

- 本任务只修改 Resources/parsing-history.html、Resources/parsing-history.css、Resources/parsing-history.js、Sources/Utilities/ParsingHistoryStore.swift、README_zh.md，以及当前确认的静态测试页 tasks/artifacts/parsing-history-reference-cards/specs/preview.html。
- 保存本次修改前的实际文件副本，并生成 scoped.diff；这份差异相对本任务起点，不把其他尚未提交的 check/tutor/skip 等实现归因于本次修改。
- snapshot.sha256 固定上述交付内容及直接消费方，unchanged-native.sha256 证明原生模型、协调器、面板和 HTTP 服务未修改。

## T1：正式页面

- 对照用户已确认的最新测试页：桌面左侧日期，原文和解析同一卡片直接显示，字号 14px，等宽解析、青色标题/术语、黄色例句、红删绿改、灰色说明和圆角保留。
- Swift 6 完整严格并发编译实际模型、store 和 server 的隔离命令行预览；复制真实网页资源，用真实 NWListener 和 API 向独立 Chrome 提供页面，不使用替代 HTTP 实现或假的 fetch。
- runtime-check.txt 记录浏览器计算样式及交互观察：侧栏显示、所有原文都在卡片内、解析无折叠、原文与解析 14px；搜索、日期、快速连续切换、刷新、深浅色、分页均正常；390px 视口无横向溢出并切换为日期选择器。
- formal-dark.png / formal-light.png 为实际网页渲染截图，只含虚构数据。主会话查看了深色截图。

## T2：写入与展示过滤

- 调用实际 append，分别传入无纠错且改写为 nil、空串、空白换行；三次均返回 nil 且未创建目录。
- 对已有当天文件追加无修改结果，返回 nil 且前后字节一致。
- 有纠错 check、仅改写 check、tutor、skip 分别正常写入，共四条；原生结果处理/回填链未修改。
- 人工加入旧 v2 无修改行（含 nil、空串、空白、缺省 rephrase），浏览器仅显示四条有效结果，不把过滤条目计为损坏。
- 全日只有旧无修改记录时显示明确空状态，原文件保留。
- 静态测试页默认剩两条，已无“表达自然，无需修改”内容。

## T3：兼容与保留

- 混合文件含 32 条 v2 tutor、1 条 v1 和2条无效/未知版本行；初始显示30条，继续阅读后33条，两条异常行有计数提示。
- v1 的正文、自然表达、提示、词汇、语法均保留，不根据旧字段猜测是否无修改，也不迁移源文件。
- 原文里的 script 标签仅作为文本呈现，卡片内无 script 节点，window.injected 不存在。
- 浏览器重新加载能恢复令牌，服务进程重启后重新打开仍读取四条有效记录；全部虚构历史文件（含旧 Markdown）哈希前后一致。
- 无令牌 API 返回403；过期令牌给出重新打开提示，搜索禁用，不覆盖错误为正常空状态；空目录显示暂无记录。
- 原生模型、协调器、面板和服务四个源文件哈希不变。

## 构建与限制

- `node --check Resources/parsing-history.js`、`git diff --check` 通过。
- `xcodebuild -workspace MoePeek.xcworkspace -scheme MoePeek -configuration Debug -destination 'platform=macOS' build` 成功。
- 未运行单元测试或项目测试套件，未请求外部模型、读取真实历史、安装或替换用户运行中的应用。
- 原生菜单和退出接线沿用未修改实现，本次未人工点击原生菜单。没有进行浏览器兼容性矩阵或负载压测。
