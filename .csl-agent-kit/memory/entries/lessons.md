---
title: MoePeek 项目经验
summary: MoePeek 中可跨任务复用的实现经验及核对要点。
---

- [2026-11-20] 修改 MoePeek 中 `isReleasedWhenClosed = false` 的 `NSPanel` 关闭流程时，MUST 显式将 `contentView` 置为 `nil`，再清空控制器持有的面板引用；核对各关闭路径是否经过该清理。结果浮窗可参考 `PopupPanelController`。
- [2026-11-20] 智能翻译浮窗并行展示多服务结果时，键盘复制和快捷键提示共用 `SmartTranslationCoordinator.copyableResult`，按启用服务顺序选取首个已有可复制正文的已完成结果。修改快捷键或结果排序时 SHOULD 保持同一来源，并核对多服务完成时按键复制的候选与提示标记一致。
