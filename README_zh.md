<p align="center">
  <img src="Resources/AppIcon.icon/Assets/MoePeek.png" width="128" height="128" alt="MoePeek Icon" />
</p>

<h1 align="center">MoePeek</h1>

<p align="center">
  轻量原生的 macOS 菜单栏翻译工具，选中即译。
</p>

<p align="center">
  <a href="README.md">English</a> | 中文
</p>

<p align="center">
  <a href="https://github.com/SSBun/MoePeek/releases/latest"><img src="https://img.shields.io/github/v/release/SSBun/MoePeek" alt="GitHub Release" /></a>
  <a href="https://github.com/SSBun/MoePeek/releases"><img src="https://img.shields.io/github/downloads/SSBun/MoePeek/total" alt="Downloads" /></a>
  <img src="https://img.shields.io/badge/platform-macOS%2014%2B-blue" alt="Platform" />
  <img src="https://img.shields.io/badge/swift-6.0-orange" alt="Swift" />
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-AGPL--3.0-green" alt="License" /></a>
</p>


<p align="center">
  <img src="Resources/MoePeek-promo.webp" alt="MoePeek 预览" />
</p>

## 功能

**翻译方式**

- **划词翻译**：在任意应用中选中文字，浮窗即时展示翻译结果
- **OCR 截图翻译**：框选屏幕区域，识别并翻译其中的文字
- **剪贴板翻译**：一键翻译剪贴板中的内容
- **手动输入**：输入或粘贴文字进行翻译
- **语言解析**：在独立面板中输入文本，直接展示纠错、自然表达、词汇和语法说明

**内置翻译服务**

| 免费 | API | LLM | 系统 |
|------|-----|-----|------|
| Google 翻译 | DeepL | OpenAI | Apple 翻译 |
| Bing 翻译 | 百度翻译 | Anthropic | *（macOS 15+，离线可用）* |
| 有道翻译 | 小牛翻译 | DeepSeek | |
| | 彩云小译 | OpenRouter | |
| | DeepLX | 智谱 GLM | |
| | | Codex *（实验性）* | |
| | | Ollama（本地） | |
| | | LM Studio（本地） | |

**更多特性**

- 智能语言检测，支持 14 种语言，自动切换翻译方向
- 非激活浮窗，永远不会抢走当前应用焦点
- 三层文本抓取：Accessibility API → AppleScript → 剪贴板逐级回退
- 所有快捷键均可自定义
- 内置 Sparkle 自动更新

## 为什么选择 MoePeek

- **约 5 MB 安装体积**：纯 Swift 6 构建，仅 3 个依赖。没有 Electron，没有 WebView。
- **约 50 MB 后台内存**：系统性防控内存泄漏，长时间挂后台也稳定。
- **注重隐私**：Apple 翻译完全在设备端运行。
- **开源项目**：AGPL-3.0 协议，欢迎提 Issue 和反馈。

## 局限性与替代方案

MoePeek 是一个纯 **AI vibe coding** 的自用项目。它能满足我个人的使用需求，但并不追求做成一个完善的商业级产品——划词、窗口交互中有大量的 edge case，商业工具花了多年时间才踩完这些坑，MoePeek 肯定还漏掉了不少。

如果你需要更健壮的解决方案，以下工具非常优秀：

