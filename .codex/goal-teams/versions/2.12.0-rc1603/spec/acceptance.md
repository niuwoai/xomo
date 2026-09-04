# 2.12.0-rc1603 验收记录

状态：Git 闭环中

| 验收项 | Owner | 状态 | 证据 |
| --- | --- | --- | --- |
| 支持/拒绝矩阵 | 评审-Figma 语义边界 | passed | leaf PASS_THROUGH exact 域为空；Paint→layer 提升已取消 |
| mapper 实现 | 开发-Figma IMAGE Paint 诊断 | passed | IMAGE 分支复用 Paint 支持检查，不修改 schema/materializer |
| 新增测试有效性 | 测试-Figma 导入门禁 | passed | 新增 9/9、相邻 110/110，合计 119/119；失败/跳过/重试均为 0 |
| 版本与文档一致 | Goal Lead | passed | 版本契约 9/9（27 条断言）、发布结构、隔离运行器与 CLI/MCP 2/2 通过 |
| Git 与远端一致 | Goal Lead | pending | 待闭环 |
