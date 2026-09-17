# 将单词翻译升级为智能翻译面板

Status: Completed (2026-09-16 18:52)
Kind: Task

## Target
- [x] T1: 面板升级为智能翻译，输入区风格与解析面板一致。
- [x] T2: 输入英文单词时显示单词翻译结果。
- [x] T3: 输入中文词语时显示两个英文翻译候选，各自的单词解析结果均完整展开。
- [x] T4: 输入英文句子时，上方显示中文翻译，后面紧接与现有 parsing 服务一致的解析内容。
- [x] T5: 输入中文句子时，处理行为与结果展示均直接沿用现有 parsing panel，不新增内容或另做一套展示。
- [x] T6: 通过 HTML 原型与用户对齐四类输入的展示要求。

## Scope

- 用户已确认原型并明确授权开始原生实现：用智能翻译替代原单词翻译入口。
- 现有解析模式的可见行为和提示词保持不变；允许提取或开放输入、结果组件供智能模式复用。
- 验证不运行测试套件或携带用户内容的真实模型请求；使用构建、静态核查及可用的本地界面验证。

## Plan

1. 核对现有解析输入样式及 check/tutor 行为。
2. 制作四类示例及空白、加载、失败状态的 HTML 原型，核验页面及脚本。
3. 四类结果与紧凑布局均已确认，进入原生实现。
4. 按确认后的原型实现原生智能翻译，验证路由与既有解析行为，完成独立审查。

## Decisions

- 用户已确认整体目标与先原型后原生实现的顺序。
- 现有中文句子解析为 tutor：一条自然英文表达、最多五个关键词、最多三个语法结构，不解析中文原句语法。用户再次确认中文句子直接显示与 parsing 面板相同的结果；原生实现应复用现有结果视图，而非重写同义布局。
- 中文句子原型已对齐现有 Writing tutor / Words / Grammar 标题与回填提示文案；不在结果区混入原型说明，不增加独立翻译块。
- 用户确认英文句子上方显示中文翻译，后面紧接的内容与现有 parsing 服务一致。保留 check 的真实纠错、原因及可选自然改写，正确句子沿用无修改提示；不新增词汇/句法讲解或自行拼接修正后的完整英文。
- 输入参照现有解析区：54px 高度、12px 内边距、无输入边框、结果出现后向下展开。
- 用户要求压缩上下间距并移除冗余标签：结果不显示候选编号、用途角标、英语标签或例句标题；单词和音标同行，保留词性、释义、用法差异及所有双语例句，两个候选仍完整展开。
- 英文句子的中文译文仅用淡色正文展示，不显示“中文翻译”标题或译文上下分隔线，后面紧接原有解析内容。

## 审查补充

- 第二轮独立审查确认 TR-1、TR-2 已解决；主会话在返回后逐项复算39项，全部与 snapshot-2.json 一致。
- TR-3 已通过本地双模型原生交互先复现再修复；只修改 enterAction 的词条重试优先级，未改变句子回填分支。证据见 [原生部分失败观察](../artifacts/smart-translation-panel/evidence/native-partial-observations.json)。

## 原型交付与待确认

- 原型：[智能翻译交互原型](../artifacts/smart-translation-panel/specs/prototype.html)。用户已确认原型并授权原生实现，T6 已具备确认依据；T1–T5 进入实现。
- 已用 Chromium 实际点击四类示例、空白/加载/失败/结果及重试，均显示对应内容；任意非示例输入明确提示未接服务，没有伪造结果。浏览器脚本错误为空。
- node --check 与 git diff --check 通过；已查看 1440px 浅色和深色截图，390px 窄屏页面宽度等于视口宽度。未运行单元测试或项目测试套件。
- 用户已确认两个中文词语的英文候选均完整展开，不增加候选选择或默认折叠。原型原有布局已满足该选择，说明文案已同步。
- 英文句子原型已按用户确认移除自行拼接的完整修正句，保留中文翻译和原有 parsing 纠错结果。
- 紧凑版在 Chromium 1440px 视口、560px 面板下，中文词语结果内容高度由 701px 降至 400px，两个候选和六组例句全部保留。已查看浅色桌面与深色窄屏截图；四类示例切换正常，390px 窄屏无页面横向溢出，脚本错误为空。node --check、git diff --check 通过，未运行单元测试或项目测试。
- 英文译文淡化版经 Chromium 核对浅色/深色计算样式：译文上下边框均为 0px，译文使用次要文本颜色；已查看浅色截图，解析内容保留，中文候选间分隔线不受影响。脚本错误为空，node --check 与 git diff --check 通过，未运行测试。
- 原生路由采用 LLM 对完整输入的语义分类，不以字数或空格猜测词语与句子。词典短语按词语处理，中英混合句按主要语言处理，不适合语言分析的内容返回提示。
- 句子在分类后使用原有 parsing 提示词与 ParsingResult 解码、渲染；中文翻译只由智能路由额外提供。解析说明语言沿用现有设置。
- 句子沿用解析模式的英文回填和解析历史保存，词语沿用复制结果行为。保留原单词模式存储键对应的服务与快捷键，避免丢失设置。
- 外部样式库被网络安全规则阻断，未绕过；原型直接依据现有解析面板的尺寸、布局和语义色，不依赖外部资源。

