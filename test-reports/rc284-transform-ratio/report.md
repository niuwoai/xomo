# rc284 变换锁定比例回归

- 生成时间：2026-07-18 18:48:00 +0800
- 总数：**3**，通过：**3**，失败：**0**
- 并行度（jobs）：1

✅ 精确定位、组件整体缩放和锁定宽高比均通过串行回归。

## 用例

| 用例 | 结果 |
|---|---|
| `transformInspectorMovesSelectedLayerWithUndoHistory` | 通过 |
| `transformInspectorResizesComponentChildrenAsOneObject` | 通过 |
| `transformInspectorCanPreserveSelectedLayerAspectRatio` | 通过 |
