# Architecture Design

## 纯几何 helper

在 `ImageEditorHotspot` 增加 `offsetForCanvasResize(offset:targetCanvasSize:) throws -> ImageEditorHotspot?`：

1. 验证 target、offset 和热点 frame 四分量均为有限值。
2. 标准化 source frame，并要求正面积。
3. 对 min/max 分别加 offset，再验证结果有限且仍为正面积。
4. 构造平移矩形，执行 `integral.intersection(canvasBounds)`。
5. 零面积交集返回 `nil`；正面积只替换原热点的 frame。

不得调用 `normalized(canvasSize:)`，避免顺带修改名称和 URL。

## 原子命令

`resizeCanvas` 在 `pushUndo()` 前完成热点 `compactMap`、图层和参考线预计算。非法几何 catch 后设置 `resizeInvalid` 并返回。成功时只 push 一次，然后写入文档各部分并修复 `selectedHotspotID`。

## 历史边界

热点属于 `ImageEditorDocument`，由现有 Undo/Redo 保存；`selectedHotspotID` 属于 ViewModel UI 状态，本版本只保证它在成功操作后不悬空，不扩大通用历史快照。
