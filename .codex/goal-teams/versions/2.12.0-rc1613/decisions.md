# 2.12.0-rc1613 Decisions

- Crop 家族统一复用 rc1612 的 `ImageEditorSlice.offsetForCanvasResize`；不复制几何算法，也不因 helper 名称做重构。
- 最终提交的整数裁剪框决定 `targetSize`，Slice 使用 `(-bounded.minX, -bounded.minY)` 平移，只平移和裁切，不缩放。
- 所有输入 Slice 先以源画布整数可见交集校验 preset；存活 Slice 再以最终 frame 校验。合法删除不能绕过源损坏检查。
- 部分越界裁切，完全越界或边界相切合法移除；存活项的顺序、UUID、名称、preset 字段和值及 nil/显式空数组形态保持。
- 成功后协调 Slice scope 和主 preset 投影；非 Slice scope 不变。Undo/Redo 延续“恢复文档后协调当前外部选择”的既有边界。
- Slice 不参与透明边缘 Trim 的 alpha bounds；图层级 Trim 不变换 Slice。
- Reveal All、Rotate/Flip、项目 schema、UI、Automation payload 与通用 Undo 架构均不在 rc1613。
