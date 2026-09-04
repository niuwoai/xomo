# PRD

## 范围

让 `crop(to:)` 共同漏斗及 `revealAllLayers()` 同步处理热点；Automation 继续复用既有 `xomo.canvas.crop_to_selection` 与 `xomo.canvas.transform`。

## 验收标准

1. Direct Crop、Crop Center、Crop to Selection、Trim Transparent 使用同一热点裁剪语义。
2. Reveal All 只按图层确定目标 bounds，并完整平移全部合法热点。
3. Crop 合法删除越界热点；Reveal 不允许静默删除热点。
4. 存活热点身份、文本、URL 与顺序不变，选择态不悬空。
5. 所有热点在 `pushUndo()` 前预计算；损坏几何不改变文档、栈、历史、选择、面板、尺寸控件或 canvasOffset。
6. 成功命令只建立一个 Undo 事务，Undo/Redo 文档快照精确往返。
7. 直接调用与 Automation 调用得到相同结果。

## 不在本版本

Rotate/Flip、Slice、schema、UI、Automation payload、HTML exporter、cursor、Release 构建和 `/Applications` 安装。
