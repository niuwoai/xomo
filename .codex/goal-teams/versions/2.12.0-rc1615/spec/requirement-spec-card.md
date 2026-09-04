# rc1615 Requirement Specification Card

状态：complete。

## 用户价值

画布旋转或翻转后，Fireworks 风格 Slice 仍覆盖对应视觉内容，并保持可直接交付。

## 边界

- 包含：顺/逆 90°、180°、水平/垂直翻转、preset、scope、Undo/Redo、Automation。
- 不包含：新增 UI、项目格式、响应式约束、任意角度旋转。

## 核心不变量

- 顺/逆 90°、180°、水平/垂直翻转使用与图层和 Hotspot 相同坐标定义；90° 交换画布宽高。
- 部分源越界 Slice 合法；完全源外、边界相切、非有限、零面积或溢出为损坏输入。
- 源端以整数可见交集校验 preset，完整浮点 frame 变换，目标一次整数化并裁切后再次校验 preset。
- 只改 frame；数量、顺序、ID、名称、preset 全字段及 nil/显式空数组保持。
- 成功只有一个 Undo 和一条既有 History，失败发生在 Undo 前；Slice scope 按最终 frame 协调。

## 用户流程

用户执行任一现有画布 Rotate/Flip 命令，Slice 与画布内容、Hotspot 同时变换；Automation 使用相同入口并可从 `xomo.slice.list` 读取结果。
