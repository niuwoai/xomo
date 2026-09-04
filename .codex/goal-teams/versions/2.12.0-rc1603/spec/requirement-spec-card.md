# 需求规格卡：Figma IMAGE Paint 诊断完整性

## 用户价值

Figma IMAGE Fill 含 Xomo 当前不能等价表达的 Paint 混合模式或透明度时，导入结果必须明确标记 partial/unsupportedPaint，不能静默当作 exact。

## 正常条件

- RECTANGLE IMAGE Fill 的 blendMode 为 nil/NORMAL。
- Paint opacity 为 nil 或 1，且其他 imageRef/transform/filter 条件由现有 mapper 支持。

## 必须诊断

- IMAGE Paint blendMode 为任一非 NORMAL、PASS_THROUGH 或未知值。
- IMAGE Paint opacity 非 1、非有限或非法。
- 不因提前返回而跳过已有 Paint 支持检查。

## 兼容性

不新增字段，不修改项目 schema，不改变正常 IMAGE 物化；Fill 级混合保真另起架构版本。
