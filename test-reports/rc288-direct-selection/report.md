# rc288 Photoshop 直接选择专项回归

- 版本：`2.12.0-rc288`
- 结果：专项通过

## 通过项

- `directSelectionSwitchesToPathAnchorAndMovesOneNode`
- `directSelectionUsesTheFamiliarSystemArrowAndSharesTheAGroup`
- `pathSelectionUsesTheFamiliarSystemArrowAndPhotoshopShortcut`
- `componentSidebarWiresMoveSemanticsIntoCanvasCursorAndGestures`
- 三语言 Localizable.strings 键集合检查
- 发布契约：3 次运行、7 项断言全部通过
- `xcodebuild` 聚焦测试编译：macOS 13.0 目标通过

## 交互边界

直接选择工具只在路径锚点或控制柄附近命中，点击后会自动切换到所属路径图层；拖动沿用现有路径锚点事务，释放时提交一次 Undo/History。单纯点击不移动时会清理临时快照，不污染历史面板。

`A` 选择路径整体，`Shift+A` 在路径选择和直接选择之间切换；两者均使用系统箭头，避免用难以理解的机械图标冒充工具语义。

## 既有失败

更大范围的矢量图层套件仍有预先存在的颜色/路径渲染断言失败，侧栏套件仍有主题 Token 刷新断言失败；这些与本次直接选择逻辑无关，已单独保留在测试输出中。
