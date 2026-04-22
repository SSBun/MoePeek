# 架构分析

## 技术栈

### 前端 / UI
- **框架**: SwiftUI + AppKit 混合架构
- **UI 模式**: SwiftUI 处理视图内容，AppKit NSPanel 处理窗口生命周期
- **状态管理**: `@Observable` (Swift 6 宏) + `@MainActor` 隔离

### 后端 / 核心
- **语言**: Swift 6.0+
- **并发**: Swift Strict Concurrency (`complete`)
- **依赖注入**: 构造器注入 + 闭包回调链

### 依赖管理
| 包 | 版本 | 用途 |
|----|------|------|
| KeyboardShortcuts | 2.3.0 | 全局快捷键注册 |
| Defaults | 9.0.0 | 用户偏好存储 |
| Sparkle | 2.0.0 | 自动更新 |

### 构建
- **系统**: Tuist + SPM
- **部署目标**: macOS 14.0+
- **特殊模式**: LSUIElement (菜单栏应用，无 Dock 图标)

## 代码分层

### 目录结构

```
MoePeek/
├── Sources/
│   ├── App/
│   │   ├── MoePeekApp.swift      # SwiftUI App 入口
│   │   └── AppDelegate.swift      # 生命周期 & 组件连接
│   ├── Core/
│   │   ├── TranslationCoordinator.swift  # 核心状态机
│   │   ├── UpdaterController.swift       # Sparkle 更新控制
│   │   ├── OCR/
│   │   │   └── ScreenCaptureOCR.swift   # 截图 OCR
│   │   ├── Permissions/
│   │   │   └── PermissionManager.swift  # 权限管理
│   │   └── TextSelection/
│   │       ├── SelectionMonitor.swift     # 鼠标事件监控
│   │       ├── TextSelectionManager.swift # 三层文本获取
│   │       ├── AccessibilityGrabber.swift # AX API
│   │       ├── AppleScriptGrabber.swift   # Safari JS
│   │       └── ClipboardGrabber.swift    # ⌘C 模拟
│   ├── Services/
│   │   ├── TranslationProvider.swift     # Provider 协议
│   │   ├── TranslationProviderRegistry.swift # 提供商注册
│   │   ├── LanguageDetector.swift        # NLLanguageRecognizer
│   │   ├── LanguageCodeMapping.swift
│   │   ├── ModelMetadataService.swift
│   │   └── Providers/
│   │       ├── OpenAICompatibleProvider.swift  # OpenAI 兼容
│   │       ├── AnthropicProvider.swift
│   │       ├── AppleTranslationProvider.swift
│   │       ├── GoogleTranslateProvider.swift
│   │       ├── DeepLProvider.swift
│   │       └── ... (其他 10+ 提供商)
│   ├── UI/
│   │   ├── Components/
│   │   │   └── ProviderIconView.swift
│   │   ├── MenuBar/
│   │   │   └── MenuItemView.swift
│   │   ├── Onboarding/
│   │   │   ├── OnboardingView.swift
│   │   │   ├── OnboardingWindowController.swift
│   │   │   ├── PermissionCardView.swift
│   │   │   └── PermissionRecoveryView.swift
│   │   ├── PopupPanel/
│   │   │   ├── PopupPanel.swift           # NSPanel 子类
│   │   │   ├── PopupPanelController.swift # 生命周期管理
│   │   │   ├── PopupView.swift            # SwiftUI 主视图
│   │   │   ├── SourceInputView.swift
│   │   │   ├── LanguageBarView.swift
│   │   │   └── ProviderResultCard.swift
│   │   ├── Settings/
│   │   │   ├── SettingsView.swift
│   │   │   ├── GeneralSettingsView.swift
│   │   │   ├── ExcludedAppsSettingsView.swift
│   │   │   ├── ServiceSettingsView.swift
│   │   │   ├── ProviderOrderSettingsView.swift
│   │   │   └── AboutSettingsView.swift
│   │   └── TriggerIcon/
│   │       ├── TriggerIconPanel.swift
│   │       └── TriggerIconController.swift
│   └── Utilities/
│       ├── Constants.swift           # Defaults Keys & 快捷键定义
│       ├── KeychainHelper.swift
│       ├── FontHelper.swift
│       ├── PopupPositioning.swift
│       └── URLFormEncoding.swift
└── Resources/
    └── Localizable.xcstrings        # 国际化字符串目录
```

