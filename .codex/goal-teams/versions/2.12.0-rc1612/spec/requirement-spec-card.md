# rc1612 Requirement Specification Card

## 用户价值

调整 Canvas Size 后，Fireworks 风格 Slice 继续标记原画布内容：扩大时随锚点移动，缩小时保留可见交集，完全移出时合法删除，同时不静默改写多规格导出意图。

## 几何契约

`offset = (targetSize - sourceSize) × (anchor.horizontalFactor, anchor.verticalFactor)`，沿用现有九宫格因子。Slice 只平移，不缩放。

- raw frame 必须有限；负宽高先标准化，源画布整数可见交集必须为正面积。
- 使用完整浮点标准化四边加 offset，最后只做一次 `.integral` 并与目标画布求交。
- 部分越界裁切；完全越界、边界相切或空交集合法移除。源画布完全不可见则是损坏输入，整单失败。
- 存活 Slice 的顺序、UUID、名称、preset 顺序/字段以及 nil/显式空数组形态逐值保持。

## preset 与选择

- 每个输入 Slice 都在源有效 frame 上验证 preset 数量、格式、值及 `resolvedScale`；存活 Slice 还须在目标最终 frame 上再次验证。
- `.scale/.width/.height` 的 value 均保持。目标裁切导致倍率越界时整次 Canvas Size 原子拒绝；合法删除不能绕过源校验。
- Slice scope 下，存活选择保持；已删除、nil 或 stale 回退首个存活 Slice；无 Slice 回退 composited。主 preset 用最终 frame 重新投影，无 preset 只清 suffix；非 Slice scope 完全不变。

## 事务与范围

成功仅一个 Undo、一条 Canvas Resize History，并清空 Redo；失败除状态文案外不改变文档、历史、导出设置、面板、锚点、画布偏移或尺寸控件。rc1612 不处理 Crop/Reveal、Rotate/Flip、schema、UI、Automation payload 或 Release。
