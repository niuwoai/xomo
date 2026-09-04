# Architecture Design：Figma IMAGE Paint 诊断完整性

## 现状

非 IMAGE Paint 会经过 `inspectPaints`；RECTANGLE IMAGE 命中后提前返回，导致 Paint blendMode/opacity 绕过诊断。

## 设计

- IMAGE 分支在返回前复用或调用等价的 Paint 支持检查。
- 非 NORMAL/未知 blendMode 与非 1/非法 opacity 追加现有风格 unsupportedPaint，并使 item 保持 partial。
- 默认 NORMAL 与 opacity nil/1 不改变现有 image mapping。

## 不变量

- 不修改 materializer、import item、项目模型或持久化 schema。
- 不把 Paint 模式传播到图层或子层。
- 正常 IMAGE 路径、filter/transform 和 asset 解析行为不变。
