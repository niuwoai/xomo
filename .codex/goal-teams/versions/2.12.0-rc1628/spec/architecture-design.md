# Architecture Design

- 在 `XomoFigmaComponentProperty` 邻近定义 `Equatable, Sendable` 的纯展示枚举，承载 `.localized(key:rawType:)` 或 `.raw(String)`。
- `typePresentation` 只根据 `type` 精确派生，并暴露不变的 `rawType`。
- 模型层不读取 Locale；View helper 使用 `L10n.text` 解析 key，并统一生成本地化 raw help。
- 现有 `diagnosis`、`resolvingWrite`、filter result 与 Codable 定义保持独立，禁止反向依赖 presentation。
- UI 仅替换旧 `Text(property.type)` 的视觉表达，保留现有 editor 和操作路径。
