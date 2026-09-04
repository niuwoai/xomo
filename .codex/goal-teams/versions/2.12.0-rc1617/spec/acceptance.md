# Acceptance

独立静态评审最终 PASS，无未关闭 P0/P1/P2。评审提出的 metadata-only 夹具未覆盖 type 漂移这一项 P2 已修复：current 同时漂移 type 与 preferredValues，而 value 保持与 imported default 相同。

动态验收：

- 唯一冷 `build-for-testing`：成功。
- `ImageEditorFigmaProvenanceTests`：18/18。
- `XomoAutomationTests`：319/319。
- `ImageEditorCanvasCursorTests`：128/128。
- Xomo CLI/MCP：2/2。
- 发布契约：9/9，27 条断言；隔离测试运行器契约通过。

结论：单项 Reset 已精确恢复完整 imported property object，Inspector 与 Automation 不再残留 ghost override；无 UI/schema 扩张，未执行 Release 或安装覆盖。
