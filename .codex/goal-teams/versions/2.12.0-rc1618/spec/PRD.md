# PRD

旧 Automation 只有 imported default 的 scalar value。遇到当前 value 与默认相同、但 type 或 preferredValues 漂移时，客户端只能看到 `overridden=true`，却无法解释差异或预知 Reset 结果。rc1618 增加完整导入基线与覆盖摘要，同时保留旧字段兼容。

验收：四种 action 的直接返回都携带完整、稳定、可比较的结果；Custom 使用显式 null；counts 随 set/reset/resetAll 正确变化，不扩大 UI、输入或持久化协议。
