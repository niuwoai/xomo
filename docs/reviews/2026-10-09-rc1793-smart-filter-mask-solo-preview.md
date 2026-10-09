# rc1793 Smart Filter 蒙版灰度预览

## 范围

Option-click 有蒙版的 Smart Filter 缩略图，临时将原始蒙版以黑白灰显示在画布上；普通点击仍进入/退出绘制。切换预览不建立文档 History 或 Undo 项，并与 Quick Mask、图层蒙版 solo、通道预览互斥。同期把产品概览的完整门槛摘要校正到当前 rc1800。

## 验证

- `ImageEditorSmartFilterMaskTests`：12/12 通过，包含 Option-click 灰度像素、普通点击绘制、切换通道退出预览，以及 History/Undo 不变断言。
- `ImageEditorScopeTests/smartFilterRowsExposeNonFocusableResultOpacityAndBlendControls`：1/1 通过，验证缩略图视图把 Option 修饰键传入 ViewModel 并暴露预览状态。
- 发布合同：10 次运行、30 项断言通过；CLI Release 合同：7 次运行、24 项断言通过；概览归档合同：3 次运行、30 项断言通过。
- `git diff --check` 通过。测试使用隔离 DerivedData；未运行完整 Release、全量回归或桌面冒烟。
- 当前 `/Applications/Xomo.app` 实读 `2.12.0-rc1760` / build `1760`；本版未安装。完整 Release/桌面门槛仍为 rc1800。
