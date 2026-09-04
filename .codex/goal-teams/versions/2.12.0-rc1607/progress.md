# 2.12.0-rc1607 Goal Teams 进展

| 成员 | 任务 | 状态 | 当前证据 | 下一步 |
| --- | --- | --- | --- | --- |
| 需求分析-热点图像缩放 | GT-1607-01 | done | Image Size 缺少 hotspots，原子失败与身份不变量已冻结 | 开发 |
| 架构-热点图像缩放 | GT-1607-02 | done | 预计算后单次提交，无需 schema/Undo 核心改动 | 开发 |
| 测试-热点图像缩放 | GT-1607-03 | done | 非等比、完整快照、Automation 与相邻矩阵已冻结 | 开发 |
| 开发-热点图像缩放 | GT-1607-04 | done | 纯热点缩放 helper、Image Size 原子接线及直接/Automation 测试完成 | 独立评审与动态 QA |
| 评审-热点图像缩放 | GT-1607-04 | done | 非有限与乘法溢出测试补强后最终 PASS | Goal Lead 收口 |
| 测试-热点图像缩放动态验收 | GT-1607-04 | done | 最终冷构建成功；Canvas/Automation/HTML/项目/cursor 合计 16/16 | Goal Lead 收口 |
| Goal Lead | GT-1607-05 | running | 发布契约 9/9（27 断言）、运行器/结构契约及 CLI/MCP 2/2 通过 | 提交、标签、main、远端核验 |
