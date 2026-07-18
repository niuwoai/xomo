# Xomo MCP 与 CLI

> 当前版本：v2.12.0-rc307

rc307 增加本地图层/组件缩放与旋转的 Escape 取消事务；MCP/CLI 数据协议保持不变。
rc306 修复本地图层/组件缩放与旋转期间的光标稳定性；MCP/CLI 数据协议保持不变。
rc305 增加本地图层/组件变换控制点的通用缩放与旋转光标；MCP/CLI 数据协议保持不变。
rc304 增加本地图层/组件拖动的 Escape 取消语义，不提交位置、不新增 History；MCP/CLI 数据协议保持不变。
rc303 只修复本地组件拖动在画布/窗口边缘释放时的事务收尾，MCP/CLI 数据协议保持不变。
rc300 只收紧移动工具的前景图层光标命中，MCP/CLI 数据协议保持不变。
rc297 只修复本地组件对象拖拽手势与拖动光标反馈，MCP/CLI 数据协议保持不变。
rc296 只细化路径选择/直接选择的本地光标语义，MCP/CLI 数据协议保持不变。
rc293 只强化本地组件库系统箭头的回归契约，MCP/CLI 数据协议保持不变。
rc292 只增加本地组件对象的 Escape 取消选中语义，MCP/CLI 数据协议保持不变。
rc291 只调整本地组件对象的方向键优先级，MCP/CLI 数据协议保持不变。
rc289 修正直接选择路径节点的本地键盘语义；方向键和 Delete/Backspace 只影响节点，MCP/CLI 数据协议保持不变。
rc288 新增本地直接选择工具与 `Shift+A` 路径工具切换；这是画布交互能力，MCP/CLI 数据协议保持不变。
rc287 新增本地 Photoshop 风格路径选择工具与 `A` 快捷键；这是画布交互能力，MCP/CLI 数据协议保持不变。
rc285 修复组件拖动被 macOS 13 拖放宿主抢占的问题；该变化只影响本地画布交互，不改变 MCP/CLI 数据协议。
rc284 增加变换面板的锁定宽高比交互；该版本只扩展本地 UI 操作，不改变 MCP/CLI 数据协议。
rc283 新增属性面板精确变换能力；该版本只扩展本地 UI 操作，不改变 MCP/CLI 数据协议。
rc282 修复组件对象的画布拖动手势并调整本地工具光标；这些变化只影响 UI 交互，不改变 MCP/CLI 数据协议。

rc281 将仿制图章与修复画笔的画布指针纳入 Caps Lock 精确模式；该变化只影响本地 UI 光标，不改变 MCP/CLI 数据协议。

rc280 的画布工具交互遵循 Photoshop 的 Caps Lock 精确模式：画笔类工具按下 Caps Lock 时使用系统精确十字光标，MCP/CLI 数据协议不变。

rc279 让画布选区光标按矩形/椭圆选区形状显示对应虚线框；MCP/CLI 的选区数据和修饰键语义保持不变。

rc278 让油漆桶图标在工具栏、顶部选项栏和当前工具提示中保持一致；rc277 增加只读发布契约检查 `scripts/verify_release_contract.rb`，可为发布门禁输出 JSON/Markdown。

rc277 增加只读发布契约检查 `scripts/verify_release_contract.rb`，可为发布门禁输出 JSON/Markdown，并核对 App/CLI/所有 Xcode target 的版本、Bundle ID、macOS 13 下限和双架构构建入口。

rc276 让裁切框内部、边缘和角点显示上下文抓取/缩放光标；rc275 让矩形选区默认替换模式也使用带虚线框的语义光标；rc274 让选择、裁切、修补、渐变、形状、仿制图章、修复画笔和钢笔等工具使用可辨识的语义光标；rc273 让组件库插入与选中属于对象操作，画布光标保持系统箭头；工具光标仍按工具语义解析。rc272 完善 UI 裁切工作流：裁切框确认前可整体移动或用八个控制点调整，始终限制在画布边界内；MCP/CLI 的 `xomo.canvas.crop_to_selection` 数据语义不变，仍由确认后的文档裁切负责写入 History。rc271 为 UI 活动选区增加 Photoshop 风格行进蚂蚁视觉反馈。

