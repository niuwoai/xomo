# Requirement Specification Card

## 用户价值

Reveal All 显露画布外图层内容时，Fireworks 风格 Slice 与内容进入同一坐标系，历史越界交付区域可以重新显露，且非破坏操作不会静默丢失 Slice。

## 核心需求

- Reveal target 只由旧画布与可见可合成图层决定，Slice 不参与 bounds 或可用性。
- Slice 按 `(-revealRect.minX, -revealRect.minY)` 平移，不缩放；历史部分越界可重新显露。
- 所有输入校验源整数可见交集和 preset，全部结果再校验最终 target frame；完全源不可见或损坏输入原子拒绝。
- Reveal 不允许删除 Slice；数量、顺序、身份、名称、preset 字段和值及 nil/显式空数组保持。
- 成功后协调 valid/nil/stale/empty/no-preset Slice scope，非 Slice scope 不变。
- 单一 Undo、清 Redo、单条 Reveal All History；Undo/Redo 恢复文档并重新投影导出 preset。

## 边界

- 无画布外可合成图层时，即便有画布外 Slice 也不触发 Reveal。
- 不新增 UI、Automation action/payload 或项目 schema。
- Rotate/Flip 与更大架构改造后置。
