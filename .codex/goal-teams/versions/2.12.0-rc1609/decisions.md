# 2.12.0-rc1609 Decisions

- Crop、Crop to Selection 与 Trim 共享“平移后裁到目标画布，完全越界移除”的热点语义。
- Reveal All 的新画布仍只由可见图层决定；热点随现有内容偏移平移，不参与反向扩大画布。Reveal 是非破坏操作，热点 helper 若返回 `nil` 也应整次拒绝，不能静默删除。
- 存活热点保持身份、名称、URL 与相对顺序；选择态始终修复为有效 ID 或 nil。
- 所有热点变换在 `pushUndo()` 前预计算，损坏几何整次拒绝。
- Rotate/Flip、Slice 和 schema 变化留到后续小版本。
