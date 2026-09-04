# 2.12.0-rc1609 Progress

- 2026-09-05：确认 rc1608 已闭环，main 与 origin/main 位于 `e1f4cc59a`，工作区干净。
- 2026-09-05：确认系统构建槽空闲，创建 `codex/hotspot-crop-reveal-rc1609`。
- 2026-09-05：冻结本轮为 Crop/Crop to Selection/Trim/Reveal All 热点坐标变换，Rotate/Flip 与 Slice 后置。
- 2026-09-05：需求、架构、测试三个只读角色完成分析；Goal Lead 裁决 Reveal All 为非破坏操作，任何热点意外消失均原子拒绝，而 Crop/Trim 允许合法越界删除。
- 2026-09-05：开发完成 Crop 共同漏斗、Reveal All 与统一选择修复接线；首次评审发现测试变量作用域 P1 和 Reveal 超限状态 P2，修复并补 Crop 全删选择测试后复审 PASS。
- 2026-09-05：唯一冷测试构建成功；Canvas Commands 25/25、三代热点 Automation 6/6、HTML 3/3、项目往返 1/1、组件库 cursor 1/1，合计 36/36，失败 0、跳过 0、基础设施重试 0。
- 2026-09-05：CLI/MCP 2/2、发布契约 9/9（27 断言）、隔离运行器契约和发布结构校验通过；本版不执行 Release 或 `/Applications` 覆盖。
