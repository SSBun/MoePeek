# 为单词翻译输入框添加占位提示

Status: Completed (2026-09-16 15:08)
Kind: Task

## Target
- [x] T1: 单词翻译面板的输入框为空时显示占位提示，输入文字后不再显示。

## Result

- T1: 单词面板传入既有本地化提示；SourceInputView 仅在 text.isEmpty 且 placeholder 非空时渲染，禁用提示命中测试；非空输入不渲染，清空后重新渲染。普通翻译调用未传入 placeholder，保持原样。Debug xcodebuild build 成功，git diff --check 通过；未运行测试或人工 UI 检查。
- Review gate: Skipped — R1 四项依据已记录；局部条件展示经编译及源码核查，无独立审查要求。
## Review Assessment

- Schema: task-review-assessment/v1
- Level: R1
- State: Current
- Reason: 仅增加受空文本条件控制的展示层，不修改编辑器、提交或翻译逻辑。
- Snapshot: SourceInputView.swift SHA256 4a95b956de403d1dca670f4daa93d856706039f59f1e1ac50179499aa49b8347（已含既有未提交修改）；WordLookupPanelView.swift SHA256 6cb372b48d99e83c12a20d840236303bf0881f844d15424b64e24a84ca366239（既有未跟踪文件）；任务仅增加可选 placeholder、条件 overlay 和单词面板参数。
- Evidence: T1 Result；Debug BUILD SUCCEEDED；git diff --check 成功；检查全部两个 SourceInputView 调用点。
- Result clarity: 用户确认空输入显示、输入后隐藏的单词输入框提示。
- Bounded impact: 唯一启用方是单词面板，普通翻译默认 nil；复用当前绑定和字体，不增加状态。
- Low risk: 只读提示层不命中点击，不写入文本或触发网络请求；失败影响限于提示外观。
- Sufficient verification: 编译和差异检查通过，逐项检查条件分支、绑定、默认值和两个调用点；未运行测试，未人工核验视觉。
- Task fingerprint: 7410516925a4e7a599f7b1f012014b8d66034538931e526b38140ae8a9f7d9f7

## Verification

- Passed: 最终两文件 SHA256 与 assessment 一致；git diff --check 通过；当前内容 Debug 构建成功。条件展示及不改变输入逻辑经源码核查；未运行测试或人工 UI 检查。
