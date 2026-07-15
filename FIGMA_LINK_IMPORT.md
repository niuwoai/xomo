# Xomo Figma 链接导入边界

> 最后更新：2026-07-16 ｜ 当前版本：v2.12.0-rc123 ｜ 当前阶段：设计 token 主题文件交换与 Figma 绑定检查

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

rc94 在 rc93 的基础上识别节点的 `boundVariables` 中 `fills`、`strokes` 与 `characters` 的 `VARIABLE_ALIAS`，并在用户已提供 Personal Access Token 时调用官方 `GET /v1/files/:key/variables/local`。颜色变量按默认 mode 读取，颜色别名递归解析后覆盖对应的纯色填充/描边；原生图层与项目保存重开继续保留字段和变量 ID。Variables 权限、网络或值类型不满足时，回退到节点响应中的静态颜色/文字，不伪装成完整变量系统。

| Figma 节点 | Xomo 结果 | 当前保真范围 |
| --- | --- | --- |
| Frame / Group | 嵌套图层组 | 保留层级、名称、显隐、透明度与固定坐标；水平/垂直 Auto Layout 保留间距、内距、两轴对齐、固定/Hug 容器及 Fill/Stretch 子项，水平 Wrap 另保留分行、行间距与逐行文字 Baseline |
| Component / Component Set / Instance | 普通嵌套图层组 | 子层可编辑，Auto Layout 容器与子项可重排；组件/实例语义明确降级 |
| Text | 可编辑文字层 | 保留文本、字体族、字号、字重、横向对齐和纯色填充 |
| Rectangle / Ellipse | 可编辑形状层 | 保留纯色、2–16 色标线性渐变或像素轴等长垂直的圆形径向渐变，支持偏心中心与公共透明度；保留纯色描边、描边宽度，以及矩形统一/非对称四角和圆角平滑，平滑曲线使用超椭圆近似 |
| Vector / Line / Star / Polygon | 可编辑路径形状层 | 支持 fill/stroke geometry 与 SVG M/L/H/V/C/S/Q/T/A/Z 的绝对、相对命令；闭合路径可保留同一套线性或圆形径向渐变，按节点局部 size 映射 |
| 图片填充 Rectangle | 图片像素层或占位层 | 显式读取时下载当前子树引用的图片；Fill/Fit、Crop 对应的 `STRETCH + imageTransform`、Tile 比例、90°旋转及曝光/对比度/饱和度/色温/色调/高光/阴影会烘焙为固定像素，单图失败时保留格纹交叉占位图 |
| 其它节点 | 不导入 | 报告中列为不支持，不生成假图层 |

