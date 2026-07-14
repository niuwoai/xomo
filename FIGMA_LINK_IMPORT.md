# Xomo Figma 链接导入边界

> 最后更新：2026-07-15 ｜ 当前版本：v2.12.0-rc64 ｜ 当前阶段：Auto Layout 固定与 Hug 容器可原生编辑

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

rc59 要求链接包含明确的 `node-id`。用户点击“读取节点并生成计划”后，Xomo 调用官方 `GET /v1/files/:key/nodes`，只读取该节点最多 6 层的子树并请求 `geometry=paths`。响应先转换成逐项报告，画布保持不变；用户再次点击“导入可映射图层”后才会一次性建立可撤销图层：

| Figma 节点 | Xomo 结果 | 当前保真范围 |
| --- | --- | --- |
| Frame / Group | 嵌套图层组 | 保留层级、名称、显隐、透明度与固定坐标；水平/垂直 Auto Layout 保留间距、内距、两轴对齐及固定/Hug 容器尺寸 |
| Component / Component Set / Instance | 普通嵌套图层组 | 子层可编辑，基础 Auto Layout 与 Hug 容器可重排；组件/实例语义明确降级 |
| Text | 可编辑文字层 | 保留文本、字体族、字号、字重、横向对齐和纯色填充 |
| Rectangle / Ellipse | 可编辑形状层 | 保留纯色填充、纯色描边和描边宽度；圆角暂降级为直角 |
| Vector / Line / Star / Polygon | 可编辑路径形状层 | 支持 fill/stroke geometry 与 SVG M/L/H/V/C/S/Q/T/A/Z 的绝对、相对命令；按节点局部 size 映射 |
| 图片填充 Rectangle | 图片像素层或占位层 | 显式读取时下载当前子树引用的图片，保留位置和尺寸并随项目保存；填充变换烘焙为固定像素，单图失败时保留格纹交叉占位图 |
| 其它节点 | 不导入 | 报告中列为不支持，不生成假图层 |

## 安全边界

- 只接受 `https://figma.com` 与 `https://www.figma.com`，拒绝相似后缀域名、HTTP、自定义端口、URL 用户名/密码和 fragment。
- 输入最长 4096 字符；文件 Key、节点和版本参数使用长度与字符白名单。
- `node-id`、`starting-point-node-id`、`version-id` 重复时拒绝，不猜测用户意图。
- 除上述三个选择参数外，其余 query 全部丢弃；令牌、时间戳、跟踪参数及其值不会进入规范 URL、预览模型、项目文件或测试报告。
- 链接只说明资源位置，不代表用户拥有访问权。未连接时授权状态保持 `notChecked`；连接时由 Figma 官方接口决定是否有权读取，不绕过权限。
- 个人令牌只写入 macOS 钥匙串的 `im.some.xomo.figma` 服务，并使用 `WhenUnlockedThisDeviceOnly`；不写入 `UserDefaults`、项目、日志、Git、查询参数或测试夹具。
- 元数据请求使用 `file_metadata:read`；节点与图片清单请求使用 `file_content:read`。三者都只向 `api.figma.com` 发送 `X-Figma-Token`；URLSession 不使用 Cookie 和缓存，不跟随重定向，避免令牌被转发到其它主机。
- 节点请求固定携带已校验的 `ids`、`depth=6` 和 `geometry=paths`；只有链接中存在合法版本时才附带 `version`。节点响应上限为 10 MB、树上限为 2000 项，元数据响应上限仍为 2 MB。
- 图片清单使用官方 `GET /v1/files/:key/images`，只消费当前计划实际引用的 `imageRef`。临时资源下载请求不携带 PAT、Authorization、Cookie 或浏览器状态，只接受无凭据、无自定义端口的 HTTPS URL，并拒绝 localhost、`.local` 与 IP 字面量；最多下载 24 个引用，单图 20 MB、总计 80 MB、最长边 16384 像素且不超过 6400 万像素。
- 官方节点端点属于 Tier 1，低权限席位的配额可能很少，因此不自动刷新、不轮询；只有用户主动读取才消耗一次请求。401/403、404、429、5xx、畸形响应和传输失败会分别提示。
- 读取计划不修改画布；导入只消费已读取的本地计划，不再次联网，并将整批变化记录为一个 History/Undo 步骤。断开连接会删除令牌并清除当前远端状态。
- 当前连接仅适合单个用户的本机工具。面向多用户/商业分发时必须改用 Figma OAuth 和外部回调服务，不能要求团队成员共享 PAT。

## 分阶段交付

