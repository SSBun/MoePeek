# 发布 MoePeek 0.14.0

## 状态

- 已完成（2026-07-22）

## Scope

- 修复 Youdao 翻译结果首尾出现多余逗号/空白的问题。
- 修复中英混排文本被语言检测器误判为英语、导致目标语言被自动翻转的问题。
- 将 marketing version 从 `0.13.0` 升级到 `0.14.0`，build number 从 `2` 升级到 `3`。
- 排除远端 tag、push、notarize 等发布动作。

## Target

- Youdao 结果不再带首尾逗号、空格或换行。
- 含中文字符的混排文本被正确检测为中文，目标语言不再被错误翻转。
- App `Info.plist` 版本号为 `0.14.0 (3)`。
- `CHANGELOG.md` 新增 `[0.14.0]` 条目。
- `tuist generate` + Debug 构建成功。

## Plan

- [x] 在 `YoudaoTranslateProvider` 结果拼接链尾加 `trimmingCharacters`。
- [x] 在 `LanguageDetector` 加 CJK 文字权重提升，修正混排检测。
- [x] 更新 `Project.swift` 版本号并 `tuist generate`。
- [x] 更新 `CHANGELOG.md`。
- [x] 对最终 diff 执行独立对抗审查。

## Checklist

- [x] Youdao 结果 trim 逻辑已应用。
- [x] CJK 检测权重已应用。
- [x] `Project.swift` 版本为 `0.14.0` / build `3`。
- [x] `CHANGELOG.md` 含 `[0.14.0]` 条目与 compare 链接。
- [x] `git diff --check` 无报错。
- [x] `tuist generate` 成功。
- [x] Debug 构建成功，`Info.plist` 确认为 `0.14.0 (3)`。
- [x] 独立对抗审查通过。

## Review status

- Gate: APPROVED
- Reviewer: Codex 内置 subagent (agent_type: default)
- Round: 1/3
- Scope: YoudaoTranslateProvider trim、LanguageDetector CJK 权重、Project.swift 版本号、CHANGELOG.md
- Summary: 两处修复最小且正确，版本号与 CHANGELOG 一致，构建通过。Reviewer 在 INITIAL (1) 即 APPROVED，仅一条 NOTE（纯汉字日语偏向中文的已知上限），已加 ponytail 注释。
- Unresolved: none
- Report: [Adversarial review report](../../reports/adversarial-review/release-0.14.0.md)

## Result

- `tuist generate` 成功。
- Debug 构建成功，App `Info.plist` 确认为 `0.14.0 (3)`。
- `git diff --check` 无报错。
- 独立对抗审查 APPROVED（1 round），无未解决发现。
- 未执行 tag、push、notarize 等远程发布动作。
