# 2.12.0-rc1608 Progress

- 2026-09-05：确认 main 与 origin/main 位于 rc1607 闭环提交，工作区干净。
- 2026-09-05：确认系统构建槽空闲，创建 `codex/hotspot-canvas-resize-rc1608`。
- 2026-09-05：冻结本轮为热点随 Canvas Size 锚定平移与裁切，不扩展到 Slice 或其它画布变换。
- 2026-09-05：需求、架构、测试三个只读角色独立完成分析；一致要求原子预计算、九锚点同源偏移、合法越界移除与损坏几何整次拒绝。
- 2026-09-05：开发完成热点纯几何 helper、Canvas Size 原子接线、九锚点与 Automation 测试；首次评审发现旧画布校验 P1 与 nil/stale 选择覆盖 P2，修复后复审 PASS。
- 2026-09-05：唯一冷测试构建成功；Canvas Commands 17/17、热点 Automation 2/2、HTML 3/3、项目往返 1/1、组件库 cursor 1/1，合计 24/24，失败 0、跳过 0、基础设施重试 0。
- 2026-09-05：CLI/MCP 2/2、发布契约 9/9（27 断言）、隔离运行器契约和发布结构校验通过；本版不执行 Release 或 `/Applications` 覆盖。
