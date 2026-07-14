# Xomo Figma 链接导入边界

> 最后更新：2026-07-15 ｜ 当前版本：v2.12.0-rc56 ｜ 当前阶段：本地安全解析与只读链接预览

## 当前已经支持

`XomoFigmaLinkParser` 在本机纯解析用户提供的链接，不发起网络请求，也不读取浏览器登录状态。当前识别 Figma 官方文件 URL 结构中的以下资源路径：

| 路径 | 资源 | 后续计划 |
| --- | --- | --- |
| `design` / `file` | Figma Design 与旧版文件链接 | 映射为 Xomo 设计文档 |
| `proto` | Figma Design 原型 | 映射设计节点，保留原型入口元数据 |
| `board` | FigJam | 单独映射白板节点，不与设计 Frame 混为一谈 |
| `slides` / `deck` | Figma Slides | 当前只读预览 |
| `site` | Figma Sites | 当前只读预览 |
| `buzz` | Figma Buzz | 当前只读预览 |
| `make` | Figma Make | 当前只读预览 |

解析结果包含资源类型、文件 Key、文件名、节点 ID、原型起点节点、版本 ID 和规范化 URL。URL 中的节点 ID 会从链接形式 `1-3` 转为 API 使用的 `1:3`；模型编码时只保存规范化结果。

## 安全边界

- 只接受 `https://figma.com` 与 `https://www.figma.com`，拒绝相似后缀域名、HTTP、自定义端口、URL 用户名/密码和 fragment。
- 输入最长 4096 字符；文件 Key、节点和版本参数使用长度与字符白名单。
- `node-id`、`starting-point-node-id`、`version-id` 重复时拒绝，不猜测用户意图。
- 除上述三个选择参数外，其余 query 全部丢弃；令牌、时间戳、跟踪参数及其值不会进入规范 URL、预览模型、项目文件或测试报告。
- 链接只说明资源位置，不代表用户拥有访问权。rc56 的授权状态固定为 `notChecked`，不会绕过 Figma 权限。

## 分阶段交付

1. **rc56（当前）**：可信 URL 解析、选择参数规范化、无凭据只读预览模型。
2. **rc57**：在“导入 Figma 链接”界面粘贴链接，显示类型、文件 Key、节点、版本、安全清理结果与明确的未授权状态。
3. **rc58**：仅在用户明确发起授权后，使用 Figma 官方接口读取文件元数据或内容；凭据不写入项目、日志或 Git。
4. **rc59**：先映射 Frame、Group、Text、基础矢量、图片填充、组件与样式，生成逐项导入/降级报告。
5. **rc60**：执行完整项目编译、全量测试和真实界面冒烟，核对导入、保存、重开、撤销与导出闭环。

## 官方依据

- [Figma 文件端点](https://developers.figma.com/docs/rest-api/file-endpoints/)：官方 URL 结构为 `/:file_type/:file_key/:file_name`，文件 Key 或分支 Key用于读取文件。
- [Figma 节点 ID](https://developers.figma.com/docs/plugins/api/properties/nodes-id/)：URL 中使用连字符的节点 ID，调用 API 时转换为冒号形式。
- [Figma 文件 URL 指南](https://help.figma.com/hc/en-us/articles/1500005554982.html)：列出 Design、Prototype、FigJam、Slides 等文件路径和节点链接语义。

## 明确尚未支持

rc56 不读取远端文件名、缩略图或图层树，不导入任何画布内容，不解析 `.fig` 私有文件格式，也不声称 Figma 文件可以无损还原。后续每增加一种节点映射，都必须附带单元测试、降级说明和可核对的导入报告。
