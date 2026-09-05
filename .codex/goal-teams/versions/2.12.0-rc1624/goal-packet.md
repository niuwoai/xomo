# Goal Packet

- 版本：`2.12.0-rc1624`
- 目标：让 Figma 组件属性的合法、孤儿、歧义、损坏与未知状态由共享纯诊断器解释，并由 Inspector 与 Automation 一致呈现。
- 成功标准：损坏候选不构造不稳定 Picker；非规范 BOOLEAN 不伪装成正常 Toggle；旧值原样可读且不自动迁移；写入继续沿用 rc1623 语义。
- 允许范围：属性纯诊断、Inspector 行展示、Automation 追加字段、i18n、测试、版本与文档。
- 禁止范围：项目 schema、真实 INSTANCE_SWAP、Figma 网络、主组件同步、`pasteOverrides` 语义、cursor 行为。
- 门禁：独立评审；Figma provenance、Automation、cursor、CLI/MCP、发布与隔离测试器契约。
