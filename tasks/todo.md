# 默认输入法设置计划

## 假设
- “input method” 指 macOS 键盘输入源，例如 ABC、拼音、日文输入法。
- 该设置只影响 MoePeek 手动翻译弹窗里的输入框，不全局切换用户其他 App 的输入源。
- 默认值为跟随系统当前输入源。

## 计划
- [x] 增加一个 Defaults 偏好，用字符串保存默认输入源 identifier。
- [x] 在 General 设置页增加 Picker：System Default + 当前可用键盘输入源。
- [x] 手动输入框获得焦点时读取偏好并应用到 `NSTextView.inputContext`。
- [x] 构建验证。

## 审查结果
- `tuist generate` 成功。
- `xcodebuild -workspace MoePeek.xcworkspace -scheme MoePeek -configuration Debug CODE_SIGNING_ALLOWED=NO build` 成功。
- 将本地未跟踪的 `Configurations/Signing.xcconfig` 改为 ad-hoc 签名后，常规 `xcodebuild -workspace MoePeek.xcworkspace -scheme MoePeek -configuration Debug build` 成功。
- `venom-cli build --run --debug` 构建成功并启动 App；日志监控已手动停止。

# 翻译结果快捷键计划

## 假设
- `⌘1`、`⌘2` 等数字快捷键在结果列表显示时复制对应完成结果并关闭弹窗。
- 空输入显示历史记录时，保留现有 `⌘1..9` 选择历史记录行为。
- 未完成、失败、等待中的结果不响应对应数字快捷键。

## 计划
- [x] 从当前 provider 顺序中取出已完成翻译结果。
- [x] 调整本地 key monitor：结果态复制对应结果并关闭，历史态保留重译。
- [x] 给完成状态的结果卡显示 `⌘1`、`⌘2` 等快捷键 badge。
- [x] 构建验证。

## 审查结果
- `xcodebuild -workspace MoePeek.xcworkspace -scheme MoePeek -configuration Debug build` 成功。
- 用户指出 badge 未显示后，补充结果卡 header badge，并让数字快捷键与可见卡片序号对齐。
