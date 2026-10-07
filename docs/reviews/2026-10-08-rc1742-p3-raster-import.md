# rc1742：普通广色域图片导入色彩

## 范围与基线

- 基于本地 `main` rc1741，起始提交 `3571340a92f9423f750acaaed4353d7f4ce9308d`。
- 将普通栅格导入的源 `CGImage` 按其色彩空间绘入显式 sRGB `CGContext`，并把带 sRGB 标记的图像进入编辑文档；外部文档打开与图片图层导入共用归一化路径。
- P3 PNG 样本覆盖 PNG 编码/解码、图层导入、项目 JSON 保存恢复，检查转换后的 RGBA 与 CoreGraphics sRGB 参考值一致。

## 验证

- P3 PNG 导入→项目 JSON 保存恢复专项：1/1 通过；PNG 解码后确认仍携带 Display P3 色彩空间，导入图层和重开图层的 RGBA 均精确匹配 CoreGraphics sRGB 参考值。报告 `/tmp/veilpic-rc1742-p3-import/report.md`。
- 外部文档打开套件：24/24 通过；画布文件拖入套件：10/10 通过，均复用本次 `build-for-testing` 产物。报告分别在 `/tmp/veilpic-rc1742-external-open/report.md`、`/tmp/veilpic-rc1742-file-drop/report.md`。
- release contract：10 runs/30 assertions；CLI build contract：7 runs/24 assertions；产品概览归档合同：3 runs/26 assertions，均零失败。
- `scripts/verify_release_contract.rb` 通过，App/CLI 为 `2.12.0-rc1742`，Xcode 六项配置与 build number `1742` 一致；`git diff --check` 通过。

## 限制

- 此变更只验证有可读取 ICC 色彩空间的 RGB 栅格输入；不代表 PSD 扁平导出、CMYK/灰度 PNG、EXIF 方向或所有图像格式均已覆盖。
- 本版不运行 rc1760 全量构建、真实 UI 冒烟或 `/Applications` 覆盖安装，不推送或打 tag。
