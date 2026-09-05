# Decisions

- 诊断为纯派生值，不写入项目、不产生 Undo/Redo/History、不标记文档脏。
- 数据健康度与图层 `editable` 分离；锁定不遮蔽诊断。
- schema 损坏与未知类型只读；候选结构合法时才允许 Picker。
- 孤儿值保持原样且不得自动迁移；显式合法选择才允许修复。
- VARIANT 需要唯一 key/name 并存 name；INSTANCE_SWAP 存 key、允许重名 name，但重名展示必须带 key。
- 空候选枚举维持 rc1623 自由非空值兼容；`pasteOverrides` 完全不改。
