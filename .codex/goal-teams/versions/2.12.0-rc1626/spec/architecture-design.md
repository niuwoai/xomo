# Architecture Design

## Doc Capsule

- 版本：`2.12.0-rc1626`
- 主题：Figma 组件属性 Inspector 本地搜索的共享派生模型与 SwiftUI 接线。
- 决策：扩展现有 `selectedLayerFigmaComponentPropertyKeys` 纯派生入口，不新增持久模型、协议字段或第二套过滤器。
- 数据流：Inspector 本地查询字符串 → ViewModel 规范化并执行三重 AND 过滤 → 统一按属性 key 排序 → Inspector 渲染或显示组合筛选空态。
- 状态边界：查询只存于 `ImageEditorView` 的 `@State`；不进入 Document、History/Undo、Automation、剪贴板或 Figma 导入模型。
- 验证者：`审查-Figma 搜索回归`。

## 共享派生入口

在 `ImageEditorViewModel` 现有函数上追加默认参数，保持已有调用兼容：

```swift
func selectedLayerFigmaComponentPropertyKeys(
    onlyOverrides: Bool,
    onlyDiagnostics: Bool = false,
    searchQuery: String = ""
) -> [String]
```

实现保持一次字典遍历、一次末尾排序：

1. 先规范化 `searchQuery`；结果为空时搜索条件恒为真。
2. `onlyOverrides == true` 时，必须满足 `hasSelectedFigmaComponentPropertyOverride`。
3. `onlyDiagnostics == true` 时，必须满足 `property.diagnosis.diagnostic != nil`。
4. 查询非空时，规范化后的 `key` 或 `property.value` 至少一个包含查询。
5. 仅当所有启用条件都满足时返回 key，最后统一 `.sorted()`。

逻辑必须是：

```text
(!onlyOverrides || isOverride)
&& (!onlyDiagnostics || hasDiagnostic)
&& (normalizedQuery.isEmpty || keyMatches || currentValueMatches)
```

不得先分别生成多个结果数组再取并集；不得让搜索放宽覆盖或问题筛选。排序仍以原始 key 的 Swift 字符串顺序为准，不能按匹配位置、字典枚举顺序或本地化比较结果重排。

## 搜索规范化边界

建议在 `ImageEditorViewModel` 内保留一个无副作用私有 helper：

```swift
private func normalizedFigmaComponentPropertySearchText(_ value: String) -> String
```

规范化顺序：

```swift
value
    .trimmingCharacters(in: .whitespacesAndNewlines)
    .folding(
        options: [.caseInsensitive, .diacriticInsensitive],
        locale: Locale(identifier: "en_US_POSIX")
    )
```

采用固定 locale，避免系统区域设置令同一文档产生不同匹配结果。边界只覆盖已确认的大小写、首尾空白和变音符号；本版不做分词、模糊匹配、类型/诊断文案匹配、候选列表全量匹配或宽度折叠。

“当前值”严格指 `XomoFigmaComponentProperty.value`，即当前写回/复制使用的属性值。文本草稿尚未提交时不改变筛选结果，避免输入属性内容导致列表在编辑中消失；候选项中未被选中的名称也不参与搜索。

## SwiftUI 本地状态与调用点

在 `ImageEditorView` 与现有两个 Figma 属性筛选状态并列增加：

```swift
@State private var figmaComponentPropertySearchQuery = ""
```

在 Figma 组件属性区标题/摘要之后、属性列表之前放置紧凑搜索行：

- `TextField` 绑定 `$figmaComponentPropertySearchQuery`，placeholder 走三语 i18n。
- 查询非空时显示清除按钮；按钮只把状态设为 `""`，并使用 `.focusable(false)`，避免抢走文本输入焦点。
- 搜索框提供稳定 accessibility identifier；清除按钮也提供独立 identifier。
- 不使用 `@AppStorage`，不写入 ViewModel，不触发 Undo/History。

唯一列表调用点改为：

```swift
let visibleFigmaComponentPropertyKeys = viewModel
    .selectedLayerFigmaComponentPropertyKeys(
        onlyOverrides: showsOnlyFigmaComponentPropertyOverrides,
        onlyDiagnostics: showsOnlyFigmaComponentPropertyDiagnostics,
        searchQuery: figmaComponentPropertySearchQuery
    )
```

空态沿用组合筛选空态，但触发条件扩展为：结果为空，且覆盖筛选、问题筛选或去除首尾空白后的搜索查询至少一项有效。仅仅输入空格不应出现“无结果”。批量复制、粘贴、全部重置仍针对既有完整语义，不消费可见 key 列表。

## 焦点安全

- 搜索 `TextField` 必须保持可聚焦，不能添加 `.focusable(false)`。获得焦点后，原生 field editor 是 `NSTextView`/`NSTextField`，现有键盘和空格平移事件路由会把它识别为活动文本输入，从而阻止工具快捷键、Delete、Space 等编辑器动作误触。
- 不新增全局键盘快捷键，也不在输入变化时主动调用 `claimEditorResponder`。
- 切换选中图层时，沿用 `reclaimEditorKeyboardFocusAfterLayerSelection` 的既有行为：用户点击画布/图层完成选择后退出搜索输入焦点，恢复编辑器快捷键所有权。搜索文本本身保留，便于跨图层使用同一查询。
- 不把搜索状态加入 `ImageEditorLayerSelectionKeyboardFocusRestorer` 的“显式编辑器”豁免参数；该搜索不编辑文档内容，选择动作优先恢复画布键盘控制。
- 清除按钮不可聚焦；鼠标清除后输入框保持当前 responder 行为，不引入额外焦点跳转。

## 不变量与风险

- 不修改 `XomoFigmaComponentProperty` Codable 结构或项目 schema。
- 不修改 Automation action/result、pasteboard payload、Figma 导入协议或组件库选择状态。
- 不修改 cursor 路由；组件库选择继续保持系统箭头语义。
- 搜索在属性数量增大时为 `O(n)` 规范化过滤加 `O(k log k)` 排序；本里程碑不引入缓存，避免缓存失效复杂度。若未来属性规模证明存在性能问题，再以 profile 证据演进。
- 风险：若直接搜索编辑中的 TEXT draft，列表可能因自身输入而消失；因此只读已提交 `property.value`。
- 风险：若 UI 自行重复过滤，会与 ViewModel 单测产生语义漂移；必须只消费共享 key API。
- 风险：若空态只看 toggle，会在纯搜索无结果时静默空白；触发条件必须包含有效查询。

## 完成状态

- 架构设计：完成。
- 代码实现：未在本成员锁定范围内执行。
- 构建与测试：未运行，交由开发成员和 Goal Lead 按单构建槽门禁执行。
- 独立复审：待 `审查-Figma 搜索回归` 验证最终差异。
