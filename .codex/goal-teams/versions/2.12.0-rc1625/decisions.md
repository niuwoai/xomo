# Decisions

- `diagnosticCount` 等于 `diagnosis.diagnostic != nil` 的属性数，包含仍可写 warning。
- `blockedCount` 等于 `diagnosis.writable == false` 的属性数，仅表达数据结构阻塞，不吸收图层锁定。
- `onlyOverrides` 与 `onlyDiagnostics` 采用逻辑与，结果按 key 稳定排序。
- 筛选仅影响 Inspector 行展示，不改变复制、粘贴、还原、History 或项目 dirty state。
- Automation 仅在成功响应根对象追加两个计数；旧字段、逐项诊断和 actions 不变。
