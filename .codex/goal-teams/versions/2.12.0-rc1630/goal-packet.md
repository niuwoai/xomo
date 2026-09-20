# Goal Packet

- 版本：`2.12.0-rc1630`，构建号 `1630`。
- 目标：让 Figma 响应式尺寸约束 Inspector 明确显示当前字段来自导入默认值、本地覆盖或仅本地字段。
- 四态：无 imported defaults 且当前字段为空 → Unset；无 defaults 且当前字段有值 → Local only；有 defaults 且字段当前值与默认相等 → Imported default；有 defaults 且字段不同 → Overridden。
- 非目标：修改项目格式、Codable、导入、Automation/MCP payload、写入/还原语义、History/Undo/Redo、cursor、大型主组件同步。
- 测试：Figma provenance 测试恰好新增 1 项，33 → 34；Automation 323、Localization 46、Cursor 128、CLI/MCP 2 保持。
- 门禁：本版不是 rc1640，不执行 Release 或 `/Applications` 覆盖。
