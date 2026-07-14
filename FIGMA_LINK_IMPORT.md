# Xomo Figma 链接导入边界

> 最后更新：2026-07-15 ｜ 当前版本：v2.12.0-rc58 ｜ 当前阶段：用户授权的官方文件元数据读取

## 当前已经支持

`XomoFigmaLinkParser` 仍在本机纯解析用户提供的链接，不发起网络请求，也不读取浏览器登录状态。当前识别 Figma 官方文件 URL 结构中的以下资源路径：

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

rc58 在这层本地预览之后增加可选的个人连接：用户必须主动粘贴自己的 Personal Access Token 并点击“保存并读取”，Xomo 才会访问 `https://api.figma.com/v1/files/:key/meta`。成功后显示官方文件名、文件夹、最近修改时间、编辑器类型、版本、当前角色和链接访问级别；这仍是元数据核对，不读取节点树，也不创建 Xomo 图层。

## 安全边界

- 只接受 `https://figma.com` 与 `https://www.figma.com`，拒绝相似后缀域名、HTTP、自定义端口、URL 用户名/密码和 fragment。
- 输入最长 4096 字符；文件 Key、节点和版本参数使用长度与字符白名单。
- `node-id`、`starting-point-node-id`、`version-id` 重复时拒绝，不猜测用户意图。
- 除上述三个选择参数外，其余 query 全部丢弃；令牌、时间戳、跟踪参数及其值不会进入规范 URL、预览模型、项目文件或测试报告。
- 链接只说明资源位置，不代表用户拥有访问权。未连接时授权状态保持 `notChecked`；连接时由 Figma 官方接口决定是否有权读取，不绕过权限。
- 个人令牌只写入 macOS 钥匙串的 `im.some.xomo.figma` 服务，并使用 `WhenUnlockedThisDeviceOnly`；不写入 `UserDefaults`、项目、日志、Git、查询参数或测试夹具。
- 只请求 `file_metadata:read`，使用 `X-Figma-Token` 请求头；URLSession 不使用 Cookie 和缓存，不跟随重定向，避免令牌被转发到其它主机。
- 响应上限为 2 MB；401/403、404、429、5xx、畸形响应和传输失败会分别提示。断开连接会删除令牌并清除当前元数据。
- 当前连接仅适合单个用户的本机工具。面向多用户/商业分发时必须改用 Figma OAuth 和外部回调服务，不能要求团队成员共享 PAT。

## 分阶段交付

1. **rc56（已完成）**：可信 URL 解析、选择参数规范化、无凭据只读预览模型。
2. **rc57（已完成）**：在“导入 Figma 链接”界面粘贴链接，显示类型、文件 Key、节点、版本、安全清理结果与明确的未授权状态，并可复制规范化 URL。
3. **rc58（当前，已完成）**：用户显式提供本机个人 PAT 后，只通过官方 metadata 端点读取文件元数据；凭据保存在 macOS 钥匙串，不写入项目、偏好、日志或 Git。
4. **rc59**：先映射 Frame、Group、Text、基础矢量、图片填充、组件与样式，生成逐项导入/降级报告。
5. **rc60**：执行完整项目编译、全量测试和真实界面冒烟，核对导入、保存、重开、撤销与导出闭环。

## 官方依据

- [Figma 文件端点](https://developers.figma.com/docs/rest-api/file-endpoints/)：官方 URL 结构为 `/:file_type/:file_key/:file_name`，文件 Key 或分支 Key用于读取文件。
- [Figma 认证](https://developers.figma.com/docs/rest-api/authentication/)：个人工具可使用 PAT，代表多用户操作的应用应使用 OAuth；不同端点要求对应 scope。
- [Figma Personal Access Token](https://developers.figma.com/docs/rest-api/personal-access-tokens/)：PAT 通过 `X-Figma-Token` 请求头发送，不放入 URL。
- [Figma OAuth](https://developers.figma.com/docs/rest-api/oauth-apps/)：商业多用户连接需要浏览器授权和回调服务，仍是后续阶段。
- [Figma 节点 ID](https://developers.figma.com/docs/plugins/api/properties/nodes-id/)：URL 中使用连字符的节点 ID，调用 API 时转换为冒号形式。
- [Figma 文件 URL 指南](https://help.figma.com/hc/en-us/articles/1500005554982.html)：列出 Design、Prototype、FigJam、Slides 等文件路径和节点链接语义。

## 明确尚未支持

rc58 只读取远端文件元数据，不读取缩略图或图层树，不导入任何画布内容，不解析 `.fig` 私有文件格式，也不声称 Figma 文件可以无损还原。后续每增加一种节点映射，都必须附带单元测试、降级说明和可核对的导入报告。
