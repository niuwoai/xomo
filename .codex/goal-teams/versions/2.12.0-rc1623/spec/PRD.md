# PRD

## 用户价值

Figma 枚举属性从 Inspector 或 Automation 修改后始终能被再次理解、展示和还原，错误输入不会污染项目。

## 验收边界

- BOOLEAN 仅小写 true/false；VARIANT 候选 key/name 均唯一并存 name，INSTANCE_SWAP 候选 key 唯一并存 key。
- key 优先；VARIANT 重复 name 时整项拒绝，INSTANCE_SWAP 重复 name 时 name 输入拒绝但明确 key 可选择。
- 任一候选 name 与另一候选 key 相等时整项拒绝；同一候选 key==name 允许。
- 当前 key 或唯一 name 对应同一候选时语义 no-op；重复 name 的 legacy current 不得被当作明确候选。
- 无候选非空自由值保持兼容；旧孤儿值不因显示或 no-op 自动迁移。
- invalid、locked、notFound 有结构化结果；失败不改变属性、defaults、Undo/Redo 或 History。
- Inspector tag 使用 key，只反解唯一 name；Automation invalid 映射 invalidArgument；TEXT 行为不回退。
