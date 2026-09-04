# PRD：Figma IMAGE Paint 诊断完整性

## 功能需求

1. IMAGE Fill 不能再静默丢弃 Paint blendMode 或 opacity 诊断。
2. 非 NORMAL/未知模式与非 1/非法 opacity 必须产生 partial/unsupportedPaint。
3. 默认 NORMAL、opacity nil/1 和现有成功 image 路径不得误报。
4. 本版不提升 Paint 模式，不声称视觉 exact 保真。

## 验收标准

- 映射内非普通模式与未知模式均被 IMAGE 分支诊断。
- opacity 小于 1、非有限或非法值被诊断。
- NORMAL、nil/1 不产生新诊断。
- 现有 image asset/filter/transform/materializer 回归通过。
- 版本、CHANGELOG、产品概览、路线图、Git 标签与 main 同步。
