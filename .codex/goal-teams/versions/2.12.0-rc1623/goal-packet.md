# Goal Packet

- 版本：`2.12.0-rc1623`
- 目标：阻止 Figma 枚举组件属性产生新的不可表示状态，同时只读兼容旧项目孤儿值。
- 成功标准：共享结构化结果；候选 key/name 安全解析；非法写入零副作用；Automation 明确失败；动态测试通过。
- 禁区：不迁移项目、不改 pasteOverrides、项目 schema、真实 instance swap、cursor 或 rc1622 TEXT 保真。
- 停止条件：修复要求改写旧值或破坏无候选枚举兼容。
