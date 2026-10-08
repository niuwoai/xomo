# rc1750 路径子路径与布尔运算索引对齐

## 问题

rc1749 把 Photoshop 风格的路径组件运算接入 UI 后，子路径仍可用既有命令复制或删除。几何数组在插入/删除后发生位移，但运算数组此前保持原位；例如复制第一组件会令原第二组件继承复制组件的运算，删除中间组件则会令后续路径套用前一组件的运算。

## 修复

- 复制子路径时先解析完整运算数组，并在复制几何的插入索引复制源子路径运算。
- 删除子路径时从完整运算数组移除相同索引。
- 其余路径修改仍沿用原有单步 `pushUndo()` 文档快照，因此 Undo/Redo 同步恢复几何与运算属性。

## 验证

- 扩展 `imageEditorDuplicatesCompoundPathSubpathAndSelectsCopy`：`[combine, subtract]` 复制索引 0 后必须为 `[combine, combine, subtract]`；Undo/Redo 恢复两个数组状态。
- 扩展 `imageEditorDeletesCompoundPathSubpathWithoutRemovingPrimaryPath`：删除索引 1 后必须为 `[combine]`；Undo/Redo 恢复原始/删除后状态。
- `ImageEditorVectorLayerTests`：108/108 实际通过。
- `scripts/test_release_contract.rb`：10 runs / 30 assertions 通过。
- `scripts/test_xomo_cli_release_build.rb`：7 runs / 24 assertions 通过。
- `scripts/verify_release_contract.rb`：通过，App/CLI/Xcode 版本为 `2.12.0-rc1750`，build 号 `1750`。
- `scripts/test_product_overview_archive.rb`：3 runs / 26 assertions 通过。
- `git diff --check`：通过。

Xcode 测试通过仓库构建锁串行执行。未启动真实 GUI、全量门槛或覆盖安装。

## 下一步

继续检查路径布尔操作与反转方向、子路径重新排序、向量蒙版应用/编辑等工作流中的属性索引一致性；避免把 renderer 已有格式能力误当成 UI 与几何命令全部正确。完整 Release、全量回归、真实冒烟和可恢复安装仍安排在 rc1760。
