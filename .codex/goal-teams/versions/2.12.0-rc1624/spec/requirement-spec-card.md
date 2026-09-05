# Requirement Specification Card

- 用户价值：旧版或异常 Figma 属性仍可检查，不会被错误 Toggle、空 Picker 或重复 SwiftUI 标识误导。
- 核心功能：共享诊断、稳定候选选择、只读回退、Automation 诊断字段。
- 兼容：保留全部原始字段与既有 Automation 字段；不自动修复项目数据。
- 非目标：真实 instance swap、主组件同步、网络导入、项目格式迁移。
- 验收：合法属性保持可编辑；异常属性原样可读；UI 与 Automation 诊断一致；写入语义不回退。
