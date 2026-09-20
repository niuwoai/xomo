# Test Plan

- Figma provenance 测试恰好从 33 增加到 34。
- 覆盖：defaults 存在且 nil/nil、数值相等、数值不同、defaults 缺失且当前为空/有值、defaults 为 `.empty`；每个字段独立判定。
- 断言来源 presentation 与三语资源、稳定 accessibility id、既有 override/reset 语义和读取无副作用。
- 静态合同：View 不比较 defaults；不改 Automation payload、Codable、搜索、History/Undo/Redo 或 cursor。
- 回归目标：Figma 34/34、Automation 323/323、Localization 46/46、Cursor 128/128、CLI/MCP 2/2。
