# rc402 工具可访问名称测试报告

- 日期：2026-07-19
- 版本：`2.12.0-rc402`
- Debug `build-for-testing`：通过
- 单元测试：**1/1 通过**
- Computer Use 运行时复验：通过

单元测试：

- `toolRailProvidesExplicitLocalizedAccessibleNamesWithoutKeyboardFocus`

运行时复验确认：

- 矩形选区主按钮名称为“矩形选区”，形状菜单仍独立为“选择选区形状”。
- 普通工具不再暴露 `paintbrush.pointed` 等 SF Symbol 内部名，画笔名称为“画笔”。
- 自绘油漆桶按钮名称为“油漆桶”，帮助文字仍完整保留。
- 工具按钮继续显式使用 `focusable(false)`。

已知的 PSD 与 Swift 6 actor-isolation 编译警告不属于本次改动，后续单独处理。
