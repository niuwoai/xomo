# rc1749 路径组件运算验证

## 目标与用户行为

路径布尔运算此前已存在于 `ImageEditorPathBoolean.swift`、项目文档和 PSD 读写中，但路径编辑面板没有入口。现在选中一个闭合路径子路径后，可直接选择排除、合并、减去、相交或延续上一组件；运算修改路径数据，不栅格化路径。文案走简中、英语和日语本地化。

## 事务与实现

- ViewModel 读取所选子路径当前解析后的运算；仅单选、闭合路径且有效子路径可修改，像素锁定时禁用。
- 设置器将旧文档的默认运算先解析并写成完整数组，只改当前子路径；相同值不产生历史事务。
- 修改先 `pushUndo()`，再替换 shape 内容并追加一条路径组件运算历史。Undo/Redo 恢复路径数据与合成像素。
- UI Picker 复用已有 renderer 的五种运算；未选中路径工具时不显示。

## 验证

- 新增 `selectedPathComponentOperationIsUndoableAndRedoable`：真实重叠的两个闭合矩形，检查只修改第二个子路径、历史只增加一项、减去后第二个形状独占区露出黑底、Undo 恢复白色排除结果、Redo 再次露出黑底。目标测试实际执行 1/1 通过。
- `ImageEditorVectorLayerTests`：108/108 通过。
- `ImageEditorProjectDocumentTests`：13/13 通过。
- `ImageEditorPSDTests`：66/66 通过。
- `scripts/test_release_contract.rb`：10 runs / 30 assertions 通过。
- `scripts/test_xomo_cli_release_build.rb`：7 runs / 24 assertions 通过。
- `scripts/verify_release_contract.rb`：通过；App、CLI、Xcode 六配置 marketing/build 号分别一致为 `2.12.0-rc1749`/`1749`。
- `git diff --check`：通过。

所有 Xcode 测试通过仓库级 `/private/tmp/veilpic-build.lock` 串行执行。调试过程中一次无效 alpha 断言已更换为实际可见 RGB 对照；未将那次失败计入通过结果。

## 未验证与下一步

- 没有启动应用做真实鼠标/SwiftUI Picker 冒烟，也没有运行全量项目门槛或覆盖 `/Applications`；下一四十版本门槛仍为 rc1760。
- `continuePrevious` 对应 Photoshop 路径组件分组语义；本版检查了值、渲染现有 PSD 回归，但没有新增组合型曲线/洞的专门视觉夹具。
- 下一步聚焦路径选择器的真实交互检查及 Phase C 的 direct/path selection、曲线布尔操作整合；不要扩张 Figma。
