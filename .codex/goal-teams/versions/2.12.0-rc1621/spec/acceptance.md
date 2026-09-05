# Acceptance

- 状态：complete
- 审查人：审查-rc1621独立复核
- 结论：最终 diff 未发现 P0/P1/P2，`git diff --check` PASS。
- 代码证据：单项与批量 reset 均要求 current/default 为 TEXT 且 value 改变才传播；属性仍完整恢复。
- 测试证据：单项跨类型和批量四象限用例均可击穿旧实现，并覆盖完整 layer、Undo/Redo、History、Custom、锁定后代及 no-op。
- 动态证据：Figma 24/24、Automation 320/320、cursor 128/128、CLI/MCP 2/2、发布契约 9/9（27 assertions）与隔离运行器契约全部通过。
- 发布边界：rc1621 非 40 版本门禁，不执行 Universal Release 或安装覆盖。
