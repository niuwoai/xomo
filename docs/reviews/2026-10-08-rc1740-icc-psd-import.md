# rc1740：PSD ICC profile 导入转换

## 范围与基线

- 基于本地 `main` rc1739，起始 HEAD 为 `69d429e0fb5f116b55232dc158a7c6a9cc6412a0`。
- PSD Image Resource 1039 现在被解析为 ICC profile；与 PSD 模式匹配的 RGB/灰阶 profile 用于图层样本到设备 RGB 的转换，alpha 原样保留。非法或模式不匹配 profile 仍报告 `.colorProfileIgnored`，未标记 PSD 保持旧路径。
- 新增 Display P3 与灰阶 ICC 外部 PSD 夹具注入测试，分别按 CoreGraphics 转换到 sRGB 的结果核对颜色和 alpha，并检查兼容报告不再提示有效 ICC 被忽略。

## 验证证据

- `ImageEditorPSDTests` 专项实际执行 65 项、65 项通过，包含 Display P3 与灰阶 ICC 数值用例，以及既有灰度、alpha、layer/group/mask、路径和 PSD round-trip 用例。
- `git diff --check` 通过；版本契约等检查在版本文件同步后执行。

## 未验证与限制

- 已观察到现有 `qingtuPNGData()` TIFF 中转会使本 P3 样本从导入时 `[213,115,0]` 变为项目恢复后 `[223,134,0]`。因此本版本只声称 PSD 图层导入样本转换，不声称 Xomo 项目 PNG 往返、PSD/PNG 导出或显示器渲染的 ICC 等价。
- 下一里程碑应单独修复并测试 PNG/项目色彩标记或统一编码路径；覆盖半透明、不同 RGB profile、坏 profile、flattened composite、layered PSD 以及导出后重开。不要通过放宽像素阈值掩盖偏色。
- 本版本不是四十版本完整门槛：未跑全量构建/全量回归、UI 冒烟或安装；未推送、打 tag。下一门槛 rc1760，已知安装版本 rc1729。

## 方向

- 此改动支持经典图像文件忠实导入，不扩展 Figma 范围；项目/导出色彩一致性是明确后续工作。
