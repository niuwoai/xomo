# Decisions

- 文本后代只有在 current/default 都精确为 `TEXT` 且 value 不同时才同步。
- TEXT→非 TEXT、非 TEXT→TEXT、非 TEXT→非 TEXT 均只恢复完整属性对象，不触碰文本层。
- TEXT→TEXT 同值的 metadata-only 覆盖恢复对象，但不重建文本层。
- resetAll 保留既有排序消费、单次 Undo/History、Custom 无默认保留和锁语义。
- 不增加 UI、i18n、Automation 或 CLI schema。
