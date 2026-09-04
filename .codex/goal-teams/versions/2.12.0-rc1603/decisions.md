# 2.12.0-rc1603 决策

| 日期 | 决策 | 理由 |
| --- | --- | --- |
| 2026-09-05 | 取消 leaf PASS_THROUGH 单 Fill 提升方案 | REST 限定 PASS_THROUGH 适用于有 children 的对象；官方 Help 说明 NORMAL 会隔离 Fill 混合，当前 exact 支持域为空 |
| 2026-09-05 | rc1603 改为 IMAGE Paint 诊断完整性 | IMAGE 分支提前返回会静默漏掉 blendMode/opacity，修复可避免虚假 exact |
| 2026-09-05 | Fill 级混合保真后置 | 需要独立 Fill/背景层承载和真实 Figma 渲染对照，属于更大架构变更 |