1. **rc56（已完成）**：可信 URL 解析、选择参数规范化、无凭据只读预览模型。
2. **rc57（已完成）**：在“导入 Figma 链接”界面粘贴链接，显示类型、文件 Key、节点、版本、安全清理结果与明确的未授权状态，并可复制规范化 URL。
3. **rc58（已完成）**：用户显式提供本机个人 PAT 后，只通过官方 metadata 端点读取文件元数据；凭据保存在 macOS 钥匙串，不写入项目、偏好、日志或 Git。
4. **rc59（已完成）**：显式读取链接所选节点，映射 Frame、Group、Text、基础形状/SVG 路径、图片填充占位与组件层级；先生成逐项报告，再由用户确认创建单步可撤销图层。
5. **rc60（已完成）**：完整项目编译、817 项全量隔离测试和真实界面冒烟通过；集成回归固定导入后的 Undo/Redo、项目保存重开、可编辑层级恢复、PNG 合成导出和凭据不持久化闭环。
6. **rc61（已完成）**：节点 ID 校验与 SVG 路径解析明确为不依赖主线程的纯函数边界，清除 Swift 6 Release 预警；不扩大授权范围或改变导入结果。
7. **rc62（已完成）**：显式节点读取同步解析官方图片清单，把安全、可解码且未超限的图片填充导入为持久像素层；单图失败时保留可导入占位层，下载请求不携带 PAT。
8. **rc63（已完成）**：水平/垂直固定尺寸 Auto Layout 映射为原生组布局，保留间距、四边内距、主轴/交叉轴对齐和绝对定位排除；属性面板可重新排列并支持保存、重开与 Undo/Redo。
9. **rc64（当前，已完成）**：主轴/交叉轴 `AUTO` 尺寸映射为 Hug 容器；重排按内容、间距和内距计算组边界，并同步 Frame 背景。属性面板可切换固定/Hug，项目继续兼容 rc63 数据。

## 官方依据

- [Figma 文件端点](https://developers.figma.com/docs/rest-api/file-endpoints/)：官方 URL 结构为 `/:file_type/:file_key/:file_name`，文件 Key 或分支 Key用于读取文件。
- [Figma 文件节点端点](https://developers.figma.com/docs/rest-api/file-endpoints/)：`GET /v1/files/:key/nodes` 通过 `ids` 读取指定节点；`geometry=paths` 返回矢量路径数据，`depth` 限制后代层数。
- [Figma 图片填充端点](https://developers.figma.com/docs/rest-api/file-endpoints/)：`GET /v1/files/:key/images` 以 `imageRef` 返回最长约 14 天有效的临时下载 URL，要求 `file_content:read`。
- [Figma 节点类型](https://developers.figma.com/docs/rest-api/file-node-types/)：Frame、Group、Vector、Text、Rectangle、Ellipse、Component 与 Instance 的可读取字段构成 rc59 映射依据。
- [Figma API 限流](https://developers.figma.com/docs/rest-api/rate-limits/)：文件节点读取属于 Tier 1，配额按席位和计划不同，因此界面使用显式读取且不自动刷新。
- [Figma 认证](https://developers.figma.com/docs/rest-api/authentication/)：个人工具可使用 PAT，代表多用户操作的应用应使用 OAuth；不同端点要求对应 scope。
- [Figma Personal Access Token](https://developers.figma.com/docs/rest-api/personal-access-tokens/)：PAT 通过 `X-Figma-Token` 请求头发送，不放入 URL。
- [Figma OAuth](https://developers.figma.com/docs/rest-api/oauth-apps/)：商业多用户连接需要浏览器授权和回调服务，仍是后续阶段。
- [Figma 节点 ID](https://developers.figma.com/docs/plugins/api/properties/nodes-id/)：URL 中使用连字符的节点 ID，调用 API 时转换为冒号形式。
- [Figma 文件 URL 指南](https://help.figma.com/hc/en-us/articles/1500005554982.html)：列出 Design、Prototype、FigJam、Slides 等文件路径和节点链接语义。

## 明确尚未支持

rc64 不保留图片的原生 Crop/Tile/旋转等可编辑填充参数，成功资源会烘焙为固定像素层；它仍不保留渐变/图案等复杂 Paint、旋转/镜像/倾斜变换、圆角、蒙版与 Frame 内容裁切关系、效果、特殊混合模式、Wrap、Fill/Stretch、Baseline、变量、组件属性和实例覆写语义。Hug 只改变容器宽高，不自动改变子项大小；绝对定位子项不参与 Hug 尺寸计算。超过 6 层的后代不会读取；不解析 `.fig` 私有格式、不读取浏览器会话，也不声称 Figma 文件可以无损还原。后续每增加一种节点或语义映射，都必须附带单元测试、降级说明和可核对的导入报告。
