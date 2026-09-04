# Architecture Design：Image Size 热点原子变换

## 设计

- `ImageEditorHotspot` 提供纯函数式 `scaledForImageSize`，只变换 frame，不修剪名称或 URL。
- 先验证源 frame 与比例均有限且有正面积；缩放标准化 frame 的四边，再做一次 `integral` 与目标画布裁边。
- `resizeImage(to:)` 在 `pushUndo()` 前用普通 `map` + 全量成功门禁预计算热点；禁止 `compactMap` 静默丢项。
- 计算成功后，在 canvas、layers、guides、selection、channels 的同一事务中整体赋值 `document.hotspots`。

## 不变量

- 合法热点不会被删除，因此 `selectedHotspotID` 与面板状态无需额外协调，也不进入项目 schema。
- Undo/Redo 继续交换完整 `ImageEditorDocument`；History 继续使用既有 `imageResize` 标题。
- ProjectDocument formatVersion、Automation Registry、HTML exporter 和画布渲染消费者无需修改。

## 失败策略

任一源/结果坐标非有限、宽高非正或裁边后为空时，设置既有 `resizeInvalid` 状态并返回；不得 push Undo 或写入任何文档字段。
