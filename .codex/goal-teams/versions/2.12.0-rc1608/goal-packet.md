# 2.12.0-rc1608 Goal Packet

- 目标：Canvas Size 按九宫格锚点平移热点，并把热点裁切到新画布范围。
- 允许：Hotspot 纯几何 helper、`resizeCanvas` 接线、直接与 Automation 单测、版本与文档。
- 禁止：Image Size/Crop/Rotate、Slice、schema、UI、Automation payload、HTML exporter、cursor、Release/安装。
- 必测：九锚点代表矩阵、扩大与缩小、部分裁切、完全越界移除、完整 Undo/Redo、Automation 共用入口、HTML/项目/cursor 相邻回归。
- 下一完整门禁：2.12.0-rc1640。
