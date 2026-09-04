# rc1611 Architecture Design

## 模型层

- `ImageEditorSlice` 新增独立纯缩放 helper，显式接收 X/Y 比例、源画布和目标画布。
- 校验 scale、画布、raw frame；标准化源 frame，计算源有效交集，缩放完整浮点四边，最终一次 integral 并裁到目标画布。
- 用源有效 frame 和目标最终 frame 校验全部 preset，但复制 Slice 时只替换 frame，绝不清洗其它字段。
- 不与 Hotspot 抽公共泛型，避免扩大 rc1611 回归面。

## 单事务接线

`resizeImage` 在 `pushUndo()` 前依次预计算全部 Slice、全部 Hotspot、图层、参考线及现有选区/通道结果。任一可抛校验失败只设置 `imageEditor.status.resizeInvalid` 并返回。

成功后一次性写入文档，随后强制协调 Slice scope：有效 ID 应用变换后的主 preset，nil/stale 回退首项，无 Slice 回退 composited；非 Slice scope 不修改 Export Settings。再清画布偏移、同步尺寸控件并追加既有 History。

Undo/Redo/History restore 已有 Slice history 同步入口，继续用恢复后的 frame 重新解析 preset，无 schema 改动。
