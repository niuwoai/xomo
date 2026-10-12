# rc1832：Cube LUT 调整层端到端验收

- 基线：`main` / `5b97f7b2577c19d689d26bdb1fcd469702fbe1dc`（rc1831）
- 版本：`2.12.0-rc1832`，build `1832`
- 范围：仅增加 LUT 工作流回归与版本记录；生产算法不变。

## 场景与结果

透明画布上的半透明彩色像素经用户导入的 3D `.cube` LUT 新建非破坏性调整层，然后保存项目、重开并导出 PNG。重开后的合成样本颜色与 alpha 均符合 LUT 结果，导出 PNG 以原始 RGBA 字节与重开画布逐像素一致，导出前后 History 不变。

最初用 `NSColor.usingColorSpace(.deviceRGB)` 直接比较导出 PNG 与画布，发现约 0.067 的通道偏移；这条比较跨越导出 sRGB 与 device RGB 色彩空间，测到的是颜色转换而非原始文件像素。改用仓库已有 `imageEditorRGBABytes` 对两个 `CGImage` 统一读取后，逐像素对比通过；没有据此修改或放宽产品颜色行为。

## 验证

- `ruby scripts/run_tests_isolated.rb --filter Cube --group-by-suite`：9/9 项通过，包含半透明 LUT 调整层保存、重开和 PNG 导出闭环。
- 发布合同：10 runs / 30 assertions；CLI 合同：7 runs / 24 assertions；隔离测试器合同通过；`git diff --check` 通过。
- 测试构建 `build-for-testing` 完成，使用 `/private/tmp/veilpic-build.lock` 串行运行。
- 本版仅增加集成测试，不改生产算法。未运行全量 Release、GUI 冒烟或安装；`/Applications/Xomo.app` 不变，rc1840 仍为下一完整质量门槛。
