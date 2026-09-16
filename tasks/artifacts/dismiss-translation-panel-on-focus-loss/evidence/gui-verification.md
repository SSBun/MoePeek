# 两类翻译面板失焦关闭：实机验证

## 验证版本

- 2026-09-16，macOS 实际桌面；通过 System Events 读取 AX 窗口、输入及菜单，通过 CGEvent 注入真实鼠标点击和拖动。
- Debug 构建：`xcodebuild -workspace MoePeek.xcworkspace -scheme MoePeek -configuration Debug -destination 'platform=macOS' build`，成功；构建日志 `/tmp/moepeek-both-focus-build.log` 明确包含 `WordLookupPanelController.swift` 编译。
- 启动本次 Debug 产物后进程 PID 63622，启动时间 14:22:59。可执行文件 `/Users/caishilin/Library/Developer/Xcode/DerivedData/MoePeek-dslezeiaypuqlfbqxltcgzuetmeq/Build/Products/Debug/MoePeek.app/Contents/MacOS/MoePeek`。
- `Sources/UI/PopupPanel/PopupPanelController.swift` SHA256：`8465080bdf0de28d59ae1b5928d9cd2df92e72bc7e5e06743ee8ececc8a8631c`。
- `Sources/UI/WordLookupPanel/WordLookupPanelController.swift` SHA256：`664dc911cba2dc83e8fbb6a481a8968438627f5d548c29f2fa97da610676cc12`。
- 修改前单词面板在 iTerm2 前台时仍显示 `Word Translation`；修订范围后补上单词面板失焦通知与不恢复焦点的关闭路径。

## 操作与观察

| 场景 | 操作 | 观察 |
| --- | --- | --- |
| 单词面板内部输入 | 从菜单打开 Word Translation，在原生文本区输入无敏感内容，不提交查询 | 输入区读到新文本，窗口仍存在 |
| 单词面板拖动 | CGEvent 在窗口顶部空白处按下并拖动 (+40,+20) | 窗口原点由 (1279,611) 变为 (1319,631)，窗口保持存在 |
| 单词面板切换应用 | 打开后激活 Finder | `Word Translation` 不再存在，最终前台为 Finder |
| 单词面板 ⌘Tab | 打开后发送 ⌘Tab | 450×500 目标面板计数由 1 变 0，前台为 Fork（本次切换目标），未抢回焦点 |
| 普通输入翻译内部输入 | 从菜单打开 Manual Translation，输入再清空，不提交翻译 | 读取到输入文本，面板保持存在 |
| 普通翻译语言菜单 | 输入清空后打开源语言菜单并选择当前选中的 English | 语言菜单正常打开、选择后目标面板仍存在；没有改变偏好值 |
| 普通翻译拖动 | 打开后 CGEvent 在顶部空白处拖动 (+40,+20) | 实际窗口原点变为 (1319,631)，尺寸仍为 450×500 |
| 普通输入翻译切换应用 | 激活 Finder | 目标面板计数由 1 变 0，最终前台为 Finder |
| 普通输入翻译 ⌘Tab | 打开后发送 ⌘Tab | 目标面板计数由 1 变 0，最终前台为 iTerm2 |
| 两类面板外部真实点击 | 分别打开面板，通过 CGEvent 在面板外的 iTerm2 内容区发送 mouseMoved/leftMouseDown/leftMouseUp | 两类面板均由 1 变 0，最终前台为 iTerm2 |
| 关闭后立即再次打开 | 两类面板各从菜单打开、Esc 关闭、再次打开，共各 3 轮 | 六次 opened 均为 1、closed 均为 0，没有旧回调误关新面板 |
| 普通翻译光标模式 | Finder 前台时通过 `open -g -a <本次产物> 'mopeek://translate?text=hello'` 打开，不主动激活应用 | Finder 保持前台，目标面板计数为 1；随后激活 iTerm2，计数变为 0，前台保持 iTerm2 |

光标模式仅使用无敏感示例 `hello`，可能调用已配置翻译服务；没有使用用户剪贴板或选中文本。其余输入均未提交。

## 第二轮复查后补齐：普通翻译光标模式

复查指出光标模式不能完全复用输入模式证据。以下均重新通过 `open -g -a <本次产物> 'mopeek://translate?text=hello'` 进入 `showAtCursor()`，未改变源码；运行进程仍为 PID 63622，两控制器哈希与上文一致。

| 场景 | 当前构建的直接观察 |
| --- | --- |
| 初始非激活状态的外部真实点击 | Finder 前台、目标面板数 1；未点击面板内部，直接 CGEvent 点击 iTerm2 外部内容区；最终 iTerm2 前台、面板数 0 |
| 初始非激活状态的 ⌘Tab | Finder 前台、面板数 1；未先激活面板，发送 ⌘Tab；最终 iTerm2 前台、面板数 0 |
| 真实点击后内部输入及语言菜单 | CGEvent 点击输入区，AXFocused=true；输入区原文 hello 被替换为 focus'check；随后清空输入，打开源语言菜单并重新选中原值；面板数仍为 1；最终激活 iTerm2 后为 0，焦点留在 iTerm2 |
| 光标模式拖动 | CGEvent 在顶部空白处拖动 (+40,+20)；原点由 (970,170) 变为 (1010,190)，面板数仍为 1；切换 iTerm2 后面板数为 0 |
| 非激活状态关闭后重开 | Finder 保持前台，连续 3 轮 URL 打开→Esc→重新打开；每轮打开数 1、关闭数 0；六次焦点读数均为 Finder，无旧回调误关新面板 |

首次仅通过 AX click 尝试光标模式输入时原文仍为 hello，因此未据此声明输入有效；改用 CGEvent 真实点击后，才观察到 AXFocused=true 和文本实际变更。拖动、菜单与失焦观察未依赖该失败的输入尝试。

## 采样限制及排除项

- 早期探查用 `window 1` 或空标题定位，曾选中另一个 84×77 的划词触发小窗，或访问到已消失的 AX 元素；这些失败不作为面板验收依据。最终以 `Word Translation` 标题、450×500 尺寸和视图结构定位目标面板。
- System Events 的 AX `click window` 与坐标点击探查不能稳定代表真实外部鼠标事件，最终外部点击以 CGEvent 注入结果为准。
- 某些菜单启动的早期 AX 查询发生在目标面板可访问性树可见之前；最终操作给初始化留出约 1 秒，且要求先观察到目标窗口再断言关闭。
- 本文记录主 Agent 实际观察；不声称独立 Reviewer 亲自重跑 GUI 操作。
- 未运行单元测试或项目测试套件；未覆盖多显示器、Spaces 切换或所有第三方应用组合。
- 本任务不修改解析面板、共享 PopupPanel 或 PopupDismissMonitor；工作区其他并行改动不属于本次交付。