rc271 为 UI 活动选区增加 Photoshop 风格行进蚂蚁视觉反馈；这是纯画布叠加动画，不改变 MCP/CLI 的选区数据、Undo/History 或导出结果。rc270 优化画布移动事务的高频路径：UI 组件与普通图层拖动中只更新预览几何，释放时才提交位置变化与 History，减少状态栏重绘带来的延迟。

rc270 优化画布移动事务的高频路径：UI 组件与普通图层拖动中只更新预览几何，释放时才提交位置变化与 History，减少状态栏重绘带来的延迟。rc269 起，组件库插入的组件可由移动工具在画布上直接拖动，UI 继续使用同一移动/预览事务；工具光标改用常见的系统箭头、手掌、I-Beam、十字准星和简洁笔刷圆环。

rc269 起，组件库插入的组件可由移动工具在画布上直接拖动，UI 继续使用同一移动/预览事务；工具光标改用常见的系统箭头、手掌、I-Beam、十字准星和简洁笔刷圆环。rc268 起，Fireworks 切片和热点可以通过移动工具直接在画布上拖动，拖动期间使用同一画布坐标换算和边界夹紧；释放时复用现有 UI 更新入口并只写入一次 Undo/History。rc267 起，`xomo.slice.update` 可更新命名切片的名称与矩形范围，并复用 UI 的 Undo/History；rc265 起，画布或交付面板选中的切片/热点可通过 Delete/Backspace 删除，并继续进入 Undo/History；rc264 起，移动工具的画布选择与交付面板共用切片/热点选择语义；rc263 起，切片交付面板与既有 `xomo.slice.create`、`xomo.slice.list`、`xomo.slice.delete` 和 `xomo.export.render` 共用命名切片模型；`xomo.export.render` 在 `scope=slice` 时仍接受 `sliceID`。rc262 起，热点交付面板与 MCP/CLI 共用同一热点选中、更新和删除模型；rc261 起，`xomo.hotspot.update` 可更新热点名称、目标 URL 和矩形范围，`xomo.hotspot.export_html` 可将合成画布与热点输出为自包含 HTML image map；文件菜单、MCP 与 CLI 复用同一导出入口。rc260 起，`xomo.hotspot.create`、`xomo.hotspot.list` 和 `xomo.hotspot.delete` 提供 Fireworks 风格矩形热点的创建、查询与删除；热点包含名称、矩形范围和可选目标 URL，并随 `.xomoproject` 保存。

rc242 起，`xomo.layer.list` 的 Figma 图层条目包含 `figmaImageFill`，可读取 IMAGE 填充的源引用、缩放模式、变换、缩放因子、旋转和滤镜参数。

rc249 起，`xomo.figma.image_fill` 可对选中的 Figma IMAGE 填充执行 `action=list` 或 `action=set`。`set` 的 `property` 支持 `scaleMode`（另传 `scaleMode`）、`scalingFactor`、`rotation`、`offsetX`、`offsetY`、`m11`、`m12`、`m21`、`m22`（另传 `value`）和 `filtersEnabled`（另传 `enabled`）。所有写入都进入一次 Xomo History/Undo，并要求项目仍保留源图；它不会把已经烘焙的像素层假装成可编辑 Figma 填充。

## 架构

Xomo MCP 分为两个进程：

- `Xomo.app` 持有真实画布和编辑状态，在 `127.0.0.1` 的随机端口提供本机自动化协议。
- `xomo` 是可独立安装的单文件 CLI；`xomo mcp` 把 MCP JSON-RPC stdio 请求转发到当前运行的 Xomo App。

App 每次启动都会生成新的随机令牌，并以 `0600` 权限写入自身沙盒容器。CLI 只读取当前用户的端点文件；服务拒绝非 loopback 客户端。令牌不会出现在进程参数、MCP 配置和正常日志中。

## 构建与安装 CLI

```bash
scripts/build_xomo_cli_release.sh
dist/xomo-macos-universal install
```

默认安装到 `~/.local/bin/xomo`。也可以指定前缀：

```bash
dist/xomo-macos-universal install /usr/local
```

## CLI

