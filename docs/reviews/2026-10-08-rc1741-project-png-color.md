# rc1741：P3 PSD 图层项目保存恢复色彩

## 范围与基线

- 基于 rc1740 本地 `main`，起始 HEAD 为 `679a1f664a60aeaab30635f0b274541fc8ec18cc`。
- 修复 PSD ICC 转换把 sRGB 像素标记为设备相关 RGB 的问题；项目 JSON 使用既有 `qingtuPNGData()` 编码路径后，恢复图层会重新解释设备色彩，导致颜色数值漂移。
- 增加真实项目数据链测试：P3 PSD 导入→项目 raster PNG 编码→项目 JSON 编码/解码→图层恢复；恢复图像的 sRGB RGBA 每通道与导入前误差不超过 1/255。生产 PNG 编码实现没有改动。

## 验证证据

- P3 PSD 导入→项目 PNG/JSON→恢复测试：1/1 通过，报告 `/tmp/veilpic-rc1741-color-rerun/report.md`。
- rc1741 提交后补跑完整 `ImageEditorPSDTests`：65/65 通过，报告 `/tmp/veilpic-rc1741-psd-suite/report.md`；覆盖 PSD 像素、透明度、ICC、通道、图层与往返相关用例。
- release contract：10 runs/30 assertions；CLI release build contract：7 runs/24 assertions；产品概览归档合同：3 runs/26 assertions；均零失败。
- `scripts/verify_release_contract.rb` 通过，确认 App/CLI `2.12.0-rc1741`、Xcode 六项配置、build number `1741` 及发布合同全部匹配；`git diff --check` 通过。

## 限制与后续

- 这一修复针对项目内部栅格编码；不代表普通 PNG 导入、扁平 PSD/PNG 导出、其他 ICC profile 或显示器渲染均已端到端色彩一致。
- 下一完整构建、全量测试、真实 UI 冒烟和可恢复安装门槛仍为 rc1760；本版不覆盖 `/Applications`，不推送或打 tag。
