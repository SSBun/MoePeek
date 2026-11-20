# 按快捷键复制单个翻译选项

| Field | Value |
| --- | --- |
| Status | Completed (2026-11-20 16:36) |
| Artifacts | [Artifacts](../artifacts/copy-individual-translation-options/) |
| Kind | Task |

## Target
- [x] T1: Return 只复制第一条译文
- [x] T2: Shift+Return 只复制第二条译文
- [x] T3: 在截图标记的两条结果标题右侧显示各自的快捷键

## Execution Log

### 001 — 确认复制入口

普通回车由共享输入框提交，智能翻译当前把候选合并成一段文本。Shift+Return 目前在共享输入框中换行。将复用智能翻译浮窗的键盘监听，仅在第二候选可复制时处理 Shift+Return，快捷键提示和复制使用同一服务结果。

### 002 — 实现与构建

补齐 Tuist 依赖并重新生成工程后，MoePeek 的 arm64 Debug 构建通过。核对了输入框提交、候选索引、窗口事件过滤以及快捷键的显示条件。

## Task Summary

- 智能翻译按候选索引提取英文正文，两组快捷键共享同一个服务结果。
- 在对应词条标题右侧显示 ↩ 或 ⇧↩。只有第二候选可用时，浮窗才接管 Shift+Return。

## Self Assessment

| Dimension | Grade | Basis and evidence | Limitations |
| --- | --- | --- | --- |
| 简洁性 | A | 复用现有事件监听及剪贴板入口，无新增存储状态。 | 静态核对。 |
| 稳定性 | A | Debug 构建通过，核对了窗口焦点、输入法组合状态及换行的既有分支。 | 未在运行中的浮窗按键。 |
| 完整性 | A | 两个候选索引、复制值及标题右侧提示均已实现。 | 未实测浮窗布局或剪贴板。 |

## Result

- T1: 静态核对输入框回车提交经 enterAction 复制候选索引 0 的正文，Debug 构建通过。
- T2: 静态核对窗口键盘监听仅在第二候选存在时将索引 1 的正文交给现有剪贴板入口，Debug 构建通过。
- T3: 静态核对受快捷键控制的服务词条按索引在标题右侧显示 ↩ 与 ⇧↩，Debug 构建通过。
- Review gate: Skipped — See Review Assessment for the recorded exemption
## Review Assessment

- Schema: task-review-assessment/v1
- Level: R1
- State: Current
- Reason: 改动集中于智能翻译浮窗的候选复制和快捷键提示。
- Snapshot: snapshot:tasks/artifacts/copy-individual-translation-options/evidence/9d9b37a339efb0832a15ace3fe64c355f42709d9e96cedfb516457c0bcf425d3.json#9d9b37a339efb0832a15ace3fe64c355f42709d9e96cedfb516457c0bcf425d3
- Evidence: 检查四个源码文件的差异和快捷键入口。
- Result clarity: 两个按键分别写入固定索引的英文正文，标题提示对应相同索引。
- Bounded impact: 仅涉及智能翻译词条复制，其他窗口及没有第二候选时沿用现有分支。
- Low risk: 复用既有剪贴板写入与面板关闭逻辑，操作的影响限于用户按键时的剪贴板。
- Sufficient verification: 源码路径核对、git diff --check 和 arm64 Debug 构建通过，未实测浮窗和剪贴板。
- Task fingerprint: bdac9cab85da1157fbda5c46f3540f2ae38f828e1c504ef2b3c87f999e5c9d98

## Verification

- Passed: 记录四个源码文件的快照后重跑 git diff --check 及 arm64 Debug 构建均通过，未运行测试套件。
