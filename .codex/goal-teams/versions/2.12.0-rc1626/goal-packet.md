# Goal Packet

- 版本：`2.12.0-rc1626`
- 目标：为大型 Figma 组件属性 Inspector 增加本地搜索，可按属性名称或当前值快速定位条目。
- 成功标准：搜索忽略大小写、首尾空白与变音符号；与覆盖/问题筛选取交集；结果稳定按 key 排序。
- 允许范围：ViewModel 纯派生过滤、Inspector 本地状态与三语文案、定向测试、版本和文档。
- 禁止范围：项目格式、History/Undo、Automation schema、剪贴板、导入协议、组件库选择与 cursor。
- 门禁：独立复审；Figma provenance 30、Automation 323、Localization 46、cursor 128、CLI/MCP 2、发布与隔离运行器契约。
- 发布边界：非 rc1640，不执行 Universal Release 或 `/Applications` 覆盖。
