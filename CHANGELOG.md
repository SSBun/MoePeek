# Changelog

## [Unreleased]

## [0.15.0] - 2026-10-10

### Added

- 新增智能翻译，按输入自动提供英文词条、中文词语的英文候选或句子翻译与解析。
- 新增英文纠错和中文表达教学，展示可安全合成的完整纠正句。
- 新增本机解析历史与复习网页，支持词条记录、收藏、学习标记、删除、自动刷新及书签直达。

### Changed

- 智能翻译完成后再次按回车，仅复制英文词语或句子，不再自动回填原输入框；不附带释义、讲解、例句或中文译文。
- 优化输入占位提示、面板失焦关闭、窗口快捷键作用域和复习卡片操作。

### Fixed

- 修复有道词语翻译中多余引号的问题。
- 改善独立解析模式的回填处理，回填失败时将结果保留到剪贴板。

### Notes

- 版本为 0.15.0，build 5，要求 macOS 14.0 或更高版本。
- 本次产物使用 Apple Development 开发签名，未经 Apple 公证；macOS 可能阻止直接打开，不属于 Developer ID 正式分发产物。
- 本次不提供 Sparkle 自动更新，请从 GitHub Release 手动下载安装。

## [0.14.0] - 2026-07-22

### Fixed

- Trim stray leading/trailing commas and whitespace from Youdao dictionary results.
- Fix mixed CJK+Latin text (e.g. Chinese with English words) being misdetected as English, which caused the target language to swap incorrectly.

## [0.13.0] - 2026-07-20

### Added

- Added an experimental Codex translation provider using ChatGPT Device Code authentication.
- Added parallel selection of multiple Codex models.
- Added configurable default input methods and result copy shortcuts.
- Added translation history in the manual translation window.
- Added an option to control capitalization of translation results.
- Added toast messages for translation trigger errors.

### Fixed

- Focus the text area automatically when manual translation opens from its shortcut.
- Preserve existing Keychain credentials if replacement fails.

[Unreleased]: https://github.com/SSBun/MoePeek/compare/v0.15.0...HEAD
[0.15.0]: https://github.com/SSBun/MoePeek/releases/tag/v0.15.0
[0.14.0]: https://github.com/SSBun/MoePeek/compare/v0.13.0...v0.14.0
[0.13.0]: https://github.com/SSBun/MoePeek/compare/v0.12.1...v0.13.0
