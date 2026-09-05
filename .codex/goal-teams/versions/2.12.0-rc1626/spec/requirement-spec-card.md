# Requirement Specification Card

## 用户价值

大型 Figma 组件包含很多属性时，用户可在 Inspector 内按属性 key 或当前值快速缩小列表，不必逐行寻找目标属性。

## 核心功能

- Inspector 为当前选中图层的 Figma 组件属性提供本地搜索输入。
- 搜索对属性 key 与当前保存值 `property.value` 做包含匹配。
- 查询忽略大小写、首尾空白与变音符号；清空或只输入空白等同于不搜索。
- 搜索与“仅看已覆盖”“仅显示有问题”分别取逻辑与，最终结果仍按 key 稳定排序。
- 搜索无结果时显示本地化空态；输入和空态提供稳定 accessibility identifier。

## 边界

- “当前值”仅指属性模型当前保存的原始 `property.value`，不扩展匹配属性类型、诊断文案、候选值列表或候选值显示名。
- 搜索只改变 Inspector 当前列表的可见行，不改变属性集合、计数、复制/粘贴/还原语义或 Automation 响应。
- 查询是 Inspector 视图内的瞬时状态，不写项目、不触发 dirty state，不进入 History/Undo/Redo，也不成为用户设置。
- 文本输入获得焦点时，正常键入必须留在搜索框内，不能误触画布工具快捷键。
- 不改 Figma 导入协议、项目 schema、组件库选择状态或 cursor。
