# Test Plan

- Direct：完整对象恢复、Custom 保留、多 TEXT 后代、一次 Undo/Redo、no-op。
- Lock：自身及祖先全锁/像素锁零副作用，非内容锁仍可操作。
- UI：按钮条件、禁用态、可访问性、三语文案与过滤空态接线。
- Automation：resetAll 成功、幂等、锁定失败、schema action 枚举。
- 回归：Figma provenance、Automation component properties、cursor、CLI/MCP 与发布契约。
