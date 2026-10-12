# rc1820 大画笔快捷尺寸预设验证

- 日期：2026-10-13
- 分支：`codex/brush-size-presets-rc1820`
- 起始基线：`515bf896`（rc1819 已合入 main）
- 目标：让 rc1819 新增的 96 px 以上画笔尺寸能在菜单中快速选取，不要求用户精确拖动较长范围的滑块。

## 实现

- 将常用笔刷直径集中为 `[1, 4, 12, 24, 48, 96, 192, 384, 512]`，菜单不再维护一份与画笔限制脱节的局部数组。
- “窗口 → 选项 → 尺寸”菜单以共享预设表生成按钮，保留原有本地化尺寸文案和 `applyOptionsBrushSizePreset` 设置路径。
- 新增回归验证共享列表不超出统一画笔范围；菜单接线测试确认 192/384/512 px 均可经同一选项命令设置并更新状态。

## 验证

- `ImageEditorScopeTests`：199/199
- `ImageEditorBrushDynamicsPreferencesTests`：38/38

两套相关 XCTest 均通过，构建锁下完成一次 `build-for-testing` 后复用测试产物。rc1840 完整 Release、全量测试、桌面冒烟和本机安装门槛仍未执行。
