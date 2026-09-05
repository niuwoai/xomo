# Goal Packet

- 版本：`2.12.0-rc1625`
- 目标：让大型 Figma 组件的属性问题可汇总、可筛选，并让 Automation 获得同口径健康统计。
- 成功标准：问题与阻塞分开计数；覆盖筛选和问题筛选取交集；UI 与 Automation 复用 rc1624 diagnosis。
- 允许范围：纯派生健康摘要、ViewModel 筛选、Inspector 摘要/筛选、Automation 根字段、i18n、测试、版本与文档。
- 禁止范围：项目 schema、偏好持久化、真实 INSTANCE_SWAP、Figma 网络、`pasteOverrides`、cursor。
- 门禁：独立评审；Figma 29、Automation 323、Localization 46、cursor 128、CLI/MCP 2、发布与隔离测试器契约。
