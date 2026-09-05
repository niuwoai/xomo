# Requirement Spec Card

- 用户问题：Figma TEXT 组件属性当前被统一 trim，导致有意义的首尾空白和纯空白丢失。
- 目标：TEXT 原样保存并传播；非 TEXT 保持既有 trim 与空值 no-op。
- 不变量：精确旧值匹配、图层名称摘要、默认快照、锁、Undo/Redo、History 与 Automation 共享路径。
- 非目标：多行编辑器、项目格式、preferredValues 校验、组件结构同步或网络导入。