```bash
xomo status
xomo doctor
xomo tools
xomo call xomo.document.get '{}'
xomo call xomo.psd.inspect '{"path":"~/Designs/checkout.psd"}'
xomo call xomo.psd.open '{"path":"~/Designs/checkout.psd"}'
xomo call xomo.psd.save '{"path":"~/Designs/checkout-export.psd"}'
xomo call xomo.export.render '{"format":"png","scope":"selection","scale":2}'
xomo call xomo.tool.select '{"tool":"brush"}'
xomo call xomo.selection.rectangle '{"x":20,"y":20,"width":200,"height":120}'
xomo call xomo.selection.quick_mask '{"action":"toggle"}'
xomo call xomo.selection.quick_mask '{"action":"setTarget","target":"selectedAreas"}'
xomo call xomo.selection.quick_mask '{"action":"paint","points":[{"x":32,"y":32},{"x":96,"y":64}],"reveal":true}'
xomo call xomo.shape.create '{"kind":"rectangle","x":80,"y":80,"width":240,"height":120,"fillColor":{"red":1,"green":0.2,"blue":0.1},"strokeColor":{"red":0.1,"green":0.3,"blue":1},"strokeWidth":4,"cornerRadius":16}'
xomo call xomo.shape.update '{"fillOpacity":0.7,"strokeOpacity":0.9}'
xomo call xomo.shape.update '{"cornerRadii":{"topLeft":8,"topRight":16,"bottomRight":24,"bottomLeft":4}}'
xomo call xomo.shape.update '{"cornerSmoothing":0.75}'
xomo call xomo.shape.update '{"fillKind":"linearGradient","fillGradient":{"stops":[{"position":0,"color":{"red":1,"green":0.2,"blue":0.1}},{"position":0.5,"color":{"red":0.1,"green":1,"blue":0.3}},{"position":1,"color":{"red":0.1,"green":0.3,"blue":1}}],"angle":30,"scale":1,"centerX":0.5,"centerY":0.5}}'
xomo call xomo.shape.update '{"fillKind":"radialGradient","fillGradient":{"startColor":{"red":1,"green":0.8,"blue":0.1},"endColor":{"red":0.1,"green":0.2,"blue":0.8},"scale":0.75,"centerX":0.5,"centerY":0.5}}'
xomo call xomo.component.insert '{"component":"button","theme":"native","x":80,"y":100}'
xomo call xomo.component.tokens '{"action":"get","theme":"chakraUI"}'
xomo call xomo.component.tokens '{"action":"apply"}'
xomo call xomo.component.tokens '{"action":"clear"}'
xomo call xomo.component.tokens '{"action":"refresh"}'
xomo call xomo.component.tokens '{"action":"export","path":"/Users/you/Desktop/chakra.xomotokens.json"}'
xomo call xomo.component.tokens '{"action":"import","path":"/Users/you/Desktop/brand.xomotokens.json"}'
xomo call xomo.figma.bindings '{"action":"list"}'
xomo call xomo.figma.bindings '{"action":"copy"}'
xomo call xomo.view.pan '{"action":"center","x":480,"y":320}'
xomo export ~/Desktop/xomo.png --format png --scope composited --scale 2
xomo project export ~/Desktop/design.xomoproject
xomo project import ~/Desktop/design.xomoproject
xomo import-image ~/Desktop/reference.png --into-selection
```

`xomo call` 的第二个参数必须是 JSON object。对象 ID 可通过 `xomo.layer.list`、`xomo.channel.list`、`xomo.history.list` 和 `xomo.guide.list` 获取。

`xomo.document.get` 返回当前 `canvasOffset` 与 `zoom`；`xomo.view.pan` 的 `nudge` 使用 `dx/dy`，`center` 使用画布坐标 `x/y`，`reset` 清零视口偏移。三种视口操作都只改变显示位置，不写入文档 History。

### 组件主题 Token 自动化

`xomo.component.tokens` 与组件库界面使用同一份序列化逻辑：`action=get` 返回带 `schemaVersion`、主题、来源、颜色和尺寸指标的 JSON；`action=export` 额外要求 `path`，在本机写出 `.xomotokens.json` 文件；`action=import` 从 `path` 严格校验并激活本地 Token 映射；`action=apply` 将当前激活的 Token 应用到选中的 UI 组件，沿用局部覆盖规则并写入一个 Undo/Redo 历史步骤；`action=clear` 清除当前本地映射，同样写入 Undo/Redo，之后可撤销恢复；`action=refresh` 批量刷新所有携带本地 Token 映射的组件，跳过局部覆写并以一个 Undo/Redo 步骤提交，返回 `count`。`theme` 可省略，省略时读取 Xomo 当前组件主题。该工具只读写本机，不会联网或写回 Figma/Sketch。