rc72 依据 Figma 官方 [Paint / ColorStop 属性说明](https://developers.figma.com/docs/rest-api/file-property-types/) 读取 `gradientHandlePositions` 与 `gradientStops`。rc73 将线性控制轴中点保留为形状专属的归一化渐变中心；rc74 进一步保留 2–16 个有序色标。rc78 把径向第一个控制点作为中心，并将后两个控制点按对象实际宽高换算成像素轴；只有两轴等长且垂直、半径落入 Xomo 25%–400% 范围时才精确导入。两类渐变都要求首尾色标位置为 0/1、各色标透明度一致；不同透明度、超过 16 个色标、椭圆/倾斜径向轴、角度和菱形渐变继续报告 `unsupportedPaint`。

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
9. **rc64（已完成）**：主轴/交叉轴 `AUTO` 尺寸映射为 Hug 容器；重排按内容、间距和内距计算组边界，并同步 Frame 背景。属性面板可切换固定/Hug，项目继续兼容 rc63 数据。
10. **rc65（已完成）**：子项 `layoutGrow` 与 `layoutAlign=STRETCH` 映射为 Fill/Stretch；固定容器按权重分配主轴空间并填满交叉轴，属性面板可编辑，项目与 Undo/Redo 闭环保持。
11. **rc66（当前，已完成）**：图片填充读取 `imageTransform`、`scalingFactor` 与 `rotation`，把 Crop/STRETCH、Tile 和 90°旋转按源图与目标框烘焙为像素结果；参数语义仍明确降级为不可再次编辑。
12. **rc73（当前，已完成）**：双停止点线性渐变保留偏心控制轴；导入后显示可拖动起止控制柄，中心、角度与跨度进入项目保存、Undo/Redo 和 MCP。
13. **rc74（当前，已完成）**：双停止点扩展为 2–16 个有序色标；Figma 多色标、Xomo 项目、属性面板与 MCP `stops` 数组使用同一插值模型，不同透明度仍明确降级。
14. **rc75（当前，已完成）**：导入后的中间色标显示为画布渐变轴上的彩色菱形，可直接拖动位置并与属性面板共享选中索引；轴方向、偏心中心与 Figma 色标顺序保持不变。
15. **rc76（当前，已完成）**：双击导入渐变的画布轴可在视觉命中位置新增插值色标，Delete 可删除当前中间色标；新增和删除保持原生形状编辑、单步 Undo 与项目持久化语义。
16. **rc77（当前，已完成）**：Xomo 形状建立原生径向渐变数据、渲染、属性与 MCP 闭环；Figma `GRADIENT_RADIAL` 本版仍按复杂填充明确降级，不提前声称已经精确导入。
17. **rc78（当前，已完成）**：Figma `GRADIENT_RADIAL` 的多色标、公共透明度、中心和圆形半径映射为原生径向形状渐变；实际像素空间中的椭圆或倾斜双轴继续明确降级。
18. **rc79（当前，已完成）**：导入后的径向渐变显示真实变换后的虚线边界、中心柄和半径柄，可直接拖动并保持实时预览、单步 Undo 与项目语义。
19. **rc81（当前，已完成）**：渐变色标与 RGBA 响应值成为明确的后台安全值类型；色标归一化从 detached task 可直接调用，线性/径向映射结果不变，双架构 Release 不再报告 actor-isolation 预警。
20. **rc82（当前，已完成）**：导入的多色标径向渐变在中心到半径柄之间显示可选、可拖动的中间色标；反向、偏心与非等比缩放坐标保持一致，并继续复用项目、属性面板和单步 Undo 语义。
21. **rc83（当前，已完成）**：径向中心到半径控制线支持双击新增插值色标；正常与反向渐变都按视觉位置生成正确逻辑位置和颜色，并继续遵循 16 色标上限、锁定与单步 Undo。
22. **rc84（当前，已完成）**：径向中心柄与半径柄显示导入渐变的视觉起点/终点颜色；多色标读取真实首尾色，反向时交换，控制柄方向与实际画布渲染一致。
23. **rc86（当前，已完成）**：图片 Paint 的曝光、对比度、饱和度、色温、色调、高光和阴影按官方范围读取，在布局变换之后近似烘焙为像素；导入报告明确标记其不可再次单独编辑。
24. **rc87（当前，已完成）**：水平 `layoutWrap=WRAP` 与 `counterAxisSpacing` 映射为原生多行布局；固定宽度负责换行，交叉轴 Hug 随行数调整高度，Fill/Stretch 在各自行内生效。
25. **rc88（当前，已完成）**：水平 `counterAxisAlignItems=BASELINE` 映射为原生首行基线对齐；文字读取实时字体度量，普通图形回退到底边，Wrap 逐行计算基线上下包络。

## 官方依据

- [Figma 文件端点](https://developers.figma.com/docs/rest-api/file-endpoints/)：官方 URL 结构为 `/:file_type/:file_key/:file_name`，文件 Key 或分支 Key用于读取文件。
- [Figma 文件节点端点](https://developers.figma.com/docs/rest-api/file-endpoints/)：`GET /v1/files/:key/nodes` 通过 `ids` 读取指定节点；`geometry=paths` 返回矢量路径数据，`depth` 限制后代层数。
- [Figma 图片填充端点](https://developers.figma.com/docs/rest-api/file-endpoints/)：`GET /v1/files/:key/images` 以 `imageRef` 返回最长约 14 天有效的临时下载 URL，要求 `file_content:read`。
- [Figma Paint 属性](https://developers.figma.com/docs/rest-api/file-property-types/)：渐变 Paint 的三个归一化控制点依次表示起点、终点和宽度，rc78 据此验证径向双轴；图片 Paint 的 Fill/Fit/Tile/Stretch、`imageTransform`、`scalingFactor`、`rotation` 与 7 项 `filters` 按白名单进行本地像素烘焙。
- [Figma 节点类型](https://developers.figma.com/docs/rest-api/file-node-types/)：Frame、Group、Vector、Text、Rectangle、Ellipse、Component 与 Instance 的可读取字段构成 rc59 映射依据。
- [Figma Auto Layout Wrap](https://developers.figma.com/docs/plugins/api/properties/nodes-layoutwrap/)：`layoutWrap=WRAP` 只适用于水平 Auto Layout；[counterAxisSpacing](https://developers.figma.com/docs/plugins/api/properties/nodes-counteraxisspacing/) 定义换行轨道之间的正数间距，rc87 据此建立水平分行与独立行间距。
- [Figma Auto Layout Baseline](https://developers.figma.com/docs/plugins/api/properties/nodes-counteraxisalignitems/)：`BASELINE` 只允许水平 Auto Layout，并要求子项沿文字基线对齐；rc88 据此限制属性入口与导入边界。
- [Figma API 限流](https://developers.figma.com/docs/rest-api/rate-limits/)：文件节点读取属于 Tier 1，配额按席位和计划不同，因此界面使用显式读取且不自动刷新。
- [Figma 认证](https://developers.figma.com/docs/rest-api/authentication/)：个人工具可使用 PAT，代表多用户操作的应用应使用 OAuth；不同端点要求对应 scope。
- [Figma Personal Access Token](https://developers.figma.com/docs/rest-api/personal-access-tokens/)：PAT 通过 `X-Figma-Token` 请求头发送，不放入 URL。
- [Figma OAuth](https://developers.figma.com/docs/rest-api/oauth-apps/)：商业多用户连接需要浏览器授权和回调服务，仍是后续阶段。
- [Figma 节点 ID](https://developers.figma.com/docs/plugins/api/properties/nodes-id/)：URL 中使用连字符的节点 ID，调用 API 时转换为冒号形式。
- [Figma 文件 URL 指南](https://help.figma.com/hc/en-us/articles/1500005554982.html)：列出 Design、Prototype、FigJam、Slides 等文件路径和节点链接语义。

## 明确尚未支持

rc88 能把 Figma 的单一纯色、2–16 色标线性渐变和圆形径向渐变映射为可继续修改的形状填充，并保留独立纯色描边、统一 `cornerRadius`、合法的四角 `rectangleCornerRadii` 与 `cornerSmoothing`；平滑轮廓使用超椭圆视觉近似，因此仍会明确标记为部分保真。椭圆/倾斜径向轴、角度渐变、菱形渐变、图案与多重 Paint 仍不保留。图片 Crop/STRETCH、Tile、90°旋转和 7 项滤镜可以视觉烘焙，但这些参数尚未保存为可再次编辑的图片填充或独立滤镜对象；节点旋转/镜像/倾斜变换、蒙版与 Frame 内容裁切关系、效果、特殊混合模式、纵向 Wrap、换行轨道 `SPACE_BETWEEN`、组件属性和实例覆写语义仍未保留。rc94 对 `fills`、`strokes`、`characters` 的变量别名 ID 继续随图层保存，并可在有权限时解析颜色变量默认 mode 与颜色别名；变量文字、非颜色类型和完整 mode 编辑仍未保留。水平 Baseline 已原生保留，非法的垂直 Baseline 仍明确降级。Fill 子项只在父组对应轴为固定尺寸时改变外框；水平 Wrap 中按所在行分配剩余宽度，Stretch 填满所在行高度。父主轴为 Hug 时保留导入尺寸，避免父子互相依赖。绝对定位子项不参与布局尺寸计算。超过 6 层的后代不会读取；不解析 `.fig` 私有格式、不读取浏览器会话，也不声称 Figma 文件可以无损还原。
