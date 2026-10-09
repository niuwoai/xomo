# rc1794 Smart Filter 蒙版临时停用

## 范围

为 Photoshop 常用的 Shift-click 蒙版旁路工作流增加 Smart Filter 蒙版启用状态。Shift-click 蒙版缩略图，或使用属性面板中的“停用蒙版 / 启用蒙版”按钮，可在不删除蒙版像素、不重置浓度/羽化/反相的情况下切换覆盖。停用时滤镜按完整结果渲染；再次启用恢复原蒙版。清除蒙版会把该状态归一为启用。

状态写入项目 Codable 数据，缺少该字段的旧项目默认为启用；Undo/Redo 和属性面板操作共用同一模型事务。缩略图变暗并显示斜线，辅助功能值明确报告停用状态。Backdrop Filter 不接受此蒙版状态操作。

## 验证

- 基线：`main` / `afac9543`（rc1793）；实现分支：`codex/rc1794-smart-filter-mask-toggle`。
- `ImageEditorSmartFilterMaskTests`：13/13 通过，覆盖实际像素变化、Shift-click 不进入绘制/预览、旁路后与无蒙版完整滤镜结果逐像素相同、蒙版/密度/羽化/反相保留、Undo/Redo、项目保存重开及旧格式默认值。
- `ImageEditorScopeTests`：198/198 通过，覆盖属性面板按钮、缩略图修饰键入口及稳定辅助功能标识。
- `LocalizationResourceTests`：46/46 通过。
- 发布合同：10 runs / 30 assertions；CLI Release 合同：7 runs / 24 assertions；产品概览归档合同：3 runs / 30 assertions，均通过。
- `git diff --check` 通过。定向测试使用隔离 DerivedData 与仓库构建锁。
- 未运行完整 Release/全量门禁或桌面 Shift-click 实操。`/Applications/Xomo.app` 仍是 rc1760/build1760；下一完整门槛为 rc1800，届时仍需完整编译、全量回归、桌面编辑/光标冒烟及可恢复覆盖安装。

测试报告位于 `/private/tmp/xomo-rc1794-smart-filter-mask-toggle-report-final5`、`/private/tmp/xomo-rc1794-smart-filter-mask-toggle-scope` 和 `/private/tmp/xomo-rc1794-smart-filter-mask-toggle-localization`。
