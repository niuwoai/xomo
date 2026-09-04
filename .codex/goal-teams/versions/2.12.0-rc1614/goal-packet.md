# 2.12.0-rc1614 Goal Packet

- 目标：Reveal All 扩画布时同步保留并平移 Fireworks 风格 Slice，让历史越界交付区域在新画布中正确显露。
- 允许：Reveal All 的 Slice 原子接线、直接与 Automation 单测、版本和文档。
- 禁止：Slice 参与 bounds、静默删除、Rotate/Flip、schema、UI、Automation payload、通用 Undo 重构、Release/安装。
- 成功标准：几何、preset、scope、不丢数据、事务、Undo/Redo 与 Automation 均有动态证据，独立复核和 Git 闭环通过。
