# rc1837：图像尺寸缩放羽化选区

- 基线：`main` / `7bb0d2a933e22a5e43cb5325549acf5255b07d6a`（rc1836）
- 版本：`2.12.0-rc1837`，build `1837`
- 范围：让 Image Size 的选区栅格蒙版跟随图像尺寸对话框所选插值模式。

## 问题与修复

Image Size 已按最近邻/平滑模式缩放图层像素、栅格蒙版和 Alpha 通道，但 `ImageEditorSelection.scaled` 对活动选区和已保存选区一律调用最近邻。用户平滑放大含羽化选区的文档时，图像及其它蒙版使用平滑覆盖，而两个选区状态会变成阶梯状二值边缘；随后用选区绘制、复制或保存选区时会产生覆盖不连续。

现在把所选 `ImageEditorImageResampling` 传入活动及已保存选区的缩放路径，并复用现有 `ImageEditorSelectionMask.resized(to:resampling:)`：最近邻仍保留硬边语义，平滑模式对软覆盖执行双线性插值。矢量选区路径的几何缩放不变。

## 验证

- `ImageEditorSliceImageSizeTransformTests`：10/10 测试通过。新增回归同时验证活动及已保存的栅格选区，在最近邻模式下保持二值边缘、在平滑模式下出现中间覆盖值，并验证项目数据的一次 Undo/Redo 往返。
- 测试通过隔离运行器在构建锁下执行；最终 build-for-testing 成功，报告位于 `/private/tmp/xomo-rc1837-tests-tmp/report.json` 与 `report.md`。
- 早期尝试受网络策略及仓库 DerivedData 写权限影响，未执行测试；最终运行复用了本机 Swift Package 缓存并把派生产物放在 `/private/tmp`，未改系统安全设置。
- 未运行全量 Release、完整测试集、桌面冒烟或 `/Applications` 安装；这些仍属于 rc1840 门槛。当前安装版和签名信任问题没有因本次测试而改变。
