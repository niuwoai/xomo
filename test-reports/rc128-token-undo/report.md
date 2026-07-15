# rc128 本地设计 Token Undo/Redo 回归报告

- 日期：2026-07-16
- 版本：`v2.12.0-rc128`
- `XomoLeftSidebarTests`：41/41 通过
- `ImageEditorHistoryTests`：5/5 通过

## 覆盖内容

- 导入本地 `.xomotokens.json` 进入历史记录，并可用 Undo 恢复无映射状态。
- Redo 恢复导入的 Token 快照；清除 Token 后也可 Undo/Redo。
- 主题切换、组件主题应用与现有图层历史共用同一撤销栈。
- 普通历史快照、历史跳转、裁切和快捷键回归保持通过。
