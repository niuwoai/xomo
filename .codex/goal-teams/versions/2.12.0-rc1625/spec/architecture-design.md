# Architecture Design

- 模型旁新增非 Codable 的 `XomoFigmaComponentPropertyHealthSummary`，单次遍历 properties 并从 `diagnosis` 派生两个计数。
- ViewModel 暴露共享摘要/计数；现有 key API 增 `onlyDiagnostics: Bool = false`，以交集过滤后统一排序。
- Inspector 增本地 `@State`、健康摘要、问题开关与组合筛选空态；批量动作不消费筛选状态。
- Automation 的共享 result 路径从当前 properties 构造相同摘要，只追加根字段。
- blocked 禁止读取混入图层锁的逐项有效 `writable`；必须使用数据级 diagnosis。
