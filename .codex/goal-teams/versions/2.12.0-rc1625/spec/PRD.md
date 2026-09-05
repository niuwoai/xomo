# PRD

## 目标

把 rc1624 的逐项诊断提升为可规模化定位的 Figma 组件属性健康视图。

## 验收

1. `diagnosticCount` 统计所有非空诊断；`blockedCount` 统计数据级不可写属性。
2. 图层锁只影响既有 `editable`/逐项有效 `writable`，不改变两个健康计数。
3. 无筛选、仅覆盖、仅问题、覆盖且问题四种结果均正确并稳定排序。
4. 组合筛选无结果时显示本地化空态；摘要、筛选与空态有稳定 accessibility identifier。
5. Automation 所有成功 action 的根结果包含最新计数，旧字段和 action 合同不变。
6. 只读汇总和筛选不写项目、不进 History/Undo/Redo。

## 非目标

不自动修复异常数据，不实现真实实例替换、Figma 云端同步、筛选持久化或项目 schema 变更。
