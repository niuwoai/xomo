# Requirement Specification Card

## 用户价值

裁剪画布或自动移除透明边缘后，Fireworks 风格 Slice 继续覆盖正确的可见内容，固定尺寸与倍率交付 preset 仍可真实导出，不留下旧坐标或悬空选择。

## 核心需求

- 普通 Crop、Crop Center、Crop to Selection 与 Canvas Trim Transparent 共用相同 Slice 投影。
- Slice 使用裁剪原点的反向 offset 平移，不缩放；部分越界裁切，完全越界或边界相切合法移除。
- 存活项只改 frame，身份、名称、顺序和全部 preset 元数据及 Optional 形态保持。
- 所有输入先校验源可见 frame 和 preset；存活项再校验目标最终 frame。任一损坏输入在 Undo 前拒绝整单。
- Slice scope 的存活选择保持，removed/nil/stale 回退首项，无 Slice 回退 composited；主 preset 按最终 frame 投影。
- 成功只有一个 Undo 和一条调用方既有 History；Undo/Redo 恢复 Slice 文档状态并重新协调导出投影。

## 边界

- Canvas Trim bounds 只由合成像素 alpha 决定，Slice 不参与扩大或缩小计算。
- Layer Trim 不改变 Slice。
- Reveal All、Rotate/Flip、UI、schema、Automation payload 和通用历史架构不在本版。
