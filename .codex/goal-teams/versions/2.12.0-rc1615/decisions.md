# 2.12.0-rc1615 Decisions

- 五种画布正交变换是本版唯一功能面；Slice 使用与图层、Hotspot 同构的 CW、CCW、180°、水平及垂直公式。
- raw frame 仅标准化一次；源可见区以 `standardized.integral ∩ sourceBounds` 校验，完整浮点 frame 参与变换，目标只 `.integral` 一次再裁边。
- 历史部分越界 Slice 合法，完全源外或损坏数据原子拒绝；正交双射不得删除合法 Slice，使用非可选稳定 `map`。
- preset constraint/value 不因 90° 自动换轴；每个 preset 对源可见 frame 与目标最终 frame 双校验，元数据及 nil/显式空数组保持。
- 成功写回 Slice 后无条件协调 Slice scope；失败只报告现有 `operationFailed`，不得污染 Undo/Redo、文档或 UI 状态。
- 不新增界面、项目 schema 或 Automation payload；现有 `xomo.canvas.transform` 必须走同一业务入口。
