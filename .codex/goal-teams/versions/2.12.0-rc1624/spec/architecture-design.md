# Architecture Design

- 在 `XomoFigmaComponentProperty` 模型旁增加非 Codable 的纯诊断类型与写入解析结果。
- 诊断统一给出 editor kind、issue code、稳定 selection key 与候选结构有效性。
- `ImageEditorViewModel.updateSelectedFigmaComponentProperty` 委托共享解析，继续映射现有 changed/unchanged/invalid/locked/notFound。
- Inspector 只消费诊断，不自行重写候选规则；无稳定控件时显示原始值与本地化原因。
- Automation `list` 在每项追加诊断对象，既有字段不删不改；`set` 仍走 ViewModel。
- 不接入 paste validator，避免扩大 rc1620 的剪贴板兼容合同。
