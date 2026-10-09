# rc1799 Smart Filter 蒙版缩放图层选区回归

日期：2026-10-10（Asia/Shanghai）

## 验证范围

补充 `paintingSmartFilterMaskMapsCanvasSelectionOntoScaledOffsetLayerPixels`：使用 64×48 画布、16×12 像素图层和偏移的 2×图层 frame，在 Smart Filter 蒙版已有全覆盖基础上启用局部画布选区并绘制。

回归验证选区内笔刷映射到正确的图层蒙版像素、选区外笔刷不造成第二次蒙版变更、底层图像像素不变，且一次笔刷事务可 Undo/Redo 恢复。

## 测试结果

- `ImageEditorSmartFilterMaskTests`：14 项，通过 14 项、失败 0。
- `ruby scripts/test_release_contract.rb`：10 runs、30 assertions，0 failures/errors。
- `ruby scripts/test_xomo_cli_release_build.rb`：7 runs、24 assertions，0 failures/errors。
- `ruby scripts/test_product_overview_archive.rb`：3 runs、30 assertions，0 failures/errors。
- `git diff --check`：通过。

新增回归通过当前生产实现，无需修改蒙版坐标转换代码。

## 尚未完成的门槛

本次不是全量测试、Release archive、桌面冒烟、签名/公证或安装验收。下一次完整门槛仍为 rc1800；本次未覆盖 `/Applications/Xomo.app`。
