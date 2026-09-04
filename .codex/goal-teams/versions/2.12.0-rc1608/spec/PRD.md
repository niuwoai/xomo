# PRD

## 范围

为 `resizeCanvas(to:anchor:)` 增加热点坐标空间变换，Automation 继续复用既有 `xomo.canvas.resize_canvas` 入口。

## 验收标准

1. 九个锚点都使用现有 anchor factor 公式，热点不缩放。
2. 扩大画布正确平移；缩小画布正确保留、裁切或移除热点。
3. 存活热点身份、文本、URL 与顺序不变。
4. 选中热点被移除后不留下悬空 ID，面板显隐不变。
5. 任何非法热点几何都在 `pushUndo()` 前拒绝，文档、Undo、Redo、历史和 UI 状态均无部分变化。
6. 成功命令只建立一个 Undo 事务，并由 Undo/Redo 精确往返文档。
7. 直接调用与 Automation 调用得到相同结果。

## 不在本版本

Slice、Crop、Reveal All、Rotate、schema、UI、Automation payload、Release 构建和 `/Applications` 安装。
