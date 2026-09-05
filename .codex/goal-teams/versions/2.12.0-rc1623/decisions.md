# Decisions

- TEXT 原样保真且忽略 preferredValues；BOOLEAN trim 后只接受小写 true/false。
- VARIANT 有候选时要求非空且唯一的 key/name，输入优先精确 key、再匹配唯一 name，写入 candidate.name；任何重复 name 使整项不可编辑。
- INSTANCE_SWAP 要求非空且唯一 key，写入 candidate.key；重复 name 合法，但 name 输入只有唯一匹配时可用，重名项必须用明确 key 选择。
- VARIANT/INSTANCE_SWAP 均拒绝任一候选 name 与另一候选 key 相等；同一候选 key==name 可接受，避免 key-first 解析与旧 name 表示指向不同候选。
- 当前值等于 candidate.key，或等于唯一 candidate.name 时语义 no-op 并保留旧表示；legacy 重复 name 加明确 key 必须 changed 并存 key。
- 无 preferredValues 时继续接受 trim 后非空自由值；未知 type 拒绝。
- 旧孤儿值不自动迁移；合法显式选择可修复。pasteOverrides 保持 rc1620 契约。
- full/pixel lock 拒绝；position/transparency lock 允许；非法输入使用三语状态，Automation 返回 invalidArgument。
