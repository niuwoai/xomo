# Requirement Spec Card

- 用户问题：Picker 和 Automation 可把未知、大小写错误或歧义字符串写入枚举属性。
- 目标：所有交互写入共享可审计结果，并只创建可由 Inspector 表示的新值。
- 不变量：TEXT 空白保真、旧项目只读兼容、锁、defaults、Undo/Redo、History 与 pasteOverrides 原子契约。
- 非目标：迁移旧项目、真实 instance swap、候选网络解析或项目 schema 变更。
