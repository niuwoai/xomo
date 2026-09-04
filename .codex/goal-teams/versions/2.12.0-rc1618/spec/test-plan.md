# Test Plan

- 构造 value 相同但 type/preferredValues 漂移的 metadata-only override，以及有默认普通属性和无默认 Custom。
- 逐次直接检查 list、set、reset、resetAll 的 action result，不只检查模型。
- 验证完整 importedDefault、兼容 defaultValue、显式 null、原顺序 preferredValues 与 counts。
- 回归：完整 XomoAutomationTests、Figma provenance、cursor、CLI/MCP、发布与隔离测试器契约。
