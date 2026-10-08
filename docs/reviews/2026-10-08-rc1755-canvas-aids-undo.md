# rc1755 画布辅助项与内容撤销边界

## 用户场景

编辑像素时临时隐藏标尺、参考线、选区边缘、变换控件或网格，或切换吸附选项，只是在调整画布观察/交互方式；这些操作不应占掉 Cmd-Z，也不应在撤销一次像素填充后恢复成先前的显示偏好。

## 实现

- 画布显示与吸附开关不再调用 `pushUndo()` 或 `appendHistory()`；参考线对象的增删/移动、锁定仍作为真实文档更改进入历史。
- Undo、Redo、命名历史快照与历史截断恢复文档内容时，保留当前画布视图设置。
- 项目文档仍保存这些偏好；本次不改变持久化格式。

## 验证

- `ImageEditorScopeTests`：196 项通过，包含像素填充后切换所有画布辅助项、PNG 像素不变、History/Undo 数不变，以及 Undo/Redo 后显示偏好保持的回归。
- `ImageEditorHistoryTests`：45 项通过。
- `ImageEditorGuideTests`：37 项通过。
- Release contract：10 runs / 30 assertions；CLI release build tests：7 runs / 24 assertions；产品概览归档合同：3 runs / 26 assertions；均通过。
- `git diff --check` 与 `scripts/verify_release_contract.rb` 通过。

## 范围与未验证

定向 Debug 测试的 build-for-testing 与 278 项目标测试通过。本次不是 rc1760 四十版本完整构建门槛；未执行全量项目回归、真实 GUI/鼠标冒烟或 `/Applications` 安装。没有公开发布或推送。
