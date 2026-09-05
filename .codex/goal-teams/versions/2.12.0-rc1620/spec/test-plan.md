# Test Plan

- Provenance：同 baseline 跨实例、metadata-only 往返、TEXT 后代、单 Undo/History、Undo/Redo。
- 原子失败：空/损坏 JSON、unknown、Custom、baseline 不同、unsupported type、非法 BOOLEAN、preferredValues 损坏、TEXT 映射歧义。
- 锁：自身/祖先 full 与 pixel 拒绝；position 与 transparency 允许；锁定后代跳过。
- no-op：第二次粘贴不新增 Undo/History，defaults 始终不变。
- Automation：`pasteOverrides` 成功/no-op/无效/锁定，验证 action-specific 计数和完整快照。
- CLI/MCP：App Registry 与 fallback enum、工具描述一致。
- 动态顺序：Figma 冷构建，Automation/cursor 复用产物，再跑 CLI 与发布/runner 契约。
