# rc1759 P3→PDF 编辑工作流验证

## 范围

将已有 P3 PNG 像素编辑任务延伸到 PDF：导入 8×8 Display P3 图像，在 2×2 选区上执行像素移动、Undo/Redo、项目重开，再导出 PNG 和 PDF。验证 PDF 页面尺寸、读回像素、History 和选中图层状态。

## 发现与修正

首轮逐字节比较失败并非文档内容损坏：直接将 PDF 页面绘制到 bitmap context 时，PDF 的底部原点与图像像素数组的 top-left 行序相反。诊断读回确认移动后的红色像素/透明区域在纵向对应位置互换；颜色转换另有 1 级通道舍入差。测试栅格化 PDF 页面前显式翻转 Y 轴，并对颜色转换采用每通道最大 1 的容差。生产导出实现未修改。

## 实际验证

- `p3PNGOpenSelectionMoveUndoRedoProjectReloadAndPNGAndPDFExportsStayConsistent`：1/1 通过；使用 `scripts/run_tests_isolated.rb --filter ...`，结果目录 `/private/tmp/veilpic-rc1759-p3-pdf-coordinate-fix`。
- PNG 导出 sRGB profile、8×8 尺寸及 RGBA 与重开文档画布逐字节一致。
- PDF 媒体框为 8×8；校正页面坐标后，所有 RGBA 通道与重开画布最大差异不超过 1。
- 导出前后内容 History 与选中图层 ID 不变。
- `scripts/test_release_contract.rb`：10 runs / 30 assertions，通过。
- `scripts/test_xomo_cli_release_build.rb`：7 runs / 24 assertions，通过。
- `scripts/test_product_overview_archive.rb`：3 runs / 26 assertions，通过。
- `scripts/verify_release_contract.rb`：`passed: true`，App、CLI、Xcode 项目版本均为 `2.12.0-rc1759`，Build 为 `1759`。
- `git diff --check`：通过。

## 未覆盖

本次没有运行全项目构建/全量测试、GUI 冒烟或 `/Applications` 安装；这些属于 rc1760 四十版本门槛。PDF 验收使用 Core Graphics 读回，尚未验证 Acrobat、Preview 等外部应用的显示结果。此测试证明该 P3 编辑样本的 PDF 栅格内容与画布一致，不代表所有色彩配置、PDF 特性或透明度组合都已验证。
