# rc1792 Smart Filter 蒙版画布反馈

## 目标

进入 Smart Filter 蒙版绘制时，确保笔刷不会继续写入 Quick Mask 或受旧通道/图层蒙版预览状态干扰；在画布上以红色覆盖显示实际不参与滤镜的蒙版区域。覆盖预览遵循蒙版反相、密度、羽化，并缓存至文档图像缓存失效。

## 验证

- `ImageEditorSmartFilterMaskTests`：11/11 通过，覆盖 Quick Mask 退出后真实笔刷改写 Smart Filter 蒙版、红色覆盖落在滤镜排除区，以及密度/羽化/反相更新后的遮罩值。
- `ImageEditorLayerThumbnailSelectionTests`：20/20 通过，既有图层蒙版行为加上蒙版叠加视图接线与图层画布坐标映射断言。
- `scripts/test_release_contract.rb`：10 runs / 30 assertions 通过；`scripts/test_xomo_cli_release_build.rb`：7 runs / 24 assertions 通过；`scripts/test_product_overview_archive.rb`：3 runs / 30 assertions 通过。
- 尚未运行完整 Release、桌面交互冒烟或 `/Applications` 安装；完整门槛仍为 rc1800。
