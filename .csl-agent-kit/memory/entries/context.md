---
title: MoePeek 项目基础信息
summary: MoePeek 的用途、macOS 技术栈与翻译流程入口。
---

- [2026-11-20] MoePeek 是面向 macOS 14+ 的原生菜单栏翻译应用，使用 Swift 6、SwiftUI 与 AppKit；构建使用 Tuist 和 SPM，Xcode 入口为 `MoePeek.xcworkspace`。划词、OCR 截图、剪贴板和手动输入均可发起翻译，划词结果在非激活浮窗中展示；`TranslationCoordinator` 负责翻译编排和多服务并行，`PopupPanelController` 负责结果浮窗生命周期。