`xomo.layer.list` 的每个图层同时返回 `figmaVariableBindingCount` 与 `figmaVariableBindings`。后者是稳定数组，每项包含 `id`（`field:variableId`）、`field` 和 `variableId`；没有绑定时返回空数组，不会把 PAT 或远端变量值写入响应。调用时可传 `figmaBindings=all|bound|unbound`，分别返回全部、已绑定或未绑定图层；未知值会被拒绝。

`xomo.figma.bindings` 的 `action=list` 返回当前多选图层的去重绑定（没有绑定时返回空结果），`action=copy` 将同一批变量 ID 按稳定顺序写入本机剪贴板；复制时没有选中绑定或传入未知 action 会明确失败，不会联网或写回 Figma。

## MCP 客户端配置

运行 `xomo mcp-config` 可生成配置片段：

```json
{
  "mcpServers": {
    "xomo": {
      "command": "/Users/you/.local/bin/xomo",
      "args": ["mcp"]
    }
  }
}
```

MCP 服务器实现 `initialize`、`ping`、`tools/list` 和 `tools/call`。当 Xomo 尚未启动时，`tools/list` 仍返回二进制内置目录；真正调用编辑工具时会明确提示启动 Xomo。

## 当前工具范围

- 共 122 个 MCP 工具；同类细粒度操作通过带严格枚举参数的 action 工具组织。
- App 与文档状态
- 预设或自定义画布创建、可编辑文字/形状检查与更新（含纯色/最多 16 个有序色标的线性渐变填充、独立描边、不透明度、线宽、统一/独立四角及超椭圆圆角平滑）、点文字 / 固定宽高段落文字创建和转换、文字框所需高度、溢出诊断与适合内容 / 仅扩高操作，以及详细调整、滤镜和图层样式参数
- 完整 `xomoproject` 项目导入导出；旧 `qpicproject` 文件仍可打开；以及 PNG/JPEG/WebP 等图像图层导入
- 本地 PSD 兼容性检查：返回尺寸、图层/组/蒙版、压缩方式和需要注意的降级项，不修改当前文档
- 本地 PSD 异步打开：`xomo.psd.open` 复用 UI 的后台读取、解码、加载提示、兼容性降级与打开后的 History 入口
- 当前文档 PSD 保存：`xomo.psd.save` 写出分层 PSD，并在返回前重新读取兼容性报告；不改变当前文档或 History
- 28 种编辑器工具选择
- 前景色、背景色、可持久化画笔预设、带硬度/流量/间距与逐点压力曲线控制的画笔与橡皮擦、渐变
- 仿制图章与修复画笔源点、对齐 / 非对齐模式、图层采样范围，以及修补工具的源 / 目标模式、透明度和羽化
- 矩形、椭圆、文字和 UI 组件创建
- 图层查询、选择、创建、删除、复制、命名、显隐、锁定、透明度、混合模式、移动、按可见层级排序、分组、所选组递归展开/折叠、链接、合并、对齐、分布、智能对象、Layer Comps 与几何变换
- 图层蒙版、矢量蒙版、十类图层效果、样式复制粘贴、智能滤镜
- 矩形、椭圆、套索、魔棒、快速选择、全选、反选、颜色范围、相似颜色、扩大颜色、羽化、平滑、像素填充、描边、清除和内容识别填充；颜色类选区支持显式 `tolerance`，图层透明度载入支持 `threshold`（0–255，默认 8），边界类操作支持显式像素参数，并与 UI 控件共用裁剪处理
- Photoshop 风格快速蒙版的状态查询、覆盖目标/颜色/不透明度设置和笔触编辑（`xomo.selection.quick_mask`）
- 系统剪贴板复制、剪切，以及将剪贴板图片粘贴为可编辑图层；Xomo 自有图层剪贴板还支持原位粘贴
- 矢量路径创建、锚点与控制柄、子路径、闭合与反向、填充、描边、选区和蒙版转换
- 独立命名路径的保存、查询、选择、重命名、更新、载入、画布可见性和删除
- Alpha 通道查询、创建、复制、改名、删除及选择布尔运算
- 历史状态、撤销、重做、截断、恢复与命名快照
- 图像尺寸、画布尺寸、裁切、缩放、参考线与网格
- 画布视口平移、按画布坐标居中和视口重置（`xomo.view.pan`），不改文档 History
- 22 类可编辑 UI 组件与七套主题
- UI 组件主组件、实例链接、主题同步和解除链接（`xomo.component.instance`）
- Figma 链接安全校验与规范化（`xomo.figma.link`），不联网、不存储凭据，并返回导入范围与清洗计数
- PNG、JPEG、WebP、PDF、SVG、PSD 渲染导出

