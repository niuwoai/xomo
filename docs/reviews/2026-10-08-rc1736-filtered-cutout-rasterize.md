# rc1736：滤镜后裁切遮罩栅格化保真

## 范围与基线

- 基于本地 `main`：`b56057cb`（rc1735）；对应 `origin/main` 为 `a88f0535`。工作分支：`codex/filtered-cutout-transform-composite-rc1736`。
- 不推送远端、不打标签、不覆盖 `/Applications`。本版不是四十版本完整门槛；安装版本仍记录为 rc1729，下一完整门槛为 rc1760。
- 问题来自真实图层路径：保存重开带 Gaussian Blur 的选区裁切后，栅格化源图层会改变复合像素。4×4 源像素、12×12 post-filter 裁切遮罩的定向回归在修复前失败。

## 修复

`ImageEditorRasterize` 在烘焙 post-filter 裁切遮罩时，现复用 `highResolutionMaskRenderingLayer()` 提升后的滤镜内容和裁切遮罩网格。输出像素图保留提升后的分辨率，栅格化后的画布合成与栅格化前逐字节相同；普通栅格蒙版不并入内容，仍可单独编辑。向量蒙版沿用提升副本的局部坐标补偿，再由既有路径栅格化流程处理。

回归同时检查：项目重开后栅格化、画布 RGBA 不变、普通蒙版尺寸与像素保留、滤镜/后滤镜遮罩被烘焙、撤销恢复原滤镜和遮罩、重做及栅格化项目重开均保留结果。遮罩缩放/旋转继续单独验证几何尺寸与撤销/重做，不将非破坏性与已栅格化图层在二次插值后的像素错误地要求完全一致。

## 验证证据

- 先改进回归断言后，修复前 RED：定向像素保真断言失败；旧实现将 12×12 遮罩按 4×4 源内容直接烘焙，复合结果不相等。
- 修复后定向回归：1/1 执行组通过，失败 0。
- `ImageEditorSelectionCutSamplingTests`：19/19 测试通过，失败/跳过 0。
- `scripts/test_release_contract.rb`：10 runs、30 assertions，0 failures/errors/skips。
- `scripts/test_xomo_cli_release_build.rb`：7 runs、24 assertions，0 failures/errors/skips。
- 测试均由仓库隔离测试运行器执行；每次 Xcode 测试持有 `/private/tmp/veilpic-build.lock`，没有并行构建。

## 未覆盖与集成状态

- 本版仅做定向 Debug 回归，不等同全量 Release 编译、完整回归、可见界面冒烟或安装验收。
- 本回归覆盖普通栅格蒙版；与高密度裁切遮罩同时存在的未链接/复杂矢量蒙版组合仍需更直接的像素验收。
- 完成分支提交后合入本地 `main`；不推送、不创建标签，不替换当前安装版。