- **[Clicknow](https://clicknow.ai/)** — 功能丰富、持续维护的划词翻译工具
- **[PopClip](https://www.popclip.app/)** — macOS 划词操作的标杆之作，拥有丰富的插件生态

## 安装

从 [GitHub Releases](https://github.com/SSBun/MoePeek/releases) 下载最新的 `.dmg` 或 `.zip`，将 `MoePeek.app` 拖入 `/Applications`。

## 使用

首次启动时，MoePeek 会引导你完成权限设置：

- **辅助功能**：用于通过 Accessibility API 获取选中文本
- **屏幕录制**：用于 OCR 截图翻译

### 默认快捷键

| 操作 | 快捷键 |
|------|--------|
| 划词翻译 | `⌥ D` |
| OCR 截图 | `⌥ S` |
| 手动输入 | `⌥ A` |
| 文本解析 | 默认未绑定，可在通用设置中录制 |
| 剪贴板翻译 | `⌥ V` |

所有快捷键均可在**设置 → 通用**中自定义。

### 语言解析模式

先聚焦需要回填的输入框，再从菜单栏选择 **文本解析**，或使用已配置的解析快捷键打开独立浮窗。首次按回车解析，结果完成后再次按回车，会关闭面板并把英文正文粘贴回原输入框。动作在松开回车后执行，避免长按产生重复回填或额外提交。`⇧↵` 换行，`Esc` 或 `⌘W` 关闭，拖动外缘留白可移动面板。

所有配置集中在 **设置 → 通用**：快捷键位于 **键盘快捷键 → 文本解析**（默认未绑定）；服务和说明语言位于 **解析** 分组。操作面板不再放置配置控件、提交按钮或卡片工具栏。

- 原翻译面板不增加模式切换，`⌥ A` 仍只打开原来的输入翻译面板，布局和交互不变。
- 基础设置的 **解析服务** 可独立指定 OpenAI-compatible（含自定义服务）、Codex、Anthropic、Ollama 或 LM Studio，并沿用该服务的默认/并行模型配置；即使该服务未勾选用于翻译，也可以用于解析。Google、DeepL、Apple 等纯翻译服务不参与解析。
- 默认选项 **已启用的 LLM** 保留原来的并行解析行为。指定服务的选择会保存，不修改翻译服务勾选；服务切换会取消旧解析，新的提交使用新选择。若显式选择的服务被移除，则提示重选，不会静默回退到其他服务。
- **中文等非英文输入 → tutor**：与 Perch 一样，只生成一份自然、完整的英文 `sentence`，再解释这份英文结果的词汇与语法。不再额外生成或显示 `Natural expression`。
- **英文输入 → check**：只列真实拼写／语法纠错 `items`（原片段、正确片段与原因）；仅在表达明显不自然时提供一条可选 `rephrase`，否则为 `null`。无需修改时显示“表达自然，无需修改”，不生成教学词汇／语法列表。
- **不适合语言分析 → skip**：模型判断内容过短、代码较多或含义不清时给出跳过结果，不提供回填正文。短文本或中英混合输入按实际内容判断，语言检测结果仅作提示。
- 基础设置的 **说明语言** 只控制纠错原因及词汇、语法讲解，默认跟随翻译目标语言，也可独立选择中文；正文、英文片段、可选改写和词条保持英文。原翻译功能的目标语言不受影响。
- 使用独立解析提示词，不覆盖用户保存的翻译提示词；短句直接交给模型，不按字符数或代码占比预先拦截。
- 解析窗口拥有独立输入、请求和结果；切换到其他窗口或应用时自动关闭，并取消未完成的解析，不把焦点抢回旧应用。关闭会清理本次草稿和结果；面板内部选字、复制等操作不应误关闭。面板仍聚焦时重复调用只激活现有窗口。多模型结果仅用必要的名称分隔，不使用卡片外框。
- 结果采用 Perch 的三分支紧凑等宽排版：**Writing check** 展示红色原片段、绿色修正、中文原因和必要的黄色改写；**Writing tutor / Words / Grammar** 展示一份黄色主句、青色词条及说明；跳过结果只显示状态。亮色外观保留对应深色配色。
- 解析传输仍可流式接收与取消，但界面会等待完整结构化结果校验成功后再呈现，不显示半截 JSON；格式无效会明确提示再次提交。
- **再次回车回填**：tutor 使用 `sentence`；check 优先使用 `rephrase`，否则将唯一且不重叠的纠错片段应用到本次原文，无需修改时使用原文。片段重复、重叠或找不到时拒绝合成正文；skip 不回填。多个结果时按面板顺序选择首个已完成且可安全回填的结果，不包含讲解。解析中不会重复提交，输入改动后重新解析，不粘贴旧结果。
- 回填需要辅助功能权限和可验证的外部可编辑输入框。应用在打开时锁定应用、窗口、控件与可读取的选区；回填前重新核对。密码框、只读区域、已变化或不支持原生 Paste 的目标会被拒绝，不盲目写入其他位置。
- 回填把正文写入系统剪贴板，再执行原应用的正常 Paste 菜单动作，遵循原光标/选区；不会设置整框文本、发送全局按键或额外 Return。英文正文留在剪贴板中；若检测到外部剪贴板变化则停止，不覆盖用户的新复制内容。无法通过 AX 确认可编辑的终端/自定义控件可能需要手动粘贴。
- 结果仍可选择文字复制或右键 **复制**；右键复制保留全部解析信息，而非 JSON。两种复制都不应用译文首字母格式化，也不写入翻译历史。
- **本地学习笔记**：完整且格式有效的解析结果按完成时的本地日期追加到 `~/Library/Application Support/MoePeek/ParsingHistory/YYYY-MM-DD.jsonl`。每行包含格式版本、唯一 ID、完成时间、原文、服务／模型信息，以及对应的完整 `check` / `tutor` / `skip` 结果；**没有纠错项且没有有效改写建议的 Writing check 不保存**（空白改写也视为没有建议）。旧文件中的此类记录仅在网页中过滤，不删除或改写历史；tutor 和 skip 沿用原有保存规则，多模型结果分别记录。新记录采用 `schemaVersion: 2`，复习页继续兼容旧 `schemaVersion: 1` 的正文／自然表达格式，旧 JSONL 不迁移或改写。失败或取消且未产生完整结果的请求不记录。模型名取自提交时的快照，未指定时存为 `null`。已有 Markdown 文件保持原样，不自动迁移或在复习页展示。
- 点击菜单栏的 **英语复习**，或 **设置 → 通用 → 解析 → 英语复习**，在浏览器中通过左侧日期栏阅读笔记、搜索当天内容。原文与解析在同一张圆角卡片中直接展示，内容采用 14px 字号；解析保留原生面板的等宽字体及青色、黄色、红绿纠错配色，支持深浅色切换。窄屏时日期改为顶部选择器。页面不使用 CDN 或外部服务，历史不上传。本机 HTTP 服务使用固定端口 `18765`，仅监听 `127.0.0.1`；端口被占用时启动失败，不自动切换端口；可将 `http://127.0.0.1:18765/index.html` 保存为书签，在应用运行时直接打开，无需会话令牌；仍检查 Host、Origin 和浏览器来源信息，所有写操作必须携带同源 Origin。退出 MoePeek 后服务关闭，重启应用后可继续通过原书签读取之前保存的 JSONL。
- 每张复习卡片右侧提供垃圾桶图标；确认后按日期和记录 ID 从本地 JSONL 删除该条，并清理其收藏、学习状态，刷新或重启后不再出现。其他行（包括损坏行）保留原始字节；缺少有效 ID 或 ID 重复时不执行不安全删除。删除无法撤销；先清理关联状态，再原子提交历史删除。失败时历史卡片仍可能保留，请刷新核对并重试。`skip` 是模型返回的“跳过解析”结果，目前仍会保存，可按需手动删除。
- **打开解析记录文件夹** 仍可打开实际存储目录。这些文件是本地明文，请留意备份和共享范围。写入失败（包括取锁超过一秒）会在解析面板提示，结果仍可复制使用。损坏或版本不支持的 JSONL 行会在页面显示跳过数量，不修改源文件；单日文件超过 64 MiB 时页面会明确提示读取失败，原始记录不会截断。
- 若提示没有可用 LLM，从菜单栏打开设置，在通用页选择解析服务，或到服务页配置对应账户/模型。

### 智能翻译模式

菜单栏的 **智能翻译** 替代原单词翻译入口；旧服务选择和快捷键继续生效。输入区与解析面板一致，按回车提交，结果出现后向下展开，不再使用旧翻译卡片的工具栏和可拖拽输入分隔条。

- **英文词语**：音标、词性、中文释义及三组双语例句。
- **中文词语**：两个英文候选全部展开，各自提供音标、释义、用法差异和三组双语例句。
- **英文句子**：先显示淡色中文译文，不加标题或上下分隔线，随后直接显示现有解析结果。
- **中文句子**：直接复用解析面板的 Writing tutor / Words / Grammar 结果。

词语、词典短语和句子由模型按语义区分，不按字数或空格硬切。中英混合句按主要语言处理；不支持的语言或不适合分析的内容显示提示。句子在分类后仍调用原解析提示词，不改动独立解析模式。

在 **设置 → 通用 → 智能翻译** 选择 LLM 服务；默认跟随已启用的 LLM。解析说明语言沿用 **解析 → 说明语言**。句子的解析部分沿用现有本地历史保存规则及再次回车回填英文的行为；词条不写入解析历史，也不会自动回填某个候选。所有结果可选字或右键复制；`⌘↵` 复制首个已完成结果并关闭，`⌘1`–`⌘9` 复制对应服务结果并关闭。

### DeepSeek 思考模式

在 **设置 → 服务 → DeepSeek** 勾选 **关闭思考**，新的 DeepSeek 翻译和解析请求会发送 `thinking: {"type": "disabled"}`。该偏好会保存，并作用于该服务的默认及并行模型。默认未勾选，不添加思考覆盖参数，保持所选模型的原有行为；取消勾选不代表强制启用思考。

此选项仅用于内置 DeepSeek 服务，不修改模型 ID、推理强度或其他服务。字段含义以 [DeepSeek 官方 Thinking Mode 文档](https://api-docs.deepseek.com/guides/thinking_mode/) 为准；服务端是否支持由实际使用的模型和兼容网关决定。

### PopClip 集成

如果你使用 [PopClip](https://www.popclip.app/)，可以直接从 PopClip 菜单栏一键触发 MoePeek 翻译。

**安装扩展：**

1. 确保 MoePeek 已安装并正在运行。
2. 从最新 Release 下载 [`MoePeek.popclipext.zip`](https://github.com/SSBun/MoePeek/releases/latest/download/MoePeek.popclipext.zip) 并解压。
3. 双击 `MoePeek.popclipext`，PopClip 会自动完成安装。
4. 在任意应用中选中文字 → 点击 PopClip 栏中的 **MoePeek** 图标即可翻译。

## 常见问题

### macOS 提示"已损坏，无法打开"

由于应用未经 Apple 公证，macOS Gatekeeper 可能会拦截。这并非文件损坏，而是系统安全机制。解决方法：

1. 打开**终端**（Terminal）
2. 执行：

```bash
sudo xattr -r -d com.apple.quarantine /Applications/MoePeek.app
```

之后即可正常打开。

### 引导页未显示 / 想重新触发引导流程

重置所有用户偏好设置，恢复到首次启动状态：

```bash
defaults delete com.nahida.MoePeek
```

重新打开应用即可。

## 参与贡献

欢迎提 Issue 和 PR！有几点说明：

- 平时上班较忙，可能无法及时回复，通常会集中在周末统一处理 Issue 和 PR。
- 欢迎 Fork 进行二次开发。根据 AGPL-3.0 协议，衍生项目**必须同样开源**。

## 致谢

MoePeek 的诞生受到了 [Easydict](https://github.com/tisfeng/Easydict) 和 [Bob](https://github.com/ripperhe/Bob) 的启发，感谢这些项目的开拓与贡献。

依赖库：

- [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts)：Sindre Sorhus
- [Defaults](https://github.com/sindresorhus/Defaults)：Sindre Sorhus
- [Sparkle](https://sparkle-project.org/)：自动更新

## 贡献者

<a href="https://github.com/SSBun/MoePeek/graphs/contributors">
  <img src="https://contrib.rocks/image?repo=SSBun/MoePeek" />
</a>

## 赞助

<a href="https://afdian.com/a/cosyu"><img width="20%" src="https://pic1.afdiancdn.com/static/img/welcome/button-sponsorme.jpg" alt="在爱发电上赞助"></a>

## Star History

[![Star History Chart](https://api.star-history.com/svg?repos=SSBun/MoePeek&type=date&legend=top-left)](https://www.star-history.com/#SSBun/MoePeek&type=date&legend=top-left)

## 许可证

[AGPL-3.0](LICENSE)
