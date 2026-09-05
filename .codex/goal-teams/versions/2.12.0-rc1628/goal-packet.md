# Goal Packet

- 版本：`2.12.0-rc1628`，构建号 `1628`。
- 目标：为 Figma 组件属性增加紧凑、可读、只读的类型徽标。
- 已知精确映射：`TEXT`、`BOOLEAN`、`VARIANT`、`INSTANCE_SWAP` 使用三语文案。
- 前向兼容：未知非空类型逐字显示；空或纯空白类型显示本地化未知类型；帮助文本保留完全原始 type。
- 搜索边界：仍仅搜索属性 key 与当前 value，类型、标签、诊断均不得参与。
- 非目标：Codable、写入、诊断、Automation/MCP、剪贴板、导入、项目、History/Undo、选择和 cursor。
- 完成条件：恰好新增 1 个 Figma provenance 测试；目标回归、发布契约与独立复审通过；提交、合并 main、tag 与推送均可验证。
- 门禁：本版不是 rc1640，不执行 Release 构建或 `/Applications` 覆盖。
