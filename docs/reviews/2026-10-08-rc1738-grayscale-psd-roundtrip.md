# rc1738：灰度 PSD 图层与通道往返

## 范围与基线

- 基于本地 `main` 基线 `432dba2b`（rc1737，已合入）；本版改动尚未提交，远端和安装状态不在本轮修改范围内。
- 补充 8 位灰度 PSD 的无透明度可编辑图层，以及灰度、透明度和多个额外 alpha plane 的组合覆盖；支持按原始未预乘设备 RGB 位图通道读取 PSD 导出像素，避免符合严格条件的位图再次经过 `NSColor` 色彩空间转换。
- 本版本不是四十版本完整门槛：不运行全量 Release 构建、真实界面冒烟或 `/Applications` 覆盖安装；下一门槛仍为 rc1760，当前已知安装版本 rc1729。

## 用户路径与实现

- 新增独立生成的 `grayscale-opaque-layer.psd`：单颜色 plane、无透明度，导入后仍是一层可编辑的不透明图层；项目序列化恢复后仍保留灰度与不透明语义。
- 新增 `grayscale-extra-alpha.psd`：灰度颜色 plane、透明度和两个有名称的附加 alpha plane；验证通道边界、名称、数据及项目保存恢复。
- 像素精确的 PSD 往返断言对“直接导入 PSD → 直接导出 PSD”执行；Xomo 项目快照将图像编码为 PNG，AppKit 会将无显式 ICC 的设备 RGB 位图转换到 PNG 色彩空间，因而项目恢复断言验证通道一致和不透明度，不把不同色彩空间下的原始字节误当作相同视觉颜色。
- 初次将 PSD 重新导出接在项目序列化恢复之后时，发现灰度值例如 16 会以 20 存储。这一差异属于项目 PNG 编码的色彩空间转换路径，与直接 PSD codec 往返不同；本版没有扩张为通用项目图像 ICC/色彩管理改造。该路径的视觉等价仍需以明确的共同色彩空间验证，不声称原始字节相等。

## 验证证据

- `scripts/run_tests_isolated.rb --group-by-suite --filter ImageEditorPSDTests`：63/63 项通过，失败/跳过均为 0；覆盖新加两项 fixture 测试及既有 PSD 回归。
- `ruby scripts/test_release_contract.rb`：10 runs、30 assertions 通过。
- `ruby scripts/test_xomo_cli_release_build.rb`：7 runs、24 assertions 通过。
- `ruby scripts/test_run_tests_isolated_contract.rb`：PASS。
- `ruby scripts/generate_psd_compatibility_fixtures.rb` 后执行 `git diff --check`；生成器与清单保持一致，无空白错误。
- 未运行全量编译/全量测试、真实 UI 打开 PSD、签名候选或安装；不推送、不打 tag。

## 后续重点

- 在共同 sRGB 渲染目标下验证“PSD 导入 → 项目保存/恢复 → PNG 或 PSD 导出”的视觉和像素语义；如用户可见颜色偏差被复现，再单独设计项目档案中的 ICC/profile 保真修复和 Undo/Redo/导出覆盖。
- 继续优先经典图像编辑工作流、像素与色彩准确性；Figma 保持必要兼容，不扩展该方向。