`xomo.layer.rasterize` 的 `target` 接受 `type`、`shape`、`fillContent`、`vectorMask`、`smartObject`、`layerStyle` 或 `layer`。普通内容目标只转换所选内容；`layerStyle` 会把样式以及位于样式之前的蒙版、智能滤镜、填充透明度和本图层 Blend If 烘焙为像素，但保留名称、层级、图层不透明度、混合模式、下层 Blend If 与剪贴关系。多选会跳过锁定或类型不匹配的图层，并把整批转换记为一个 History/Undo 步骤。

`xomo.layer.style` 的 `hideSelected`、`showSelected`、`hideAll` 与 `showAll` 动作用于临时隐藏或恢复效果而不清除样式配置；`xomo.layer.style_settings property=effectScale value=<1...1000>` 以百分比设置所选未锁定样式层的绝对效果比例。显隐与缩放分别进入一个 History/Undo 步骤，旧项目缺少字段时按显示与 100% 读取。

`xomo.layer.style` 的 `presetList`、`presetCreate`、`presetApply` 与 `presetDelete` 动作管理跨会话自定义样式预设；创建时可传 `name`，应用或删除时传返回的 `id`。返回值包含预设 ID、标题、是否匹配当前图层、效果缩放百分比和启用的效果清单。应用到多选时跳过锁定或不支持样式的图层并只记录一个 History/Undo 步骤，创建和删除则只修改工作区预设。

`xomo.layer.style` 的 `presetRename` 使用 `id` 与 `name` 重命名，`presetMove` 使用 `id` 与 `direction=top|up|down|bottom` 排序；`presetExport path=<本地 .xomostyles 路径>` 导出全部预设，附带 `id` 时仅导出该项。`presetImportPreview path=<路径>` 只读返回总数、可导入、重复、容量不足、跳过总数和逐项处理结果，不修改工作区；确认摘要后再调用 `presetImport path=<路径>` 执行写入。导入项会获得新的本机 ID，并按名称与完整样式去重；管理和文件操作均不进入文档 History。

`xomo.layer.style` 的 `presetCatalog` 返回 6 个稳定 ID 的内置经典样式，结果中的 `builtIn=true` 表示只读内置项；`presetApply id=<内置或自定义 ID>` 可直接应用任一来源，`presetDuplicate id=<ID>` 会把完整样式复制成可重命名、排序和导出的自定义项。图形界面的样式菜单与管理器使用相同目录，并由真实图层效果合成器生成缩略图。

`xomo.layer.style` 的 `presetFavorite id=<ID> favorite=<true|false>` 切换内置或自定义预设的收藏状态，`presetFavorites` 与 `presetRecent` 分别返回收藏列表和最多 8 项、最新优先的最近使用列表；目录项同时包含 `favorite`、`recent` 标记。收藏与最近记录跨会话保存但不进入文档 History，删除自定义预设会同步移除失效记录。

