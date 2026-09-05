# Test Plan

- ViewModel：依次写入首尾空白、纯空白、空字符串，断言属性与匹配后代逐字符一致，纯空白名称使用兜底。
- ViewModel：非 TEXT 带首尾空白时保存 trim 结果；纯空白输入严格 no-op。
- ViewModel：TEXT 相同值与非 TEXT 空值不改变属性、Undo/Redo 或 History；Undo/Redo 恢复属性与正文。
- Automation：`set` 带首尾空白的 TEXT，响应快照和文档均保留原值。
- 回归：串行运行 Figma provenance、Automation、cursor、CLI/MCP、发布契约与隔离运行器契约。
