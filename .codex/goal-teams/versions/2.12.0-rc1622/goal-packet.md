# Goal Packet

- 版本：`2.12.0-rc1622`
- 目标：让 Figma TEXT 组件属性把首尾空白、纯空白和空字符串视为设计内容并逐字符保留。
- 成功标准：TEXT 原样保存与传播；非 TEXT 继续 trim；真实变化保持单次 Undo/History；动态测试通过。
- 禁区：不改 UI 结构、项目 schema、Automation/CLI schema、cursor、reset/paste 类型规则或组件 identity。
- 停止条件：修复需要破坏非 TEXT 既有归一化，或出现无法串行的外部构建。
