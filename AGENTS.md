# MoePeek - Agent 文档

## 项目概述

MoePeek 是一款 macOS 菜单栏翻译应用，核心功能为**划词翻译**——用户选中任意文本后通过快捷键或触发图标即时获取多翻译服务并行结果。应用支持 OCR 截图翻译、剪贴板翻译、URL Scheme 调用等多种翻译方式，目标用户为需要在日常使用中频繁翻译的用户群体。

## 技术栈

- **语言**: Swift 6.0+ (`SWIFT_STRICT_CONCURRENCY: complete`)
- **UI 框架**: SwiftUI + AppKit 混合架构
- **构建系统**: Tuist + SPM
- **状态管理**: `@Observable` 宏 + `@MainActor` 隔离
- **部署目标**: macOS 14.0+，LSUIElement 菜单栏模式
- **依赖**: KeyboardShortcuts 2.3.0, Defaults 9.0.0, Sparkle 2.0.0
- **许可证**: AGPL-3.0

## 文档索引

- [业务逻辑分析](./docs/business_logic.md)
- [架构分析](./docs/architecture.md)
- [页面索引](./docs/page_index.md)

## 快速开始

```bash
# 安装依赖并生成 Xcode 项目
tuist install && tuist generate

# 命令行构建
xcodebuild -workspace MoePeek.xcworkspace -scheme MoePeek -configuration Debug build

# 在 Xcode 中打开
open MoePeek.xcworkspace
```

## 目录结构

```
MoePeek/
├── Sources/
│   ├── App/              # SwiftUI App 入口 + AppDelegate
│   ├── Core/             # 核心逻辑: TranslationCoordinator, TextSelection, OCR, Permissions
│   ├── Services/         # 翻译服务: Provider 协议 + 15+ 实现
│   ├── UI/               # SwiftUI 视图 + AppKit 窗口控制器
│   └── Utilities/        # 常量、Helper
├── Resources/            # 本地化字符串
├── Project.swift         # Tuist 项目配置
└── Package.swift         # SPM 依赖
```

## 常用命令

| 命令 | 描述 |
|------|------|
| `tuist install && tuist generate` | 初次设置/重新生成项目 |
| `tuist generate` | 仅重新生成 Xcode 项目 |
| `xcodebuild -workspace MoePeek.xcworkspace -scheme MoePeek build` | 命令行构建 |

## 核心模块

| 模块 | 关键文件 | 职责 |
|------|----------|------|
| 翻译编排 | `TranslationCoordinator.swift` | 状态机，协调文本获取→语言检测→多 Provider 并行翻译 |
| 组件连接 | `AppDelegate.swift` | 快捷键注册、SelectionMonitor → TriggerIcon → Coordinator → PopupPanel 闭包链 |
| 文本获取 | `TextSelectionManager.swift` | 三层降级: AX API → AppleScript Safari → ⌘C 模拟 |
| 权限管理 | `PermissionManager.swift` | Accessibility/Screen Recording 权限轮询 |
| 浮窗面板 | `PopupPanelController.swift` | 非激活 NSPanel 生命周期管理 |
| Provider 协议 | `TranslationProvider.swift` | 翻译后端插件接口 |

## 快捷键

| 快捷键 | 默认 | 功能 |
|--------|------|------|
| 划词翻译 | ⌥D | 捕获选中文字并翻译 |
| OCR 翻译 | ⌥S | 截图并 OCR 翻译 |
| 输入翻译 | ⌥A | 打开输入模式翻译 |
| 剪贴板翻译 | ⌥V | 翻译剪贴板内容 |

## 注意事项

1. **LSUIElement 模式**: 应用无 Dock 图标，所有交互通过菜单栏和浮窗完成
2. **@Observable 限制**: 计算属性 setter 不触发观察，仅存储属性触发
3. **闭包捕获**: 存储闭包必须使用 `[weak self]` + `guard let self` 模式
4. **NSPanel 生命周期**: `isReleasedWhenClosed = false` 时必须手动清理 `contentView = nil` 后再置空
5. **AsyncThrowingStream**: `continuation.onTermination` 必须取消关联 Task
6. **权限轮询**: `PermissionManager` 在权限授予后必须调用 `stopPolling()`
