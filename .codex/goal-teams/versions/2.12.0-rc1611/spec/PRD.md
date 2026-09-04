# rc1611 PRD

## 目标

让既有 Image Size 命令在保持图层、热点、选区、通道与参考线行为不变的同时，同步缩放全部 Slice，并刷新选中 Slice 的导出投影。

## 验收标准

1. 非对称画布非等比缩放后，正/负尺寸小数 Slice 得到精确预期 frame；部分越界裁切，完全越界失败。
2. Slice 数量、顺序、UUID、原始名称和完整 preset 数组不变。
3. scale/width/height 三类 preset 值保持，目标 resolved scale 正确；任何源或目标无效 preset 使整次操作在 Undo 前失败。
4. Slice scope 的有效、nil、stale、空列表选择均按规格协调；非 Slice scope 不受影响。
5. 成功只新增一个 Undo 和既有 Image Resize History，清空 Redo；Undo/Redo 恢复文档并重新投影正确的导出倍率。
6. Automation 的 `resize_image → slice.list` 证明共享业务入口，不修改协议。

## 发布边界

rc1611 是 Slice Image Size 专属增量，不宣称其它 Canvas Transform 已支持 Slice。下一次完整构建、全量冒烟和 `/Applications` 覆盖门禁仍为 rc1640。
