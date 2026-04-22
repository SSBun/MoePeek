# 页面索引

MoePeek 是 LSUIElement 菜单栏应用，不依赖传统页面导航。以下为应用内各视图组件的说明。

## 主视图

### PopupView

- **文件**: `Sources/UI/PopupPanel/PopupView.swift`
- **类型**: SwiftUI View
- **描述**: 翻译浮窗主视图，包含源文本输入、目标语言选择、翻译结果卡片列表
- **子组件**:
  - `SourceInputView`: 源文本输入框
  - `LanguageBarView`: 语言选择栏（支持自动检测显示）
  - `ProviderResultCard`: 单个翻译结果卡片
  - `ResizeGripView`: 右下角拖拽调整大小手柄
  - `DraggableDividerView`: 输入框与结果区可拖拽分割线

### SettingsView

- **文件**: `Sources/UI/Settings/SettingsView.swift`
- **类型**: SwiftUI View (TabView)
- **描述**: 应用设置窗口，5 个标签页
- **标签页**:

| Tab | 组件 | 功能 |
|-----|------|------|
| General | `GeneralSettingsView` | 快捷键、语言偏好、弹出面板大小、字体 |
| Excluded Apps | `ExcludedAppsSettingsView` | 排除翻译检测的应用列表 |
| Services | `ServiceSettingsView` | 各翻译服务商的 API Key/配置 |
| Order | `ProviderOrderSettingsView` | 翻译结果卡片排序 |
| About | `AboutSettingsView` | 版本信息、检查更新 |

## 浮窗组件

### PopupPanel

- **文件**: `Sources/UI/PopupPanel/PopupPanel.swift`
- **类型**: NSPanel 子类
- **特性**:
  - `isFloatingPanel = true`
  - `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]`
  - `styleMask = [.titled, .closable, .resizable, .nonactivatingPanel]`
  - `isReleasedWhenClosed = false`

### TriggerIconPanel

- **文件**: `Sources/UI/TriggerIcon/TriggerIconPanel.swift`
- **类型**: NSPanel 子类
- **描述**: 选中文字后显示的圆形触发图标面板
- **尺寸**: 32x32 points

### TriggerTrackingView

- **文件**: `Sources/UI/TriggerIcon/TriggerIconController.swift`
- **类型**: NSView 子类
- **描述**: 圆形图标视图，跟踪鼠标进入/退出/点击事件

## 引导流程

### OnboardingView

- **文件**: `Sources/UI/Onboarding/OnboardingView.swift`
- **类型**: SwiftUI View
- **描述**: 首次启动引导，完成 Accessibility 和 Screen Recording 权限授予
- **子组件**:
  - `PermissionCardView`: 单个权限卡（图标 + 描述 + 授予按钮）
  - `PermissionRecoveryView`: 权限丢失后恢复提示

### OnboardingWindowController

- **文件**: `Sources/UI/Onboarding/OnboardingWindowController.swift`
- **类型**: NSWindowController
- **描述**: 引导窗口生命周期管理

## 设置子视图

### GeneralSettingsView

- **文件**: `Sources/UI/Settings/GeneralSettingsView.swift`
- **内容**: 快捷键配置、语言设置、浮窗大小/字体调节

### ExcludedAppsSettingsView

- **文件**: `Sources/UI/Settings/ExcludedAppsSettingsView.swift`
- **内容**: 应用排除列表（Bundle ID 管理）

### ServiceSettingsView

- **文件**: `Sources/UI/Settings/ServiceSettingsView.swift`
- **内容**: 所有已启用提供商的配置入口，点击后显示各 Provider 的 `makeSettingsView()`

### ProviderOrderSettingsView

- **文件**: `Sources/UI/Settings/ProviderOrderSettingsView.swift`
- **内容**: 拖拽排序翻译结果卡片的显示顺序

### AboutSettingsView

- **文件**: `Sources/UI/Settings/AboutSettingsView.swift`
- **内容**: 版本号、Sparkle 更新检查、许可证信息

### AddCustomProviderSheet

- **文件**: `Sources/UI/Settings/AddCustomProviderSheet.swift`
- **类型**: SwiftUI View (Sheet)
- **描述**: 添加自定义 OpenAI 兼容 API 的表单

## 提供商配置视图

各 Provider 的设置 UI 通过 `TranslationProvider.makeSettingsView()` 提供：

| Provider | 设置视图文件 |
|----------|-------------|
| OpenAICompatibleProvider | `Sources/Services/Providers/OpenAICompatibleSettingsView.swift` |
| AnthropicProvider | `Sources/Services/Providers/AnthropicSettingsView.swift` |
| Ollama/LMStudio | `Sources/Services/Providers/LocalLLMSettingsView.swift` |

## 工具视图

### ProviderIconView

- **文件**: `Sources/UI/Components/ProviderIconView.swift`
- **描述**: 提供商图标组件（SF Symbol 或 Asset Catalog）

### MenuItemView

- **文件**: `Sources/UI/MenuBar/MenuItemView.swift`
- **描述**: 菜单栏菜单项视图

### ProviderResultCard

- **文件**: `Sources/UI/PopupPanel/ProviderResultCard.swift`
- **描述**: 单个翻译结果卡片，支持展开/折叠、流式内容显示

### SourceInputView

- **文件**: `Sources/UI/PopupPanel/SourceInputView.swift`
- **描述**: 源文本输入视图，支持 ⌘+Enter 提交

### LanguageBarView

- **文件**: `Sources/UI/PopupPanel/LanguageBarView.swift`
- **描述**: 源语言/目标语言选择栏，支持自动检测标签

## 窗口控制器

| 控制器 | 文件 | 职责 |
|--------|------|------|
| PopupPanelController | `PopupPanelController.swift` | 浮窗显示/定位/生命周期 |
| TriggerIconController | `TriggerIconController.swift` | 触发图标显示/消失/交互 |
| OnboardingWindowController | `OnboardingWindowController.swift` | 引导窗口管理 |

## 导航结构

应用为单窗口模式，导航通过以下方式实现：

1. **系统菜单栏**: 点击图标显示菜单
2. **设置 TabView**: 设置窗口内的 5 个标签页切换
3. **浮窗**: 翻译结果浮窗通过 NSPanel 实现

## URL Scheme

```
mopeek://translate?text=<url-encoded-text>
```

支持从其他应用通过 URL Scheme 唤起翻译。
