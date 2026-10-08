# rc1757 Direct Selection 路径线段点选

## 用户行为

Direct Selection 之前只在锚点/控制柄命中时切换路径与子路径；点击曲线线段会被识别为遮挡命中，但不会选择该组件。对复合闭合路径，用户因此只能依赖属性面板的前后按钮切换布尔运算目标。

现在点击线段会选择其路径图层、所在子路径和曲线参数最近的端点，不开启锚点移动事务。锚点与控制柄仍走现有拖动事务；被锁定的路径仍被拒绝，顶层线段继续遮挡下层锚点。

## 验证

- `ImageEditorVectorLayerTests/directSelectionClickOnPathSegmentSelectsItsSubpathWithoutMoving`：验证点击第二个闭合组件的线段后，选中正确图层、子路径与最近端点，属性面板读到对应 `.subtract` 运算；点击不增加 History/Undo，也不创建锚点移动事务；随后把该组件改为 `.intersect` 只增加一个历史步骤。
- `directSelection` 定向筛选：build-for-testing 成功，4 个独立执行组 / 4 项实际测试通过，包括光标、手势接线、既有锚点拖动与新增线段点选。
- 首次运行 3/4；新增用例把点击点放在曲线参数约 0.48 的位置，却误断言最近端点为后一端。将夹具移到参数约 0.52 后，重跑 4/4 通过。生产代码未因该测试夹具问题修改。
- `scripts/test_release_contract.rb`：10 runs / 30 assertions 通过。
- `scripts/test_xomo_cli_release_build.rb`：7 runs / 24 assertions 通过。
- `scripts/test_product_overview_archive.rb`：3 runs / 26 assertions 通过。
- `scripts/verify_release_contract.rb`：通过；App、CLI 与 Xcode 六配置版本为 `2.12.0-rc1757` / build `1757`。
- `git diff --check`：通过。

所有 Xcode 测试由 `/private/tmp/veilpic-build.lock` 串行执行。没有做真实鼠标 GUI 冒烟、全量 Release 构建或 `/Applications` 覆盖安装；这些仍留给 rc1760 门槛。
