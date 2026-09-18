# 项目上下文

## Project Core

### Purpose
- MoePeek 是 macOS 菜单栏翻译应用，支持划词、OCR、剪贴板翻译及英语解析。

### Global Vocabulary
- TranslationProviderRegistry 管理翻译服务；TranslationCoordinator 编排翻译，ParsingCoordinator 编排英语解析。

### System Map
- Sources/App/AppDelegate.swift 连接应用生命周期、快捷键、文本选择及浮窗。
- Sources/Core 承载编排逻辑；Sources/UI 承载 SwiftUI 和 AppKit 界面；Sources/Services 承载服务实现。
- Project.swift 是 Tuist 项目定义，Sources/** 与 Resources/** 分别声明代码和资源输入。

### Global Invariants
- 应用部署目标为 macOS 14.0，启用完整 Swift 严格并发检查。
- 默认以菜单栏应用运行；窗口和 UI 状态由主线程隔离对象管理。
- 项目由 Tuist 生成，第三方依赖包含 Defaults、KeyboardShortcuts 和 Sparkle。

## CTX-parsing-review — 英语解析历史与本机复习页
- Scope: 解析结果持久化、浏览器复习及本机 HTTP 服务的边界。
- Paths: `Sources/Utilities/ParsingHistoryStore.swift`, `Sources/Utilities/ParsingHistoryServer.swift`, `Sources/Core/ParsingCoordinator.swift`, `Resources/parsing-history.html`, `Resources/parsing-history.js`, `Resources/parsing-history.css`
- Keywords: 解析历史, JSONL, 英语复习, 本地服务, Markdown, ParsingHistory
- Authority: `Sources/Utilities/ParsingHistoryStore.swift`, `Sources/Utilities/ParsingHistoryServer.swift`, `Sources/Core/ParsingCoordinator.swift`, `Sources/App/AppDelegate.swift`, `Project.swift`
- Recheck: 修改历史格式、浏览器资源加载方式、存储目录或应用退出生命周期时重新核对。

### Purpose and Boundaries
- 完整解析结果按本地完成日期追加为 JSONL，保留结构化 ParsingResult；旧 Markdown 不迁移、不删除，也不进入网页日期索引。
- 无纠错项且无非空改写的 check 在存储层直接返回 nil，不创建目录或文件；网页也过滤已存的此类 v2 记录，但不改写原文件，不推断旧 v1 记录是否无修改。
- 解析完成后的保存任务独立于面板 reset 生命周期；保存失败不丢弃可复制的解析结果。

### Relationships
- ParsingCoordinator 持有同一历史 store 和 server；AppDelegate 启动时调用 startHistoryService 在后台启动服务但不打开浏览器，退出时停止。菜单及设置共享 openHistory 入口，仍调用幂等的 start 以复用服务或重试失败启动。
- HTTP 仅绑定回环地址；端口在 ParsingHistoryServer.startListener 中固定指定，不回退到动态端口。历史及复习状态 API 使用会话令牌并检查来源；固定资源路由不允许读取任意本地文件。
- 收藏与学习事件独立保存在日期对应的 `.review.json`；Study 在 store actor 内按服务端本地日期限次，每次事件保留本地日期和 ISO 8601 时间，次数由事件数组派生。
- 用户可通过卡片删除图标确认永久删除指定日期、UUID 的 JSONL 行及关联复习状态；其他行保留原始字节。追加、删除和复习状态修改共享稳定的日期锁文件，避免原子替换 JSONL 后并发追加丢失；旧进程不识别该锁，更新后应退出旧版再使用删除入口。删除先清理关联状态，再原子提交 JSONL；后者失败时卡片仍保留，可点击重试。
- 页面资源来自应用 Bundle，由 Project.swift 的 Resources/** 打包；浏览器以 JSONL 读取，DOM textContent 渲染，不执行记录中的 HTML。
- 正式复习页使用日期侧栏、14px 原文与解析同卡片直接展示，保持 check/tutor/skip 语义配色；兼容 v1 正文、自然表达、提示、词汇和语法字段。

### Decision and Verification Boundaries
- HTTP 服务验证与原生菜单/浏览器交接验证不同；隔离服务运行不能证明原生窗口交互。
- 每日读取存在明确大小限制，损坏行由页面报告跳过；数据保存不因页面显示失败而被删除或截断。

## CTX-smart-translation — 智能翻译与解析复用
- Scope: 智能模式的语义路由、解析复用、历史及旧单词模式设置兼容。
- Paths: `Sources/Core/SmartTranslationCoordinator.swift`, `Sources/Core/SmartTranslationResult.swift`, `Sources/UI/SmartTranslationPanel`, `Sources/UI/ParsingPanel`, `Sources/Services/TranslationProvider.swift`, `Sources/Utilities/Constants.swift`
- Keywords: 智能翻译, smartTranslation, 单词, 词语, 句子, parsing, 回填
- Authority: `Sources/Core/SmartTranslationCoordinator.swift`, `Sources/Core/SmartTranslationResult.swift`, `Sources/UI/SmartTranslationPanel/SmartTranslationPanelView.swift`, `Sources/UI/ParsingPanel/ParsingPanelView.swift`, `Sources/Utilities/Constants.swift`, `Sources/App/AppDelegate.swift`
- Recheck: 修改智能路由协议、解析共享组件、历史保存或偏好键时重新核对。

### Structure
- 智能模式替代旧单词入口；首个 LLM 请求按语义区分中英文词语与句子，词语直接得到完整词条，句子随后将原输入发送到未改写的 parsing 协议。
- ParsingTextEditor、StyledParsingResultView 与 ParsingPanel 同时供解析和智能模式使用；改动共享输入、结果或窗口时需检查两个入口的行为。

### Relationships
- 智能句子的解析结果保存到与 ParsingCoordinator 共享的 ParsingHistoryStore；词条不保存，中文译文不扩展现有历史格式。说明语言沿用 parsingExplanationLanguage。
- 智能模式服务与快捷键的 Swift 名称已改变，但底层仍使用 wordLookupProviderID 和 inputWordLookup 存储名称，以继承旧用户设置。
