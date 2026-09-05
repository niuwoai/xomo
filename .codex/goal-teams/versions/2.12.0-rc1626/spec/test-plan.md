# Test Plan

## Doc Capsule

- 版本：`2.12.0-rc1626`
- 测试负责人：测试-Figma 搜索验收
- 依据：`goal-packet.md`、`plan.md`、`tasklist.md`、rc1625 测试计划与现有相邻回归。
- 被测增量：Figma 组件属性 Inspector 的本地搜索；查询匹配属性 key 或当前 `value`，并与“仅看已覆盖”“仅显示有问题”取逻辑交集。
- 明确不测为新增能力：项目持久化、History/Undo、Automation 搜索参数、剪贴板过滤、Figma 导入协议、组件库选择及 cursor；这些均应保持无改动并由既有回归护栏验证。
- 发布边界：本版不是 rc1640，不执行 Universal Release、完整项目冒烟或 `/Applications/Xomo.app` 覆盖。
- 测试设计状态：完成；本文件只定义可失败断言，不修改产品代码或测试文件，也不启动构建。

## 独立可失败测试矩阵

### TP-1626-01：共享派生搜索语义与三重过滤

- 套件：`ImageEditorFigmaProvenanceTests`
- 方式：新增且仅新增 1 个动态测试，使套件总数由 29 增至 30。
- 建议名称：`componentPropertySearchMatchesKeysAndCurrentValuesAcrossCombinedFilters()`。
- 夹具：构造乱序的 7 个属性，至少包含：
  - 健康、未覆盖属性；
  - 健康、已覆盖属性；
  - 可写诊断且已覆盖属性；
  - 不可写诊断且未覆盖属性；
  - key 含可搜索文本的属性；
  - 当前 `value` 含 `Résumé` 与 `Café` 等带变音符号文本的属性；
  - 多个属性共享 `Focus` 文本，以便验证搜索、覆盖和问题筛选的交集。
- 必须直接调用 ViewModel 的共享派生入口，不通过复制、持久化或 Automation 间接证明。

| 输入 | 预期断言 |
| --- | --- |
| 空字符串 | 不应用搜索；返回全部 7 个 key，按 key 升序稳定排序 |
| 仅空白（空格、tab、换行） | trim 后视为空查询；结果与空字符串完全相同 |
| 大小写混合且带首尾空白的 key 查询，如 `  bRaVo  ` | 仅命中对应 key，证明 trim 与不区分大小写 |
| 无变音符号的 `resume` | 命中当前值含 `Résumé` 的属性 |
| 大写无变音符号的 `CAFE` | 命中当前值含 `Café` 的属性，证明大小写与 diacritic 同时折叠 |
| 只存在于当前 `value`、不在 key 中的查询 | 命中该属性，证明匹配的是当前值而非 imported default/preferred value |
| 不存在的查询 | 返回空数组 |
| `focus` + 两个布尔筛选均关闭 | 返回所有 key/value 含 `focus` 的属性，且排序稳定 |
| `focus` + `onlyOverrides=true` | 只保留搜索命中且已覆盖的属性 |
| `focus` + `onlyDiagnostics=true` | 只保留搜索命中且诊断非空的属性 |
| `focus` + 两个筛选均为 `true` | 只保留同时满足搜索、已覆盖、有诊断的属性；不得使用 OR |

- 额外纯派生断言：遍历全部查询与筛选组合前后，属性字典、默认快照、document history、undo/redo 栈内容与计数均不变化。
- 失败判据：任一匹配依赖大小写/音标、空白查询缩小结果、默认值误命中、筛选使用 OR、结果未排序或查询造成模型写入，均视为失败。

### TP-1626-02：Inspector 搜索 UI 源码合同

- 套件：`ImageEditorFigmaProvenanceTests`
- 方式：扩写现有 `componentPropertyOverrideInspectorExposesLocalizedFilterAndEmptyState()`，不增加测试数。
- 必须断言：
  - Inspector 存在本地、非持久化搜索状态；
  - 使用本地化搜索 placeholder/label，用户可见文本没有硬编码；
  - 搜索输入有稳定 accessibility identifier：`image-editor-figma-component-property-search`；
  - 有显式清除动作，清除后查询变为空字符串；
  - 清除动作使用本地化 accessibility label，并有稳定 identifier：`image-editor-figma-component-property-search-clear`；
  - View 调用共享 ViewModel 入口时同时传入搜索查询、`onlyOverrides` 与 `onlyDiagnostics`，没有在 View 中复制一套过滤算法；
  - 无命中时显示本地化过滤空态；
  - 搜索控件只位于 Figma 组件属性 Inspector，复制全部属性/复制覆盖/粘贴覆盖的语义与搜索状态解耦；
  - 文本框焦点不会把普通键入转发为画布工具快捷键；若实现采用现有 SwiftUI 文本输入焦点机制，源码合同至少验证其使用可聚焦文本控件且没有 `.focusable(false)` 施加在输入框上。
