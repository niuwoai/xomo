# Test Plan

- Direct：metadata-only、value+metadata、目标隔离、Custom、一次 Undo/Redo、project roundtrip、第二次 no-op。
- TEXT：旧值匹配后代、锁定后代跳过，完整默认对象写回。
- Automation：reset 后 preferredValues 与默认一致且 `overridden=false`；unknown/no-default/locked 保持原契约。
- 回归：单项/批量组件属性、组件库 cursor、CLI/MCP、发布与隔离测试器契约。
