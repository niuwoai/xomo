# Goal Packet

- 版本：`2.12.0-rc1629`，构建号 `1629`。
- 目标：让 Figma 组件属性 Inspector 明确显示当前值来自导入默认值、本地覆盖还是仅本地属性。
- 三态：有 baseline 且完整对象相等 → Imported default；有 baseline 且完整对象不同 → Overridden；无 baseline → Local only。
- 覆盖判定必须复用现有 ViewModel 完整对象规则，包含 type、value、preferredValues。
- 非目标：修改 Codable、项目格式、导入、写入/reset、Automation/MCP、剪贴板、搜索谓词、诊断、History/Undo、cursor。
- 测试：Figma provenance 恰好新增 1 项，32 → 33；其他目标保持 Automation 323、Localization 46、Cursor 128、CLI/MCP 2。
- 门禁：本版不是 rc1640，不执行 Release 或 `/Applications` 覆盖。
