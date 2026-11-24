---
title: MoePeek 项目经验
summary: MoePeek 中可跨任务复用的实现、发布与核对经验。
---

- [2026-11-20] 修改 MoePeek 中 `isReleasedWhenClosed = false` 的 `NSPanel` 关闭流程时，MUST 显式将 `contentView` 置为 `nil`，再清空控制器持有的面板引用；核对各关闭路径是否经过该清理。结果浮窗可参考 `PopupPanelController`。
- [2026-11-23] 智能翻译浮窗的 Return、Shift+Return 与词条快捷键提示共用 `SmartTranslationCoordinator.copyableResult`。它按 `activeSlots` 顺序选取首个第一候选可复制的已完成结果，第二候选取自同一结果。Command+Return 和 Command+数字键由独立路径复制对应服务结果的 `plainText`。修改前两种快捷键、提示或结果排序时 SHOULD 保持共用来源，并核对多服务完成时按键复制的候选与提示标记一致。
- [2026-11-24] 发布 MoePeek 时 SHOULD 先核对 [GitHub Release 工作流](../../../.github/workflows/release.yml) 的签名配置。远端缺少签名配置时，以本机 Apple Development 签名构建并手动上传 DMG 是已有发布路径。采用该路径时 SHOULD 核对远端标签指向发布提交、GitHub 附件 SHA-256 与本地 DMG 一致、DMG 完整且包内应用签名有效，并明确本次产物的公证与 Sparkle 更新状态。如果完整远端下载超时且使用摘要一致的本地副本，SHOULD 如实记录核验方式和安装来源；安装后 SHOULD 核对实际安装路径、版本、构建号和启动结果。
- [2026-11-24] MoePeek「关于」页版本号右侧的问号按钮弹出当前版本的更新说明。[AboutSettingsView](../../../Sources/UI/Settings/AboutSettingsView.swift) 从应用包读取 [CHANGELOG.md](../../../CHANGELOG.md)，按 `CFBundleShortVersionString` 匹配 `## [版本]` 标题，资源由 [Project.swift](../../../Project.swift) 声明。缺少资源或匹配内容时弹层显示无更新说明。发布新版本或修改日志格式、资源打包时 SHOULD 核对目标构建包含更新日志，且问号弹层能离线显示与版本号对应的内容。
