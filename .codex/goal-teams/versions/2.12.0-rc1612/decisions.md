# 2.12.0-rc1612 Decisions

- Slice 使用与图层、Hotspot 完全相同的九宫格 offset，只平移，不缩放。
- 源 frame 以 `standardized.integral.intersection(sourceCanvasBounds)` 校验可见性与 preset；几何平移仍使用完整、未裁切的浮点标准化四边。
- 平移后只做一次 `integral` 再与目标画布求交；部分越界裁切，完全越界或边界相切合法移除。
- helper 返回 Optional：`nil` 只代表合法移除；损坏几何、非法 preset、源或目标倍率不可解析必须抛错，使整次命令在 Undo 前失败。
- 合法移除的 Slice 仍须通过源 preset 校验，但因没有目标 frame 不做目标 preset 校验。
- 存活 Slice 只替换 frame，保持顺序、UUID、名称及 `exportPresets` 的 nil/显式空和值；不调用 `normalized`。
- 成功后强制协调 Slice scope；非 Slice scope 的 Export Settings 完全不变。Undo/Redo 延续现有文档恢复后重新投影语义，不扩展 UI 历史快照。
