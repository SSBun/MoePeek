---
title: 近期上下文
summary: 最近7个UTC自然日的用户意图与必要背景；不是执行授权。
---

- [2026-11-20] 用户确认 MoePeek 智能翻译浮窗的双候选复制交互：Return（↩）MUST 只复制第一项英文译文正文，Shift+Return（⇧↩）MUST 选中第二项并只复制其英文译文正文；任一快捷键均 MUST NOT 同时复制两条译文。用户建议的截图红圈位置对应词条标题右侧，当前视图代码在那里渲染快捷键提示。只有一条候选时，当前键盘事件处理保留 Shift+Return 的换行路径。
- [2026-11-24] 用户确认本次范围为提交并推送 MoePeek 当时全部本地改动、发布下一次版本并在本机安装同一版本。发布记录显示 [v0.22.0](https://github.com/SSBun/MoePeek/releases/tag/v0.22.0) 已正式发布，`/Applications/MoePeek.app` 已核实为 0.22.0（build 6）并启动。安装使用 SHA-256 与 GitHub 附件摘要一致的本地 DMG，采用 Apple Development 签名，未经公证，本次未提供 Sparkle 自动更新。
- [2026-11-24] 用户确认 MoePeek「关于」页 MUST 在版本号右侧提供问号按钮，点击后 MUST 在应用内显示当前版本的更新说明。当前实现将更新说明随应用打包，支持离线查看。据前台会话报告，Debug 构建通过并实点验证了 `0.22.0` 更新说明，此改动尚未发布或安装到 `/Applications/MoePeek.app`。
