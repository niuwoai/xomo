# Architecture Design

- `updateSelectedFigmaComponentProperty` 返回 changed、unchanged、invalid、locked、notFound。
- 方法内按 type 分流归一化，并在 pushUndo/default snapshot 前完成全部验证和语义 no-op 判断。
- 候选先验证非空 key/name 和唯一 key；VARIANT 额外要求 name 唯一并写 candidate.name，INSTANCE_SWAP 写 candidate.key。
- key 精确匹配优先于唯一 name；重复 name 对 VARIANT 使整项 invalid，对 INSTANCE_SWAP 仅禁止 name 输入。
- 在解析输入与判断 no-op 前，拒绝跨候选 `name == other.key`；同一候选 key==name 不构成碰撞。
- Inspector Binding 以 candidate.key 为 selection/tag，getter 只反解唯一 name，setter 仍调用共享 ViewModel。
- Automation set 直接 switch 共享结果；不复制校验逻辑，不改 pasteOverrides。
