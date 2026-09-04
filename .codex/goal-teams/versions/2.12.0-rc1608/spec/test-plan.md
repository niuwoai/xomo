# Test Plan

## 直接命令

- 表驱动验证旧 `100×80` 扩到 `140×120` 时九个锚点的平移矩阵，热点宽高与元数据不变。
- 中心锚点缩到 `60×40`，同时覆盖完整保留、部分裁切、边界相切删除、存活顺序与选中回退。
- 预置 Redo，验证成功操作只加一个 Undo、清空 Redo、追加一条历史，Undo/Redo 文档快照精确往返。
- 验证相同/过小/NaN 目标及 NaN、Infinity、零面积、溢出热点均无部分写入。

## Automation

新增独立 `XomoAutomationHotspotCanvasResizeTests.swift`，调用 `xomo.canvas.resize_canvas` 后通过 `xomo.hotspot.list` 验证同一共享入口，不扩充巨型综合测试文件。

## 相邻回归

- rc1607 Image Size 热点缩放。
- 热点 HTML exporter。
- 项目热点 round-trip。
- 组件库系统箭头 cursor。