## 各层职责

### App 层 (Sources/App/)

| 文件 | 职责 |
|------|------|
| MoePeekApp | SwiftUI App 入口 |
| AppDelegate | 应用生命周期、快捷键注册、组件连接、URL Scheme 处理 |

### Core 层 (Sources/Core/)

| 文件 | 职责 |
|------|------|
| TranslationCoordinator | 核心状态机，协调翻译全流程 |
| TextSelectionManager | 三层降级文本获取策略 |
| SelectionMonitor | 全局鼠标事件监控 |
| PermissionManager | Accessibility/Screen Recording 权限管理 |
| ScreenCaptureOCR | 截图 OCR 能力封装 |

### Services 层 (Sources/Services/)

| 文件 | 职责 |
|------|------|
| TranslationProvider | 翻译后端插件协议 |
| TranslationProviderRegistry | 提供商注册、排序、启用状态 |
| LanguageDetector | Apple NLLanguageRecognizer 封装 |
| 各 Provider | 具体翻译服务实现 |

### UI 层 (Sources/UI/)

| 组件 | 职责 |
|------|------|
| PopupPanel | 非占用焦点浮动面板 |
| PopupView | 翻译结果主视图（SwiftUI） |
| TriggerIcon | 鼠标悬停触发图标 |
| SettingsView | 设置窗口（5 个 Tab） |
| OnboardingView | 首次启动引导流程 |

### Utilities 层 (Sources/Utilities/)

| 文件 | 职责 |
|------|------|
| Constants | 所有 Defaults Keys 和 KeyboardShortcuts.Name |
| KeychainHelper | API Key 安全存储 |
| PopupPositioning | 面板屏幕位置计算 |

## 关键设计模式

### 1. Coordinator 模式

`TranslationCoordinator` 作为唯一的事实来源，所有 UI 通过它驱动：
- `@Observable` + `@MainActor` 确保线程安全
- 状态变更驱动 PopupView 重新渲染

### 2. 插件化 Provider

```swift
protocol TranslationProvider: Sendable {
    var id: String { get }
    var displayName: String { get }
    func translateStream(_ text:, from:, to:) -> AsyncThrowingStream<String, Error>
    @MainActor func makeSettingsView() -> AnyView
}
```

任何实现该协议的类型都可作为翻译后端，自包含其配置存储和设置 UI。

### 3. 非激活 Panel

`PopupPanel` 和 `TriggerIconPanel` 设置 `NSWindow.Level.floating` + `collectionBehavior`，实现：
- 不抢夺用户当前应用焦点
- 始终显示在屏幕最前

### 4. 三层文本降级

```
Tier 1: AX API (大多数应用) → 快速、非侵入
Tier 2: AppleScript Safari JS (仅 Safari) → 扩展兼容
Tier 3: ⌘C 模拟 (兜底) → 通用但有侵入
```

### 5. 并行多 Provider

`ModelSlotProvider` 包装层实现单个 Provider 多模型并行翻译，`enabledSlots` 展开后所有 Provider 并行执行。

## 关键文件位置

| 功能 | 文件路径 |
|------|----------|
| 核心状态机 | `Sources/Core/TranslationCoordinator.swift` |
| 组件连接 | `Sources/App/AppDelegate.swift` |
| 常量定义 | `Sources/Utilities/Constants.swift` |
| 文本获取 | `Sources/Core/TextSelection/TextSelectionManager.swift` |
| 浮窗管理 | `Sources/UI/PopupPanel/PopupPanelController.swift` |
| Provider 协议 | `Sources/Services/TranslationProvider.swift` |
| 提供商注册 | `Sources/Services/TranslationProviderRegistry.swift` |
