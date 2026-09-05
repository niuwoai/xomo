# Test Plan

- 单项：TEXT→VARIANT，属性完整恢复，匹配后代整层编码不变，Undo/Redo 正确。
- 批量：TEXT→TEXT 异值传播；TEXT→非 TEXT、非 TEXT→TEXT、TEXT 同值 metadata-only 不传播；Custom 保留。
- 锁定匹配后代不变；整批只有一个 Undo 和一条 History；第二次 resetAll 严格 no-op。
- 复跑 Figma provenance、Automation、cursor、CLI/MCP 与发布/隔离运行器契约。
