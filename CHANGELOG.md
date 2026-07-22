# Changelog

## [Unreleased]

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

[Unreleased]: https://github.com/SSBun/MoePeek/compare/v0.14.0...HEAD
[0.14.0]: https://github.com/SSBun/MoePeek/compare/v0.13.0...v0.14.0
[0.13.0]: https://github.com/SSBun/MoePeek/compare/v0.12.1...v0.13.0
