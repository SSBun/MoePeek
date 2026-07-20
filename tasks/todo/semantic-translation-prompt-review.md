# Review: 多语义翻译 Prompt

## 状态

- 已完成（2026-07-20）

## 目标

- [x] 同一源文本解释只输出一个最自然译法，不输出同义改写。
- [x] 词性、名词化、句法结构或言语功能造成的实质不同解释分别输出。
- [x] 最终输出仅含裸译文，每行一个，不含标签、编号或解释。
- [x] Prompt 不诱导模型虚构歧义，并保持对无歧义文本的单行输出。
- [x] 通过独立对抗审查。

## Review status

- Gate: APPROVED
- State: APPROVED
- Reviewer: semantic-prompt-reviewer
- Round: 5
- Scope: 报告中 SHA-256 为 `23ad79f64d69991ac2030c3d88f91e45c4aa0c1933bc137338e1a1770065ecac` 的最终候选 Prompt
- Summary: 真实 Provider 已验证目标样例、未见歧义样例、无歧义单译及非英语目标；独立 Reviewer 确认 R1–R12 全部解决且无新问题。
- Unresolved: none
- Report: [Adversarial review report](../../reports/adversarial-review/semantic-translation-prompt-review.md)