- 失败判据：文案硬编码、缺少任一稳定标识、清除不能归零查询、View 自行过滤、搜索状态影响复制/粘贴或搜索输入不可获得键盘焦点，均视为失败。

### TP-1626-03：三语资源完整性

- 套件：`LocalizationResourceTests`
- 方式：保持 46 个测试；复用 `supportedLocalizationTablesKeepMatchingKeys()` 验证三语 key 对齐，并在现有 Figma Inspector 源码合同中验证搜索与清除文案 key 被消费。
- 必须具备的语义文案：搜索 placeholder/label、清除搜索；简体中文、英文、日文三个 `Localizable.strings` 必须同时存在且非空。
- 静态补充：三个 strings 文件分别执行 `plutil -lint`。
- 失败判据：任一语言缺 key、值为空、plist 语法无效或 UI 未消费资源 key，均视为失败。

### TP-1626-04：Automation 协议不回归

- 套件：`XomoAutomationTests`
- 方式：不新增或改写搜索协议测试，总数保持 323；完整运行现有套件。
- 护栏：`xomo.figma.component_properties` 的 action 集合、参数、根字段与 `properties` 负载不得因 UI 搜索新增字段或改变语义；`list/set/reset/resetAll/copyOverrides/pasteOverrides` 及健康计数继续通过。
- 静态审查：最终 diff 中 `XomoAutomationRegistry.swift`、wire schema 和 CLI/MCP schema 不应出现 rc1626 搜索改动。
- 失败判据：既有 snapshot/字段/action 任一变化、搜索查询进入 wire 层或测试数偏离 323，均视为失败。

### TP-1626-05：组件库与工具 cursor 不回归

- 套件：`ImageEditorCanvasCursorTests`
- 方式：不新增测试，总数保持 128；完整运行既有套件。
- 护栏：组件库选择仍返回 `NSCursor.arrow`；工具模式继续使用各工具的语义 cursor，手形只用于真实平移。
- 静态审查：最终 diff 不应修改 cursor 路由、组件库 selection mode 或 pointer ownership。
- 失败判据：既有 128 项任一失败、组件模式泄漏上次工具 cursor，或 rc1626 diff 触碰 cursor 行为，均视为失败。

### TP-1626-06：CLI/MCP 与发布契约

- `swift test --package-path xomo-cli`：保持 2/2；搜索不得扩张 CLI/MCP 协议。
- `ruby scripts/test_release_contract.rb`：保持 9/9。
- `ruby scripts/test_run_tests_isolated_contract.rb`：通过。
- `ruby scripts/verify_release_contract.rb --out test-reports/rc1626-release-contract`：版本 `2.12.0-rc1626`、build `1626` 与文档契约一致。
- `git diff --check`：通过。

## 串行门禁清单

- [x] 开始任何 Xcode/SwiftPM/打包流程前分别确认不存在 `xcodebuild`、`swift-frontend`、`release_mac_apps`。
- [x] 先构建并运行 `ImageEditorFigmaProvenanceTests`，精确 30/30。
- [x] 复用同一 DerivedData，以 `--skip-build` 运行 `XomoAutomationTests`，精确 323/323。
- [x] 复用同一 DerivedData，以 `--skip-build` 运行 `LocalizationResourceTests`，精确 46/46。
- [x] 复用同一 DerivedData，以 `--skip-build` 运行 `ImageEditorCanvasCursorTests`，精确 128/128。
- [x] 构建槽空闲后运行 CLI/MCP，精确 2/2。
- [x] 三语 strings `plutil -lint` 全部通过。
- [x] 发布契约 9/9、隔离运行器契约、release verifier 与 `git diff --check` 全部通过。
- [x] 动态报告来自未被外部并发构建污染的有效运行。
- [x] 独立审查确认 Automation、项目格式、剪贴板、导入、组件库选择和 cursor 均无行为变化。
- [x] 非 rc1640：确认未执行 Release、安装或 `/Applications` 覆盖。

## 完成状态与风险

- 测试设计：`complete`。
- 动态执行：`complete`，Figma 30/30、Automation 323/323、Localization 46/46、cursor 128/128、CLI/MCP 2/2 全部通过。
- 首要风险：若只测单个筛选，AND 组合错误可能漏检；因此 TP-1626-01 明确覆盖搜索与两个既有筛选的四种组合。
- 文本风险：Swift 默认字符串比较不必然满足大小写、trim 与 diacritic 三项要求；测试分别设置反例，不能用英文 ASCII 样例冒充通过。
- 焦点风险：搜索框键入可能泄漏到画布快捷键；需要源码合同与最终人工/动态冒烟关注，但本版非 40 版本门禁，不以完整 UI 冒烟替代定向测试。
- 协议风险：本地搜索若误入 Codable/Automation 会扩大持久化表面；既有 Automation、CLI/MCP 与项目编码回归必须保持原样。
