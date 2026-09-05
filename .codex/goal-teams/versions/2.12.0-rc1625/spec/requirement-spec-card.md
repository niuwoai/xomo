# Requirement Specification Card

## 用户价值

大型 Figma 组件包含很多属性时，用户可直接看到问题总量与真正阻塞的数量，并只查看需要处理的属性；Automation 客户端获得相同口径。

## 核心功能

- Inspector 显示问题数与阻塞数，并提供“仅显示有问题”开关。
- 问题筛选与现有仅覆盖筛选取交集，稳定排序。
- Automation 根响应新增 `diagnosticCount`、`blockedCount`。

## 边界

- 统计复用 rc1624 diagnosis，不新增第二套判断。
- 图层锁不进入 blocked；非规范 Boolean、孤儿与歧义值属于可修复 warning。
- 不持久化筛选，不改项目格式、动作集合、paste/cursor 或网络能力。
