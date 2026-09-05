# Requirement Specification Card

## 核心目标

用户在 Figma 组件属性 Inspector 中可一键复制全部真实覆盖值，便于交付、审查和自动化。

## 业务流

1. 选中保留了 Figma 组件属性及导入默认的图层。
2. 存在覆盖时显示“复制覆盖值”。
3. 点击后将覆盖子集 JSON 写入剪贴板；锁定图层仍可执行。
4. Automation 可以同样触发，并获得完整诊断快照。

## 边界

- 不改 Copy All、项目文件、Undo/Redo、History 或 cursor。
- 无默认基线的 Custom 不假定为覆盖。
- 视图筛选不改变复制范围。
