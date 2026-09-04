# Requirement Spec Card

- 只恢复存在导入默认且完整属性对象不同的覆盖。
- 无默认 Custom 不计数、不显示批量入口、恢复后保持不变。
- 成功仅一次 Undo/History/status；无覆盖静默 no-op。
- 自身或祖先全锁/像素锁阻止写入；位置锁/透明像素锁不阻止。
- Inspector 有覆盖时显示全部还原；过滤状态不变，恢复后自然显示空态。
- Automation `resetAll` 无需 key/value，结果结构保持兼容。