## Result

- T6: 用户在四类 HTML 原型及历次紧凑调整后明确表示 ok, begain to execute the task the replace the word translation mode to the smart mode，授权按最终原型实现。prototype.html 保留四类示例及已确认的中文候选全部展开、英文淡色译文、中文原 parsing 内容。
- T1: Tuist 与 Debug build 通过；本地固定SSE响应驱动实际应用。菜单及已有 Ctrl+H 均打开智能面板，空窗口560×78，随内容展开并在640高封顶可滚动；Shift+Return换行、Esc清空关闭、Cmd+Return复制关闭已观察。截图 native-empty/native-long-scroll；持久偏好逐键哈希无变化。详见 evidence/native-observations.json。
- T4: 实际英文错误句显示淡色中文译文且无标题或上下分隔线，紧接共享 Writing check，native-english-sentence.png；再次Return将纠正后的完整英文回填到临时TextEdit选区，native-pasteback.png。原parsing提示词逐字未变；本地固定响应，未调用真实模型。
- T5: 实际中文句子显示共享 Writing tutor/Words/Grammar，native-chinese-sentence.png。菜单及快捷键打开后，再次Return均把英文正文回填到临时TextEdit文档并关闭智能窗口。隔离CFFIXED_USER_HOME内保存check/tutor共8条人工预览记录且model=fixture，词条无历史；见 native-history.jsonl。原ParsingCoordinator/ParsingResult/PasteTarget源码不变。
- T2: 原生 resilient 完整词条及三组例句已观察；TR-3双模型部分失败先复现（再次Return仍只有2请求），修复后再次Return变4请求并全部成功；全部成功后再Return不重复，进行中slow连续Return各模型仅1请求。native-partial-observations.json、前后截图和日志；最新Debug构建通过。
- T3: 中文坚韧原生两候选六例句全部展开见native-chinese-word.png。两个中英文词语分支均归一到words结果；本轮拆开loading/error/words判定，使部分失败可恢复，不改词条解码及视图。双模型原生重试观察见native-partial-observations.json；迟到结果隔离与布局沿用已核验代码。
- Review gate: Passed — 独立fresh只读审查 run19a8997d-98e3-42ab-b94a-e58b2c3e70c3，reports/review-3.md：Findings none，TR-1/TR-2/TR-3均resolved，无阻断风险。主会话返回后逐项重算45项全部一致，清单SHA256匹配；未发生源码漂移。
## Review Assessment

- Schema: task-review-assessment/v1
- Level: R2
- State: Current
- Reason: 第三轮复核TR-3多模型部分失败重试修复；跨模式回填、取消和历史要求保持前轮审查覆盖。
- Snapshot: tasks/artifacts/smart-translation-panel/evidence/snapshot-3.json SHA256 222cc9151d0e99bca97cc6c7649a692caf7904b3c64854c15f5718d38068243d，45项；相对第二轮唯一既有文件变化为 SmartTranslationCoordinator.swift，另新增6项部分失败原生证据。完整产品差异 implementation-3.patch。
- Evidence: T1–T6；native-partial-observations.json、before/after日志和截图；实际应用修复前复现、修复后原输入再次Return恢复成功，完成/进行中不重复。Debug BUILD SUCCEEDED；diff/context检查通过；持久偏好无变化；预览关闭且正常配置新版已启动。未跑测试套件或真实模型。
- Task fingerprint: 90008c5a79d09ce3e6fba795a9a7e18da3508915e5db845a3f558ead09a8bc77

## Verification

- Passed: 审查后45项哈希与snapshot-3完全一致；git diff --check及Context validate通过；最终改动Debug构建成功，固定本地响应的原生四类结果、滚动/重试/取消/复制/回填/历史及双模型部分失败恢复有截图和日志。正常无覆盖参数新版进程已运行。未跑测试套件或真实模型，未人工验IME/原生浅色。
