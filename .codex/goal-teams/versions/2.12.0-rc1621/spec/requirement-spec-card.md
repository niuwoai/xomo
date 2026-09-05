# Requirement Spec Card

- 用户问题：还原 Figma 属性时，非文本默认值可能被错误写进文本后代。
- 目标：将属性恢复与文本绑定分开；只有明确 TEXT→TEXT 才同步可见文案。
- 不变量：完整 imported default、Undo/Redo、History、锁和 Custom 语义不变。
- 非目标：新增控件、组件结构同步、instance swap 或网络导入。
