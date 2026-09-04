# 2.12.0-rc1607 Goal Teams 计划

## 目标

让 Fireworks 风格热点成为 Image Size 的完整参与者，随图像像素内容非等比缩放并保持一次可撤销事务。

## 成员

| 成员 | 任务 | 锁定范围 | 交付 | 验收 |
| --- | --- | --- | --- | --- |
| 需求分析-热点图像缩放 | 需求、不变量、失败边界 | 只读 | 规格卡 | Goal Lead |
| 架构-热点图像缩放 | 事务顺序与项目边界 | 只读 | Architecture Design 建议 | Goal Lead |
| 测试-热点图像缩放 | 行为与相邻矩阵 | 只读 | Test Plan 建议 | Goal Lead |
| 开发-热点图像缩放 | 模型纯函数、ViewModel 接线、直接/Automation 测试 | Canvas Commands、Hotspot model、相关测试 | 最小实现 | QA + 评审 |

## 停止条件

- 需要修改项目 schema、Automation 协议或 Undo/Redo 核心。
- 需要定义 Canvas Size/Crop/Rotate 等另一类几何语义。
- 外部构建占用唯一构建槽时暂停动态测试。

本版不执行 Release/安装；下一完整门禁为 rc1640。
