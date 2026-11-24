---
title: MoePeek 项目经验
summary: MoePeek 中可跨任务复用的实现经验及核对要点。
---

- [2026-11-20] 修改 MoePeek 中 `isReleasedWhenClosed = false` 的 `NSPanel` 关闭流程时，MUST 显式将 `contentView` 置为 `nil`，再清空控制器持有的面板引用；核对各关闭路径是否经过该清理。结果浮窗可参考 `PopupPanelController`。
- [2026-11-23] 智能翻译浮窗的 Return、Shift+Return 与词条快捷键提示共用 `SmartTranslationCoordinator.copyableResult`。它按 `activeSlots` 顺序选取首个第一候选可复制的已完成结果，第二候选取自同一结果。Command+Return 和 Command+数字键由独立路径复制对应服务结果的 `plainText`。修改前两种快捷键、提示或结果排序时 SHOULD 保持共用来源，并核对多服务完成时按键复制的候选与提示标记一致。
