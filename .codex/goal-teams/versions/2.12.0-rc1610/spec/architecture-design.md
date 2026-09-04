# rc1610 Architecture Design

## 模型层

- 在文档模型层新增非 Codable 的内部五态正交变换枚举，不进入 `ImageEditorDocument`，因此无 schema 迁移。
- 枚举负责验证源画布并唯一推导目标画布尺寸。
- `ImageEditorHotspot` 提供纯变换 helper：校验有限值、标准化源 frame、严格验证源边界、套用同构公式、最终一次整数化并验证目标边界。
- helper 复制热点后只替换 frame，不调用会清洗名称或 URL 的 `normalized`。

## ViewModel 单事务

共同 `transformCanvas` 入口接收显式正交操作，按以下顺序执行：

1. 预计算并验证目标画布。
2. 使用 `map` 全量预计算热点和选择修复结果。
3. 预计算所有图层并确认无失败。
4. 调用一次 `pushUndo()`。
5. 写入画布、图层、热点和选择，同步尺寸控件并追加既有历史。

任何预计算失败只设置操作失败状态并返回，不得提前修改文档、历史、Undo/Redo、选择、面板、尺寸控件或视口偏移。

## 兼容性

现有五个公开命令和 Automation 均继续调用同一 ViewModel 入口。Undo snapshot 已包含 `ImageEditorDocument.hotspots`，无需新增持久化字段；热点选择是 UI 状态，因 UUID 保持而在正常 Undo/Redo 中继续有效。
