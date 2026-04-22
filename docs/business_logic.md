# 业务逻辑分析

## 项目概述

MoePeek 是一款 macOS 菜单栏翻译应用，核心功能是**划词翻译**——用户选中任意文本后通过快捷键或触发图标即时获取翻译结果。应用支持多翻译服务并行翻译、OCR 截图翻译、剪贴板翻译等多种翻译方式，目标用户为需要在日常使用中频繁翻译的用户群体。

## 核心功能模块

### 模块 1: 文本捕获 (TextSelectionManager)

- **功能描述**: 三层降级策略获取用户选中的文本
- **核心文件**: `Sources/Core/TextSelection/TextSelectionManager.swift`
- **关键实现**:
  - `AccessibilityGrabber`: 使用 AX API 获取大部分应用中的选中文字
  - `AppleScriptGrabber`: 通过 JavaScript 获取 Safari 中的选中文字
  - `ClipboardGrabber`: 模拟 ⌘C 获取剪贴板内容作为兜底方案

### 模块 2: 文本检测 (SelectionMonitor)

- **功能描述**: 全局鼠标事件监控，检测用户何时选中文本并自动显示触发图标
- **核心文件**: `Sources/Core/TextSelection/SelectionMonitor.swift`
- **关键逻辑**:
  - 监听 `leftMouseUp` 事件，在 100ms 延迟后尝试 AX API 获取选中文字
  - 支持拖拽选中和多击选中手势识别
  - 可配置三种检测模式: `conservative`、`standard`、`full`

### 模块 3: 翻译编排 (TranslationCoordinator)

- **功能描述**: 核心状态机，协调文本获取→语言检测→多提供商并行翻译的全流程
- **核心文件**: `Sources/Core/TranslationCoordinator.swift`
- **状态机**:
  - `Phase.idle`: 空闲状态
  - `Phase.grabbing`: 正在捕获文本
  - `Phase.active`: 翻译进行中
- **关键函数**:
  - `translateSelection()`: 快捷键触发，捕获选中文字并翻译
  - `ocrAndTranslate()`: OCR 截图翻译
  - `translateClipboard()`: 剪贴板翻译
  - `translate(text:)`: 多提供商并行翻译入口

### 模块 4: 语言检测 (LanguageDetector)

- **功能描述**: 使用 Apple NaturalLanguage 框架检测文本语言
- **核心文件**: `Sources/Services/LanguageDetector.swift`
- **关键特性**:
  - 支持 14 种语言
  - 可配置置信度阈值
  - 支持用户偏好语言提示

### 模块 5: 翻译服务提供商 (TranslationProvider)

- **功能描述**: 插件化翻译后端架构，支持多种翻译服务
- **核心文件**: `Sources/Services/TranslationProvider.swift`
- **支持的提供商**:

| 类别 | 提供商 |
|------|--------|
| 免费翻译 | Google Translate, Bing Translate, 有道翻译 |
| 翻译 API | DeepL, DeepLX, 百度翻译, 腾讯翻译, 彩云小译 |
| LLM 服务 | OpenAI, DeepSeek, 智谱 GLM, OpenRouter, Anthropic, Ollama, LMStudio |
| 系统 | Apple Translate (macOS 15+) |

### 模块 6: 权限管理 (PermissionManager)

- **功能描述**: 管理 Accessibility 和 Screen Recording 权限
- **核心文件**: `Sources/Core/Permissions/PermissionManager.swift`
- **关键逻辑**:
  - 每 1.5 秒轮询权限状态（macOS 无权限变更回调）
  - 权限不足时引导用户前往系统设置

### 模块 7: 浮窗面板 (PopupPanelController)

- **功能描述**: 管理浮动翻译结果面板的显示、定位和生命周期
- **核心文件**: `Sources/UI/PopupPanel/PopupPanelController.swift`
- **关键特性**:
  - 非占用焦点 NSPanel，不抢夺用户当前应用焦点
  - 跟随鼠标位置或屏幕居中显示
  - 支持拖拽调整大小

### 模块 8: 触发图标 (TriggerIconController)

- **功能描述**: 选中文字后显示的圆形触发图标，悬停/点击后开始翻译
- **核心文件**: `Sources/UI/TriggerIcon/TriggerIconController.swift`
- **关键逻辑**:
  - 3 秒自动消失计时器
  - 悬停 0.3 秒后触发翻译

## 业务流程

### 流程 1: 划词翻译

```
用户选中文字 → SelectionMonitor 检测到 MouseUp
  ↓
显示 TriggerIcon (3秒自动消失)
  ↓
用户点击图标/悬停 0.3s
  ↓
TranslationCoordinator.translateSelection()
  ↓
TextSelectionManager.grabSelectedText() (三层降级)
  ↓
LanguageDetector 检测语言
  ↓
registry.enabledSlots 并行调用各翻译服务
  ↓
PopupPanel 显示流式翻译结果
```

### 流程 2: OCR 截图翻译

```
用户按下 OCR 快捷键 (⌥S)
  ↓
ScreenCaptureOCR.captureAndRecognize()
  ↓
调用系统屏幕截图 OCR
  ↓
TranslationCoordinator.translate(text)
  ↓
PopupPanel 显示翻译结果
```

### 流程 3: 快捷指令翻译 (URL Scheme)

```
外部应用打开 mopeek://translate?text=xxx
  ↓
AppDelegate.application(_:open:)
  ↓
coordinator.translate(text)
  ↓
panelController.showAtCursor()
```

## 数据模型

### TranslationCoordinator.State

- `phase: Phase`: 当前翻译阶段
- `sourceText: String`: 源文本
- `detectedLanguage: String?`: 检测到的源语言
- `targetLanguage: String`: 目标语言
- `providerStates: [String: ProviderState]`: 各提供商状态
- `activeSlots: [TranslationProvider]`: 当前活跃的翻译槽位

### ProviderState

```swift
enum ProviderState: Equatable {
    case waiting
    case translating
    case streaming(partial: String)
    case completed(text: String)
    case error(message: String)
}
```

### CustomProviderDefinition

```swift
struct CustomProviderDefinition: Codable {
    let id: String
    let displayName: String
    let iconSystemName: String
    let baseURL: String
    let model: String
    let apiKey: String
    let extraHeaders: [String: String]
}
```
