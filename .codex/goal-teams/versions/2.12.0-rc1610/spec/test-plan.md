# rc1610 Test Plan

## 新测试

- `ImageEditorHotspotOrthogonalTransformTests.swift`：模型几何、五个直接命令、元数据与顺序、选择、Undo/Redo、损坏输入原子拒绝。
- `XomoAutomationHotspotOrthogonalTransformTests.swift`：五个 `xomo.canvas.transform` action 后通过 `xomo.hotspot.list` 验证真实共享入口。

固定 `100 × 80` 非对称画布，主热点使用负尺寸小数 frame `(30.75, 24.25, -12.5, -8.5)`，分别期待：CW `(55,18,10,13)`、CCW `(15,69,10,13)`、180 `(69,55,13,10)`、水平 `(69,15,13,10)`、垂直 `(18,55,13,10)`。另以整数热点 `(70,50,12,8)` 充当顺序和身份哨兵。

## 原子失败矩阵

覆盖零/负/NaN/无穷源画布，零面积/NaN/无穷 frame，源画布外热点及有限数求和溢出。五个命令都必须保持 document、Undo、Redo、history、选择和面板状态，只更新失败状态文本。

## 相邻回归

- 整套 `ImageEditorCanvasCommandTests`
- rc1607/1608/1609 三套 Automation 热点回归
- 新 Automation 正交变换套件
- Hotspot HTML exporter 与项目文档 round-trip
- Canvas cursor 的组件库箭头与交互模式测试
- CLI/MCP 单测与静态 release contract

rc1610 不运行 rc1640 才要求的完整 Release、全项目冒烟或 `/Applications` 覆盖。
