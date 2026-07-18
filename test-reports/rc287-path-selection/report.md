# rc287 Photoshop 路径选择专项回归

- 版本：`2.12.0-rc287`
- 结果：专项通过

## 通过项

- `pathSelectionHitsClosedPathGeometryAndMovesWholeLayer`
- `pathSelectionUsesTheFamiliarSystemArrowAndPhotoshopShortcut`
- `componentSidebarWiresMoveSemanticsIntoCanvasCursorAndGestures`
- 三语言 Localizable.strings 键集合检查
- 发布契约：3 次运行、7 项断言全部通过
- `xcodebuild` 聚焦测试编译：macOS 13.0 目标通过

## 交互边界

路径选择工具只命中路径实际填充或描边几何，不会因为点击路径外的矩形区域而误选；选中后拖拽整条路径，移动过程显示现有灰色虚线预览，释放时提交一次 Undo/History。

## 既有失败

更大范围的矢量图层套件仍有预先存在的颜色/路径断言失败，侧栏套件仍有主题 Token 刷新断言失败；这些与本次路径选择逻辑无关，已单独保留在测试输出中。
