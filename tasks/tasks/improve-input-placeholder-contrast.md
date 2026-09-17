# 提高输入框占位提示的可读性

Status: Completed (2026-09-17 10:19)
Kind: Task

## Target
- [x] T1: 输入框占位提示具有更高对比度，仍与实际输入文字区分，输入和翻译行为不变。

## Result

- T1: 仅将共享ParsingTextView占位色从tertiaryLabelColor改为secondaryLabelColor。AppKit实际解析：浅色黑色alpha由0.259增至0.498，深色白色alpha由0.247增至0.549，均低于正文0.847；字体、文案、空值/IME判断和输入处理未变。Debug构建及git diff --check通过；新版已启动。原生截图两次为空，未作为视觉通过证据；未运行测试。
- Review gate: Skipped — R1：仅占位语义颜色更改，四项豁免依据已记录，无独立审查要求。
## Review Assessment

- Schema: task-review-assessment/v1
- Level: R1
- State: Current
- Reason: 单一语义颜色替换，不改变布局或交互；系统深浅外观的真实色值已确认。
- Snapshot: Sources/UI/ParsingPanel/ParsingPanelView.swift SHA256 b27cbef957771d97bca0992c7a49378c1980e5655087e1afd1d370b4eb7ba17d；本任务仅draw中的tertiaryLabelColor替换为secondaryLabelColor，其余为此前智能模式改动。
- Evidence: T1 Result；Debug BUILD SUCCEEDED；AppKit NSAppearance浅色/深色RGBA输出；git diff --check。
- Result clarity: 用户要求提高占位提示可读性，实际提高alpha且仍弱于正文。
- Bounded impact: 仅共用编辑器绘制占位文字的颜色，影响智能与解析输入；不影响正文或请求。
- Low risk: 纯展示色值且使用系统自适应语义色，可随系统外观调整，低风险可逆。
- Sufficient verification: 构建、色值解析及一行差异检查已完成；没有改写输入与组字判断。未运行测试，屏幕捕获为空，未声称截图验收。
- Task fingerprint: 4f28f2d64d5c9282dfa5099cf3302ddfead820b172498b907de3a445fee17a0f

## Verification

- Passed: 最终源码SHA256与assessment一致，差异检查通过；构建成功，深浅外观色值证实对比度提高且低于正文。原生可视截图未取得，不作为证据；未运行测试。
