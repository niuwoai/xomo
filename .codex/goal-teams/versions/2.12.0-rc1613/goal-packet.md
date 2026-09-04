# 2.12.0-rc1613 Goal Packet

- 目标：让 Fireworks 风格 Slice 在所有缩画布 Crop 与 Canvas Trim 入口中保持正确交付区域和可用导出 preset。
- 允许：共同 `crop` 漏斗接线、直接与 Automation 单测、版本和文档。
- 禁止：图层 Trim 行为变更、Reveal、Rotate/Flip、schema、UI、Automation payload、通用 Undo 重构、Release/安装。
- 成功标准：几何、preset、scope、事务和历史契约均由真实命令测试证明，独立评审通过，Git 闭环。
- 停止条件：共享高风险架构歧义、不可复用现有 helper、动态构建受外部并发污染且无法串行重试。
