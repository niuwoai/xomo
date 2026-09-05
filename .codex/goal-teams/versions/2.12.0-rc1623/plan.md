# Plan

长期 Goal 持续执行。本版不是 rc1640 周期门禁。

1. 冻结 TEXT、BOOLEAN、VARIANT、INSTANCE_SWAP 的写入矩阵。
2. 在 ViewModel 建立 changed/unchanged/invalid/locked/notFound 共享结果。
3. Inspector 使用稳定 key，Automation 映射结构化失败。
4. 补 ViewModel、Automation 与 Inspector 合同回归并独立审查。
5. 串行验证后提交、快进合入 `main`，打 `v2.12.0-rc1623` 并推送。
