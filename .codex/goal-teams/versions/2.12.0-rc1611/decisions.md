# 2.12.0-rc1611 Decisions

- Slice 是 Fireworks 风格交付元数据；Image Size 改变像素坐标域时必须与图层、选区、参考线和热点一起缩放。
- 本版只处理 Image Size，Canvas Size、Crop/Reveal 与 Rotate/Flip 后置，避免扩大单版本回归面。
- 不新增 schema、UI 或 Automation payload；`xomo.canvas.resize_image` 复用 ViewModel 共同入口。
- 导出预设、选中 Slice 与损坏几何的精确语义由独立需求、架构和测试分析冻结后再实现。
- 部分越界历史 Slice 按现有 Hotspot Image Size 语义裁到画布有效区域；完全越界、空交集或非法几何整次失败，不允许删除 Slice。
- `.scale/.width/.height` preset 的 value、顺序与 Optional 形态均原样保留；源有效 frame 与目标最终 frame 上任一 preset 不可解析时原子拒绝，不产生半可用交付状态。
- Slice scope 的有效选择保持；nil/stale 回退首项，无 Slice 时回退 composited。非 Slice scope 的导出设置完全不动。
