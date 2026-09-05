# Goal Packet

- 版本：`2.12.0-rc1621`
- 目标：修复 Figma 组件属性单项/批量还原在跨类型默认值下误写文本后代的问题。
- 成功标准：仅 TEXT→TEXT 且 value 改变时传播；属性仍完整还原；单次 Undo/History；动态测试通过。
- 禁区：不改项目 schema、UI、Automation/CLI schema、cursor、组件 identity/swap/detach。
- 停止条件：修复必须改变既有合法 TEXT 排序消费，或出现无法串行的外部构建。
