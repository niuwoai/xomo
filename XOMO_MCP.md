# Xomo MCP 与 CLI

> 当前版本：v2.12.0-rc118

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
xomo call xomo.tool.select '{"tool":"brush"}'
xomo call xomo.selection.rectangle '{"x":20,"y":20,"width":200,"height":120}'
xomo call xomo.shape.create '{"kind":"rectangle","x":80,"y":80,"width":240,"height":120,"fillColor":{"red":1,"green":0.2,"blue":0.1},"strokeColor":{"red":0.1,"green":0.3,"blue":1},"strokeWidth":4,"cornerRadius":16}'
xomo call xomo.shape.update '{"fillOpacity":0.7,"strokeOpacity":0.9}'
xomo call xomo.shape.update '{"cornerRadii":{"topLeft":8,"topRight":16,"bottomRight":24,"bottomLeft":4}}'
xomo call xomo.shape.update '{"cornerSmoothing":0.75}'
xomo call xomo.shape.update '{"fillKind":"linearGradient","fillGradient":{"stops":[{"position":0,"color":{"red":1,"green":0.2,"blue":0.1}},{"position":0.5,"color":{"red":0.1,"green":1,"blue":0.3}},{"position":1,"color":{"red":0.1,"green":0.3,"blue":1}}],"angle":30,"scale":1,"centerX":0.5,"centerY":0.5}}'
xomo call xomo.shape.update '{"fillKind":"radialGradient","fillGradient":{"startColor":{"red":1,"green":0.8,"blue":0.1},"endColor":{"red":0.1,"green":0.2,"blue":0.8},"scale":0.75,"centerX":0.5,"centerY":0.5}}'
xomo call xomo.component.insert '{"component":"button","theme":"native","x":80,"y":100}'
xomo call xomo.component.tokens '{"action":"get","theme":"chakraUI"}'
xomo call xomo.component.tokens '{"action":"export","path":"/Users/you/Desktop/chakra.xomotokens.json"}'
xomo export ~/Desktop/xomo.png --format png --scope composited --scale 2
xomo project export ~/Desktop/design.qpicproject
xomo project import ~/Desktop/design.qpicproject
xomo import-image ~/Desktop/reference.png --into-selection
```

`xomo call` 的第二个参数必须是 JSON object。对象 ID 可通过 `xomo.layer.list`、`xomo.channel.list`、`xomo.history.list` 和 `xomo.guide.list` 获取。

### 组件主题 Token 自动化

`xomo.component.tokens` 与组件库界面使用同一份序列化逻辑：`action=get` 返回带 `schemaVersion`、主题、来源、颜色和尺寸指标的 JSON；`action=export` 额外要求 `path`，在本机写出 `.xomotokens.json` 文件。`theme` 可省略，省略时读取 Xomo 当前组件主题。该工具只读写本机，不会联网或写回 Figma/Sketch。

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

- 共 113 个 MCP 工具；同类细粒度操作通过带严格枚举参数的 action 工具组织。
- App 与文档状态
- 预设或自定义画布创建、可编辑文字/形状检查与更新（含纯色/最多 16 个有序色标的线性渐变填充、独立描边、不透明度、线宽、统一/独立四角及超椭圆圆角平滑）、点文字 / 固定宽高段落文字创建和转换、文字框所需高度、溢出诊断与适合内容 / 仅扩高操作，以及详细调整、滤镜和图层样式参数
- 完整 `qpicproject` 项目导入导出，以及 PNG/JPEG/WebP 等图像图层导入
- 28 种编辑器工具选择
- 前景色、背景色、可持久化画笔预设、带硬度/流量/间距与逐点压力曲线控制的画笔与橡皮擦、渐变
- 仿制图章与修复画笔源点、对齐 / 非对齐模式、图层采样范围，以及修补工具的源 / 目标模式、透明度和羽化
- 矩形、椭圆、文字和 UI 组件创建
- 图层查询、选择、创建、删除、复制、命名、显隐、锁定、透明度、混合模式、移动、按可见层级排序、分组、所选组递归展开/折叠、链接、合并、对齐、分布、智能对象、Layer Comps 与几何变换
- 图层蒙版、矢量蒙版、十类图层效果、样式复制粘贴、智能滤镜
- 矩形、椭圆、套索、魔棒、快速选择、全选、反选、羽化、平滑、像素填充、描边、清除和内容识别填充
- 系统剪贴板复制、剪切，以及将剪贴板图片粘贴为可编辑图层
- 矢量路径创建、锚点与控制柄、子路径、闭合与反向、填充、描边、选区和蒙版转换
- 独立命名路径的保存、查询、选择、重命名、更新、载入、画布可见性和删除
- Alpha 通道查询、创建、复制、改名、删除及选择布尔运算
- 历史状态、撤销、重做、截断、恢复与命名快照
- 图像尺寸、画布尺寸、裁切、缩放、参考线与网格
- 22 类可编辑 UI 组件与七套主题
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