`xomo.path.saved` 的 `action` 接受 `list`、`save`、`select`、`rename`、`duplicate`、`moveUp`、`moveDown`、`moveToTop`、`moveToBottom`、`moveToIndex`、`update`、`load`、`selection`、`fill`、`stroke`、`visibility` 或 `delete`。`save` 可选 `name`，其余写操作通过 `id` 定位，`rename` 另需 `name`，`visibility` 另需 `visible`，`moveToIndex` 另需零基整数 `index`；结果返回路径的零基索引、ID、名称、选中状态、固定可见状态、当前轮廓可见状态、闭合状态、锚点数以及画布坐标下的完整子路径。保存项是独立快照：删除源图层不会丢失路径，`load` 会生成新的可编辑路径图层，只有显式 `update` 才会用当前路径改写保存项。`duplicate` 不经过系统剪贴板创建紧邻原项的独立副本。四个方向 `move` 动作调整列表和固定轮廓绘制顺序；`moveToIndex` 可一次到达确切位置。所有排序都保持选择并形成单步 Undo/Redo，边界、同位置、小数、负数和越界索引明确失败且不写 History。`selection` 从闭合路径直接建立选区，遵守当前替换/相加/相减/相交模式，不创建或切换图层；开放路径会被拒绝。`fill` 用当前前景色和不透明度填充闭合路径，`stroke` 用当前画笔宽度描边开放或闭合路径，两者都写入当前选中的可编辑像素层并尊重透明像素锁。`visibility` 固定或取消固定该路径的非破坏画布轮廓，不写入 History；选中的路径即使未固定也会临时显示。

`xomo.mask.action` 的 `apply` 只永久应用栅格图层蒙版，`applyVector` 只永久应用矢量蒙版，`rasterizeVector` 则把矢量蒙版转换成仍可编辑的栅格图层蒙版。三者不会再互相冒名顶替；智能对象须先通过 `xomo.layer.rasterize` 的 `smartObject` 目标转成像素层，才能永久应用蒙版。

`xomo.layer.order` 的 `direction` 接受 `top`、`up`、`down`、`bottom`。自动化没有图层面板的临时搜索上下文，因此按当前展开/折叠状态下的完整可见层级排序；折叠组会作为完整子树移动，整次调用只产生一个 History/Undo 步骤。

`xomo.layer.group` 会把所选可编辑项目整理为连续图层子树：锁定项留在原位置并保持选中，显式选中的组内后代会提升为新组的直接成员，未选中的后代分支保持原结构。`xomo.layer.ungroup` 可一次处理嵌套所选组，跳过锁定组并保留无关选择；两者均只产生一个 History/Undo 步骤。

`xomo.layer.action` 的 `moveIntoGroup` 会寻找选择上方同层级的下一个可编辑组，并把可编辑所选根及完整组子树连续放到该组顶部；`moveOutOfGroup` 则把每个子树放到各自原父组的正上方，可一次处理多个嵌套父组。锁定选择保持原位，两种操作都保留选择并只增加一个 History/Undo 步骤。

`xomo.layer.merge_visible`、`xomo.layer.stamp_visible`、`xomo.layer.stamp_selected` 与 `xomo.layer.flatten` 共用 App 内的层级合成入口：不会切开图层组，盖印保留源结构，合并可见保留隐藏子树，拼合会输出白色不透明且锁定的背景层。

`xomo.layer.duplicate` 会把显式选择按原父级分簇，并复制所选组的完整嵌套子树。同父级副本保持原相对顺序，不同父组分别在各自边界落位；父组 ID、显式选择、主选择和副本内部链接使用统一的新 ID 映射。剪贴链副本优先绑定副本基底，复制基底不会改变原链，孤立剪贴副本会转为普通图层；整次调用只增加一个 History/Undo 步骤。

`xomo.layer.delete` 会删除可编辑的显式选择；所选组会携带完整嵌套子树，受自身或祖先锁定影响的选择会保留。删除后优先保留仍可见的锁定选择，否则按删除前图层面板的可见顺序选择下方、再选择上方；幸存图层会清理已删链接，失去原基底的剪贴层会解除剪贴而不改绑。整次调用只增加一个 History/Undo 步骤，并且不会删除文档最后一个图层。

`xomo.layer.merge_down` 只把当前可见图层与同父级紧邻下方的像素层合并；当前选择为组时，改为压平该组的完整嵌套子树。`xomo.layer.merge_selected` 合并同父级的可编辑所选分支，组会携带全部后代，锁定选择保持原位；跨父级、含锁定后代的组或不安全目标会被拒绝。两者都会重建外部链接和可安全延续的剪贴基底，并且只增加一个 History/Undo 步骤。

## 边界

- MCP 操作当前活动编辑器窗口，不在后台偷偷创建不可见文档。
- 涉及系统文件选择器的菜单命令不直接远程点击；CLI 通过编码数据与 App 交换，再由 CLI 在用户指定路径读写项目、图像和导出文件，保持沙盒边界清晰。
- 第一版不开放局域网、远程 TCP 或固定长期令牌。
