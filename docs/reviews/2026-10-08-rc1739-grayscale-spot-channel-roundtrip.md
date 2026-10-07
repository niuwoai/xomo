# rc1739：灰度 PSD 选区与专色通道往返

## 范围与基线

- 基于本地 `main` 的 rc1738 提交 `592522d0`；本版是测试夹具/回归合同补全，没有改变 PSD 编解码生产算法。
- 修正外部灰度 PSD fixture：原先名为 `Gray Spot` 的第二个附加 plane 没有 PSD 资源 1077 的 display info，实际只覆盖普通 alpha。现在 fixture 明确含有一个普通选区 alpha 和一个带洋红 spot color、75% opacity 的 spot alpha plane。
- 继续验证“外部 PSD 打开 → 通道可编辑 → 保存 Xomo 项目 → 恢复项目 → 导出 PSD → 重开 PSD”的真实交付路径。
- 本版不触发四十版本完整门槛：不运行全量 Release、真实 UI 冒烟或 `/Applications` 安装；下一门槛仍为 rc1760，已知安装版 rc1729。

## 验证证据

- PSD 专项 63/63 通过；新断言检查灰度/透明度/两个附加 plane、通道名称、`.spot` 类型、spot color space/components/opacity、project roundtrip，以及 PSD 重导入后的稳定通道语义和完整 alpha mask。
- PSD 重导入会给通道生成新 UUID，因此往返合同只比较用户可见/可编辑语义字段，不比较身份 UUID。
- `ruby -c scripts/generate_psd_compatibility_fixtures.rb`、重新生成夹具、版本发布合同和产品概览合同通过；`git diff --check` 通过。
- 未运行全量编译/回归、真实界面冒烟、签名候选或安装；不推送、不打 tag。

## 方向

- 这是经典 Photoshop 常见的选区与专色通道兼容，不扩展 Figma 能力。
- 下一步优先真实色彩空间一致性验证（PSD profile → 项目保存/恢复 → PSD/PNG 导出），以及更广泛的图像编辑闭环；不要将更多 fixture 数量本身当作产品目标。
