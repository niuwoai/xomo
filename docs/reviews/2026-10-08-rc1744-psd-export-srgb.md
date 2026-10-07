# rc1744：PSD sRGB 导出与复合图像颜色

## 范围与基线

- 基于本地 `main` 的 `d835adf0`（rc1743）；实现期间在 `codex/psd-export-srgb-rc1744` 开发，尚未提交。
- PSD Image Resources 写入有效 sRGB ICC 资源 1039；PSD 图层与复合图像均以 sRGB 像素样本输出，与嵌入 profile 对齐。
- sRGB CGImage 快速读取限定为默认字节序及受支持的 RGBA alpha 排列；premultiplied RGB 在写 PSD 前恢复为直 alpha。
- 新增 Display P3 源图测试（一个不透明、一个半透明像素）：导出 PSD 后分别检查可编辑图层解码像素与文件内 Composite Image Data 平面，并与导入文档的直 alpha sRGB RGBA 逐通道比较。

## 验证

- 最终 `ImageEditorPSDTests` 套件：66 项全部通过，0 失败/跳过；报告 `/tmp/veilpic-rc1744-psd-suite-final4/report.md`。
- 新 P3→PSD 专项同时验证 Image Resource 1039、兼容性报告无问题、图层 RGBA 与 PSD 复合平面 RGBA；两处均与 sRGB 参考值一致，透明像素也正确恢复直 alpha 样本。
- 调试中测试确实发现图层及复合平面样本偏移（`[223, 134, 0, 255]` 对比 `[213, 115, 0, 255]`）；加入原始 sRGB CGImage 路径及复合图像归一化后，含半透明像素的最终全套通过。
- 版本合同 10 runs/30 assertions、CLI release build contract 7 runs/24 assertions、产品概览归档合同 3 runs/26 assertions 均通过；`scripts/verify_release_contract.rb` 显示 App/CLI `2.12.0-rc1744`、Xcode 六配置与 build number `1744` 一致。
- `git diff --check` 通过。

## 限制与下一步

- 未在 Photoshop 等外部编辑器内进行实际打开/显示验证；其它 RGB/灰阶 profile、透明混合复杂场景、JPEG/WebP/PDF 导出未由本版证明。
- 本版不是 rc1760 四十版本质量门槛；未运行全量项目 Release、UI 冒烟或 `/Applications` 覆盖安装，当前安装版记录为 rc1729。
- 后续优先在 rc1760 门槛中用外部软件检查 P3 参考像素、PSD 图层与复合图像显示一致性，并保留颜色配置文件未支持时的清晰降级报告。
