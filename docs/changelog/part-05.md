
## 2.12.0-rc217 - 2026-07-18

### Added
- 图层菜单和图层面板更多操作接入智能对象“替换内容、让实例独立、重置变换”，复用已有多实例、Undo/Redo 与本地化业务入口。

### Verification
- 顶部“图层”菜单契约通过 1/1，报告：`test-reports/rc217-smart-object-menu/report.md`。
- 图层面板更多操作契约通过 1/1，报告：`test-reports/rc217-smart-object-panel/report.md`。

## 2.12.0-rc216 - 2026-07-17

### Added
- 含 Photoshop `SoLd`/`PlLd` 标记的 PSD 图层现在导入为 Xomo 原生智能对象栅格回退；不伪称保留嵌入源，但变换、智能滤镜和项目往返继续保持非破坏语义。

### Verification
- `ImageEditorPSDTests` 定向回归通过 23/23，覆盖外部智能对象夹具的原生回退、兼容性报告与项目往返，报告：`test-reports/rc216-psd-smart-object/report.md`。

## 2.12.0-rc215 - 2026-07-17

### Added
- 移动工具按住 `Command` 点击组件时可进入组件内部最上方实际可见的子图层；普通点击仍选择 Xomo 组件整体，透明子图层不会拦截深层选择。

### Verification
- 带 rc215 构建的 `XomoCanvasObjectTests` 回归通过 27/27，覆盖组件 Command 深选、普通图层命中、Shift 多选、Option 复制移动、透明孔洞和移动预览，报告：`test-reports/rc215-deep-selection-final/report.md`。
- 移动手势接线契约通过 1/1，确认 Command 深选不会误启动移动，报告：`test-reports/rc215-deep-selection-contract/report.md`。

## 2.12.0-rc214 - 2026-07-17

### Changed
- 移动工具按住 `Option` 时显示带复制标记的四向移动光标，明确提示即将进行复制拖动；组件库模式仍使用系统箭头。

### Verification
- `ImageEditorCanvasCursorTests` 回归与带 rc214 构建通过，覆盖组件库箭头、画布外箭头、工具语义光标、Option 复制标记与缩放修饰状态，报告：`test-reports/rc214-cursor-final/report.md`。

## 2.12.0-rc213 - 2026-07-17

### Added
- 移动工具在画布上按住 `Option` 拖动时复制当前可见图层或 Xomo 组件，并把复制与移动合并为一次可撤销操作；普通拖动、`Shift` 多选和空白平移保持不变。

### Verification
- 带 rc213 构建的 `XomoCanvasObjectTests` 回归通过 26/26，覆盖组件与普通图层 Option 复制移动、单步 Undo、联合选择框、Shift 选择、透明命中与移动预览，报告：`test-reports/rc213-final-build/report.md`。
- 画布手势接线契约通过 1/1，确认 Option 克隆状态与 Shift 选择状态互不串线，报告：`test-reports/rc213-option-drag-contract/report.md`。

## 2.12.0-rc212 - 2026-07-17

### Added
- 移动工具在画布上支持 `Shift` 追加或切换普通图层与 Xomo 组件对象选择；追加选择只改变选择集合，不启动拖动，空白处仍可平移画布。

### Verification
- 带 rc212 版本号的 `XomoCanvasObjectTests` 构建与回归通过 24/24，覆盖普通图层追加/切换、组件组追加、组件联合选中框、透明孔洞、命中、移动预览与吸附，报告：`test-reports/rc212-final-build/report.md`。
- 画布手势接线契约通过 1/1，确认 `Shift` 选择状态不会被 `DragGesture` 重复切换，报告：`test-reports/rc212-canvas-selection-contract/report.md`。

## 2.12.0-rc211 - 2026-07-17

### Added
- 移动工具现在可以直接从画布按实际可见像素选中最上层普通图层；组件子图层仍归属 Xomo 对象，透明孔洞和空白处不会错误拦截画布平移。

### Verification
- 普通图层画布命中专项通过 1/1，报告：`test-reports/rc211-canvas-layer-hit-escalated/report.md`。
- 完整 `XomoCanvasObjectTests` 回归通过 21/21，覆盖组件命中、透明孔洞、移动预览/吸附和新普通图层命中，报告：`test-reports/rc211-canvas-object-regression/report.md`。
- 移动工具手势接线契约通过 1/1，确认画布拖动入口复用普通图层命中逻辑，报告：`test-reports/rc211-canvas-layer-contract-escalated/report.md`。

## 2.12.0-rc210 - 2026-07-17

### Changed
- 工具光标仅在可绘制画布内显示语义图形；画布外深色工作区恢复系统箭头，平移手势进行中仍显示闭合手掌。

### Verification
- rc210 光标专项构建通过 1/1；`toolCursorFallsBackToSystemArrowOutsideDrawableCanvas` 通过 1/1，报告：`test-reports/rc210-canvas-cursor-escalated/report.md`。
- 完整 `ImageEditorCanvasCursorTests` 回归通过 11/11，报告：`test-reports/rc210-canvas-cursor-regression/report.md`。

## 2.12.0-rc209 - 2026-07-17

### Changed
- 复制所选图层、图层组或多选到剪贴板时自动裁切到实际非透明内容边界，避免小组件携带整张画布；仍保持透明 PNG 与 History 不变。

### Verification
- rc209 专项构建通过 1/1；紧凑边界回归报告：`test-reports/rc209-clipboard-bounds/report.md`。
- `Command+A`/无选区时的图层剪贴板回退通过 1/1；报告：`test-reports/rc209-clipboard-fallback-escalated/report.md`。

## 2.12.0-rc208 - 2026-07-17

### Changed
- 标准复制（`⌘C`）在有选区时复制选区、无选区时复制当前所选图层；复制菜单不再在无选区时无故禁用，保留透明度与 History 不变。

### Verification
- 无选区复制所选图层功能专项 1/1 通过；rc207 的多图层复制、菜单、快捷键和 MCP/CLI schema 回归继续保留。

## 2.12.0-rc207 - 2026-07-17

### Added
- 编辑菜单新增“复制所选图层到剪贴板”（`⌘⌥⇧C`），单层、图层组和多选统一输出带透明度的 PNG；MCP/CLI 剪贴板动作同步支持 `copySelectedLayers`。

### Verification
- 复制所选图层不写入 History；功能专项 1/1、编辑菜单 1/1、快捷键 1/1、MCP/CLI schema 1/1 通过，报告见 `test-reports/rc207-selected-layer-clipboard/`、`rc207-menu/`、`rc207-shortcut/` 与 `rc207-automation/`。

## 2.12.0-rc206 - 2026-07-17

### Added
- 图层面板的每一行新增右键“导出所选图层…”动作；未选中行会先切换到该图层，随后复用单层、组或多选导出范围，不再要求用户回到文件菜单。

### Verification
- 图层行导出动作契约专项 1/1 通过；rc205 的导出范围模型 5/5 与文件菜单 1/1 继续作为回归证据。

## 2.12.0-rc205 - 2026-07-17

### Added
- 文件菜单新增“导出所选图层”（`⌘⌥L`）：单个可编辑图层使用单层范围，图层组或多选使用所选图层范围；没有可导出图层时自动禁用。

### Verification
- 所选图层导出范围模型专项 5/5、文件菜单专项 1/1 通过；rc205 按每 5 个小版本门禁完成全新 macOS 13 Debug 构建并成功。

## 2.12.0-rc204 - 2026-07-17

### Added
- 文件菜单新增“导出选区 / 切片”（`⌘⌥E`）：有选区时直接以 selection 范围打开导出面板，无选区时自动禁用，减少重复打开面板的操作。

### Verification
- 文件菜单专项 1/1 通过；rc203 的选区切片专项 1/1 与导出格式回归 4/4 继续通过。

## 2.12.0-rc203 - 2026-07-17

### Added
- 导出范围新增“选区 / 切片”：按当前选区边界导出 PNG、JPEG、WebP 或 PDF，非矩形选区外保留透明，自动化 `xomo.export.render` 同步接受 `selection`。

### Verification
- 选区切片专项 1/1、既有导出格式回归 4/4 通过；报告见 `test-reports/rc203-selection-slice/` 与 `test-reports/rc203-export-regression/`。

## 2.12.0-rc202 - 2026-07-17

### Added
- 文件菜单新增“从剪贴板新建画布”，支持 `⌘⌥N`，按剪贴板图片的实际像素尺寸创建独立画布，并重置工具、缩放、历史和 PSD 兼容状态。

### Verification
- 剪贴板新建画布专项 1/1、文件菜单契约专项 1/1 通过；保留报告：`test-reports/rc202-clipboard-canvas/` 与 `test-reports/rc202-clipboard-menu/`。

## 2.12.0-rc201 - 2026-07-17

### Changed
- 项目文件品牌收敛为 `.xomoproject`：新保存和自动化导出使用 Xomo 扩展名，旧 `.qpicproject` 文件继续可打开，避免产品更名造成已有项目失效。
- 版本记录、MCP/CLI 示例和组件库文档同步到 rc201。

### Verification
- 项目格式专项 9/9、Finder/UTI 注册专项 4/4、自动化回归 51/51 通过；rc201 Debug 测试产品构建与 CLI 2/2 通过。

## 2.12.0-rc200 - 2026-07-17

### Changed
- 完成第 200 个小版本质量门禁：全量隔离测试 984/984（jobs=4）通过，CLI 2/2 通过，双架构 Release App/CLI、版本/Bundle ID/macOS 13.0/adhoc runtime 签名核对通过。
- 启动 Release App 并完成组件库切换、组件插入和可编辑图层生成冒烟；已覆盖安装 `/Applications/Xomo.app`。
- 保留全量门禁报告：`test-reports/rc200-full-suite/report.json` 与 `report.md`。

## 2.12.0-rc199 - 2026-07-17

### Added
- 将独立生成的 `unsupported-features.psd` 外部夹具接入 `xomo.psd.inspect` 自动化回归，验证尺寸、图层数和文字/智能对象/未知混合模式降级报告。

## 2.12.0-rc198 - 2026-07-17

### Added
- 新增 `xomo.psd.save` MCP/CLI 工具，将当前分层文档写出 PSD，并在返回前验证尺寸、图层数量和兼容性报告。
- PSD 自动化保存支持路径扩展名、目标类型和 512 MB 大小校验，保存不修改当前文档或 History。

## 2.12.0-rc197 - 2026-07-17

### Added
- 新增 `xomo.psd.open` MCP/CLI 工具，异步复用 UI 的 PSD 加载协调器，支持后台解码、兼容性降级、加载提示与打开后的 History 语义。
- 为 PSD 自动化打开增加路径、常规文件与 512 MB 大小校验，避免无效请求阻塞编辑器。

## 2.12.0-rc196 - 2026-07-17

### Added
- 新增 `xomo.psd.inspect` MCP/CLI 工具，可在不导入或修改当前文档的情况下读取本地 PSD 兼容性报告。

### Verification
- PSD 检查正向/扩展名拒绝测试 1/1、MCP 工具目录测试 1/1、`xomo-cli` 测试 2/2 通过；macOS 13 Debug 测试产品构建通过。

## 2.12.0-rc195 - 2026-07-17

### Added
- PSD 导出现在会在 Raw、PackBits RLE、ZIP 与 ZIP Prediction 之间自动择优；对平滑渐变按行预测后再压缩，失败或无收益时安全回退。

### Verification
- PSD 压缩定向测试 8/8、完整 PSD 专项 24/24、CLI 2/2 通过；渐变样本兼容性报告确认实际写出 ZIP Prediction。

## 2.12.0-rc194 - 2026-07-17

### Added
- PSD 导出在 Raw 与 PackBits RLE 之外支持 ZIP（zlib）自动择优；压缩无收益或失败时回退到更安全的编码。

### Verification
- PSD Raw/RLE/ZIP 导出与图层/复合图像往返定向测试 7/7 通过，完整 PSD 专项 23/23 通过；兼容性报告确认交替像素样本实际写出 ZIP。

## 2.12.0-rc193 - 2026-07-17

### Added
- PSD 导出现在会对可压缩的图层与复合通道使用 PackBits RLE；压缩无收益或行长度超限时自动回退 Raw，保持安全兼容。

### Verification
- PSD RLE 导出与图层/复合图像往返定向测试 6/6 通过；macOS 13 独立测试产品构建通过。

## 2.12.0-rc192 - 2026-07-17

### Added
- 新增 `xomo.view.pan` MCP/CLI 工具，可按增量平移、按画布坐标居中或重置视口，并返回当前偏移与缩放。
- `xomo.document.get` 现在返回当前画布视口偏移，便于自动化客户端核对导航状态。

### Verification
- MCP/CLI 注册与视口操作回归测试 47/47 通过；视口操作不增加文档 History。

## 2.12.0-rc191 - 2026-07-17

### Added
- 导航器缩略图现在显示当前缩放/平移后的真实画布视口，点击或拖动缩略图可把目标位置居中到画布。

### Verification
- 导航器几何、居中不污染 History、界面连线测试 3/3 通过；macOS 13 独立测试产品构建通过。

## 2.12.0-rc190 - 2026-07-17

### Added
- 新增 `xomo.selection.quick_mask` MCP/CLI 工具：可查询快速蒙版状态、切换模式、设置覆盖目标/颜色/不透明度，并使用与 UI 相同的画笔路径编辑选区。

### Verification
- `registryControlsQuickMaskThroughTheSharedSelectionPath` 1/1、CLI 测试 2/2、macOS 13 Debug `build-for-testing` 通过；测试运行器在授权环境中重跑成功。

## 2.12.0-rc189 - 2026-07-17

### Fixed
- 修正菜单和 `Command+F` 的“上次滤镜”语义：现在记录上一次成功应用的滤镜、强度与专属参数，重复时不受当前滤镜面板选择影响；没有可重复滤镜时给出明确提示。

### Verification
- `commandFRepeatsTheLastSuccessfulFilterAndItsParameters` 1/1、`LocalizationResourceTests` 4/4、CLI 测试 2/2，以及 macOS 13 Debug `build-for-testing` 通过。

## 2.12.0-rc188 - 2026-07-17

### Added
- 新增 `xomo.figma.link` MCP/CLI 工具，在不联网、不保存凭据的前提下校验并规范化 Figma 链接，返回资源类型、文件身份、节点选择器、导入范围与清洗计数。

### Verification
- Figma 链接自动化正向与拒绝契约、工具目录和 SwiftPM CLI 测试通过；完整 macOS 13 构建仍按 20 版门禁执行。

## 2.12.0-rc187 - 2026-07-17

### Added
- 新增 `xomo.component.instance` MCP/CLI 工具，支持把 UI 组件设为主组件、链接实例、同步主组件主题并解除实例链接；自动化入口与组件库 UI 共用实例模型和 Undo/Redo。

### Fixed
- 修正 MCP 工具总数文档，将当前工具数从 114 更新为 116。

### Verification
- `XomoAutomationTests` 44/44（含组件实例正向与失败契约）、SwiftPM CLI 测试 2/2，以及 macOS 13 Debug `build-for-testing` 通过。

## 2.12.0-rc186 - 2026-07-17

### Added
- 新增 `xomo.figma.component_properties` MCP/CLI 工具，支持读取、设置和还原当前选中图层的 Figma 组件属性，并复用 UI 的本地覆盖与 Undo/Redo 语义。

### Verification
- Figma 自动化专项测试 42/42、空文本属性边界测试 1/1、macOS 13 Debug `build-for-testing`、SwiftPM CLI 测试 2/2 通过。

## 2.12.0-rc185 - 2026-07-17

### Added
- Figma 组件属性导入时保留默认值快照，属性面板支持单项还原；还原会同步真实文字子图层，并进入 History/Undo/Redo。

### Verification
- Figma 组件属性专项独立进程测试 3/3、macOS 13 Debug `build-for-testing`、SwiftPM CLI 测试 2/2 通过。

## 2.12.0-rc184 - 2026-07-17

### Changed
- Figma 文本组件属性覆盖现在同步更新导入组件组内匹配的可编辑文字图层；找不到安全匹配时只更新元数据，不猜测其它图层。

### Verification
- Figma 文本组件覆盖专项独立进程测试 3/3、macOS 13 Debug `build-for-testing`、SwiftPM CLI 测试 2/2 通过。

## 2.12.0-rc183 - 2026-07-17

### Fixed
- 修复组件库插入或选中对象后画布仍保留上一次工具语义指针的问题；组件库模式现在立即恢复系统箭头。

### Verification
- 组件库与画布指针专项独立进程测试 43/43，语义指针测试 10/10，macOS 13 Debug `build-for-testing`，SwiftPM CLI 测试 2/2 通过。

## 2.12.0-rc182 - 2026-07-17

### Added
- Figma 组件属性支持本地覆盖编辑：布尔属性使用开关，变体/实例替换使用首选值菜单，文本属性可编辑；每次覆盖进入 Xomo History/Undo/Redo，不向 Figma 云端写回。

### Verification
- Figma 组件属性专项独立进程测试 69/69、本地化资源测试 4/4、macOS 13 Debug `build-for-testing`、SwiftPM CLI 测试 2/2 通过。

## 2.12.0-rc181 - 2026-07-17

### Added
- Figma 导入图层保留组件属性元数据（变体、布尔、文本和实例替换等），属性面板可查看并复制结构化 JSON，项目保存重开继续保留。

### Verification
- Figma 专项独立进程测试 68/68、本地化资源测试 4/4、macOS 13 Debug `build-for-testing`、SwiftPM CLI 测试 2/2 通过。

## 2.12.0-rc180 - 2026-07-17

### Verification
- 完成第 180 个小版本质量门禁：独立进程全量测试 965/965、CLI 测试 2/2、arm64/x86_64 通用 Release App 与 CLI 构建、安装版启动和组件库插入冒烟均通过；已覆盖安装 `/Applications/Xomo.app`。

## 2.12.0-rc179 - 2026-07-17

### Added
- Figma 导入图层保留清洗后的规范源链接，属性面板可直接复制链接回到 Figma 对应节点。

### Verification
- Figma 导入与源链接专项 30/30 通过；本地化资源专项通过；`XomoMCPServerTests` CLI 2/2 通过。

## 2.12.0-rc178 - 2026-07-17

### Added
- Figma `COMPONENT`、`COMPONENT_SET`、`INSTANCE` 导入层现在保留独立的组件角色元数据；属性面板会显示该语义，同时继续按可编辑组参与 Photoshop 式图层操作。

### Verification
- Figma 导入与源节点属性专项 30/30 通过；`XomoMCPServerTests` CLI 2/2 通过。

## 2.12.0-rc177 - 2026-07-17

### Added
- 属性面板现在显示选中 Figma 图层的源节点类型与 ID，并支持复制 `节点类型:节点 ID` 引用，方便从设计稿回溯来源。

### Changed
- 校正 rc173、rc175、rc176 的 Figma 专项报告计数，使报告包含 `@Test nonisolated` 测试。

### Verification
- Figma 相关专项合计 30/30 通过；`XomoMCPServerTests` CLI 2/2 通过。

## 2.12.0-rc176 - 2026-07-17

### Added
- Figma 导入图层现在保留源节点 ID 与节点类型，并随 Xomo 项目保存、重开，给后续组件语义和源节点回溯留出稳定锚点。

### Verification
- Figma 节点导入专项 30/30 通过（含源节点属性专项）；`XomoMCPServerTests` CLI 2/2 通过。

## 2.12.0-rc175 - 2026-07-17

### Added
- Figma `BOOLEAN_OPERATION` 节点现在使用最终几何路径导入为可编辑矢量，并明确标记为“已展平”，同时不再重复生成布尔运算的源子图层。

### Verification
- Figma 节点导入专项 29/29 通过；`XomoMCPServerTests` CLI 2/2 通过。

## 2.12.0-rc174 - 2026-07-17

### Fixed
- 补齐 PSD 剪贴蒙版链的完整回归覆盖：导出、重新导入以及项目保存重开都会保留连续剪贴层、基底关系、透明度和选择状态。

### Verification
- PSD 专项 19/19 通过；`XomoMCPServerTests` CLI 2/2 通过。

## 2.12.0-rc173 - 2026-07-17

### Added
- Figma `SECTION` 节点现在按可编辑组导入，并保留其线性/径向渐变背景，不再被错误标记为不支持节点。

### Verification
- Figma 节点导入专项 28/28 通过；`XomoMCPServerTests` CLI 2/2 通过。

## 2.12.0-rc172 - 2026-07-17

### Fixed
- 修复 PSD 栅格蒙版导出经过 AppKit 重绘导致透明度被混合的问题，改为使用 Core Graphics 无插值逐像素提取 alpha，复杂蒙版现在可以精确往返。

### Verification
- PSD 套件 18/18 通过；复杂蒙版 alpha 交替 255/0 数据精确恢复。

## 2.12.0-rc171 - 2026-07-17

### Fixed
- 修复 PSD ZIP 通道解码未去除标准两字节 zlib 头导致的 `.invalidFile`，外部 ZIP 合成与 ZIP 组蒙版现在可以进入解码流程。

### Verification
- 外部 ZIP 合成与 ZIP 组/蒙版通过；PSD 套件为 17/18，剩余 1 项为复杂蒙版 alpha 往返问题。

## 2.12.0-rc170 - 2026-07-17

### Fixed
- 修复 PSD EngineData UTF-16 字符串以单字节 `)` 结束时的解析偏移，字体名不再吞入后续 `/FontFamily` 与 `/FontStyle` 字段。

### Verification
- 基础文字层导出与外部文字夹具的字体名断言恢复通过；其余 PSD 兼容性问题继续单独跟踪。

## 2.12.0-rc169 - 2026-07-17

### Fixed
- 修复 PSD `vmsk`/`vsms` 矢量蒙版子路径长度记录少写 2 个保留字节导致导入偏移的错误。
- 同步修正矢量蒙版兼容性夹具，单子路径、多子路径孔洞与路径资源均可恢复为可编辑模型并完成项目往返。

### Verification
- 矢量蒙版与路径资源相关 PSD 测试 4/4 通过；PSD 套件当前为 13/18，剩余 5 项为既有文字、ZIP 和复杂蒙版问题。
- Xomo MCP/CLI 测试 2/2 通过。

## 2.12.0-rc168 - 2026-07-17

### Fixed
- 修复 PSD Path Resource 长度记录少写 2 个保留字节导致命名路径无法导入和导出的错误。
- 同步修正独立 PSD 夹具生成器和二进制夹具，闭合/开放命名路径可恢复并完成项目往返。

### Verification
- 命名路径导出与外部路径资源往返测试通过；PSD 套件当前为 10/18，剩余失败已记录为无关的文字、矢量蒙版和复杂蒙版回归。

## 2.12.0-rc167 - 2026-07-17

### Changed
- 组件库切换时立即恢复系统箭头，不再继承上一个工具的笔刷、选区或缩放指针；画布平移仍使用抓手。
- 将画布光标解析集中为组件库、具体工具和平移三种交互状态，继续为每个工具提供语义化指针。

### Verification
- 光标定向测试 10/10 通过，Debug `build-for-testing` 通过。

## 2.12.0-rc166 - 2026-07-17

### Added
- PSD 额外通道现在读取并写回 DisplayInfo（1077）中的 Spot 模式、色彩空间、颜色分量和不透明度，专色通道可在项目格式与 PSD 之间往返。
- 额外 Alpha 与 Spot 通道不再被兼容性报告误标为未导入内容，并新增专色元数据往返测试。

## 2.12.0-rc165 - 2026-07-17

### Added
- Figma `BACKGROUND_BLUR` 导入为作用于图层背后的非破坏高斯模糊，保留半径、项目往返和背景采样语义；`LAYER_BLUR` 与阴影效果继续可编辑。
- 新增背景模糊渲染与 Figma 计划/材质化回归测试。

## 2.12.0-rc164 - 2026-07-17

### Added
- Figma `LAYER_BLUR` 导入为可调半径的非破坏高斯模糊，并随项目保存；`BACKGROUND_BLUR` 仍保留明确的降级提示。

## 2.12.0-rc163 - 2026-07-17

### Added
- Figma Drop Shadow 与 Inner Shadow 导入为可编辑的 Xomo 图层效果；未支持的效果继续在导入计划中标记为扁平化。

## 2.12.0-rc162 - 2026-07-17

### Added
- Figma `strokeAlign` 现在映射为 Shape 的 inside/center/outside 描边位置，属性面板可直接修改，并沿用 Undo/Redo 与项目存档。
- 新增描边位置导入、渲染、项目往返和控件回归覆盖。

### Verification
- Shape 专项与 Figma 描边位置定向测试均完成 `build-for-testing` 编译；隔离运行器受当前宿主 `testmanagerd` 限制无法采集断言，结果保留在 `test-reports/rc162-shape-style` 与 `test-reports/rc162-figma-stroke`。
- Xomo CLI 测试 2/2 通过。
- `git diff --check` 通过。

## 2.12.0-rc161 - 2026-07-17

### Added
- Shape 属性面板现在可以直接编辑描边端点、连接方式和虚线预设；导入的 Figma 描边不再只能查看，修改仍是一条可撤销、可保存的原生操作。
- 新增 Shape 描边样式的 Undo/Redo、项目往返和属性控件回归测试。

### Verification
- Shape 专项已完成 `build-for-testing` 编译；隔离运行器受当前宿主 `testmanagerd` 限制无法采集断言，结果保留在 `test-reports/rc161-shape-style`。
- Xomo CLI 测试 2/2 通过。
- `git diff --check` 通过。

## 2.12.0-rc159 - 2026-07-17

### Added
- Figma `strokeDashes` 现在进入原生 Shape，虚线/点划线在导入、缩放渲染和项目保存重开时保持可编辑。
- 新增虚线描边映射与项目往返回归测试，旧项目缺少字段时安全回退为实线。

### Verification
- rc159 代码已进入编译回归；完整测试结果待宿主 `testmanagerd` 恢复后采集。
- `git diff --check` 通过。

## 2.12.0-rc158 - 2026-07-17

### Added
- Figma 形状导入现在保留 `strokeCap` 与 `strokeJoin`，矩形和路径在 Xomo 中继续以可编辑的 butt/round/square 端点与 miter/round/bevel 连接渲染。
- 新增 Figma 描边样式映射和项目存档往返回归测试；旧项目缺少字段时安全回退为 round。

### Verification
- Figma 描边样式定向测试已完成编译；当前隔离测试运行器在本机统一返回无断言异常退出，结果已保留在 `test-reports/rc158-figma-stroke`。
- `git diff --check` 通过。

## 2.12.0-rc157 - 2026-07-17

### Added
- PSD 导出现在会为基础 Xomo 文字层写入 TySh/EngineData，保留纯文本、字体、字号、颜色、段落框、对齐、缩进和基础字符样式；同时保留像素回退以兼容不支持语义的阅读器。
- 新增基础文字层 PSD 导出/导入往返回归测试与定向报告。

### Verification
- PSD 专项测试 17/17、文字导出定向测试 1/1、Xomo CLI 测试 2/2、`git diff --check` 通过。

## 2.12.0-rc156 - 2026-07-17

### Added
- PSD 导出现在会写入 Xomo 原生额外 Alpha 通道、名称和 8-bit 掩码，导出后可被 PSD 读取并继续编辑。
- 新增额外 Alpha 通道导出/导入往返回归测试与定向报告。

### Verification
- PSD 专项测试 16/16、Alpha 通道导出定向测试 1/1、Xomo CLI 测试 2/2、`git diff --check` 通过。

## 2.12.0-rc155 - 2026-07-17

### Added
- PSD 额外 Alpha 通道现在会读取名称与透明度数据，映射为 Xomo 原生可编辑 Alpha 通道，并随项目保存重开。
- 新增独立生成的 `extra-alpha.psd` 外部夹具，覆盖额外通道名称与像素掩码。

### Verification
- PSD 专项测试 15/15、额外 Alpha 通道定向测试 1/1、Xomo CLI 测试 2/2、`git diff --check` 通过。

## 2.12.0-rc154 - 2026-07-17

### Added
- PSD 导出现在会把结构完整的闭合原生矢量蒙版写入图层 `vmsk` 数据，保留多子路径、Bézier 控制柄和启用/停用状态。
- 开放路径、复杂路径和不适合 PSD `vmsk` 的内容继续自动栅格化为普通图层蒙版，避免生成误导性的半支持数据。

### Verification
- PSD 专项测试 14/14、原生矢量蒙版导出定向测试 1/1、Xomo CLI 测试 2/2、`git diff --check` 通过。

## 2.12.0-rc153 - 2026-07-17

### Added
- PSD 导出现在会把 Xomo 原生命名路径写入 Image Resources 的 Path Resource，支持闭合路径、开放路径、多子路径和 Bézier 控制柄。
- 新增“导出 PSD → 重新读取 PSD”的回归测试，验证名称、路径状态、锚点数量和画布坐标保持不变。

### Verification
- PSD 专项测试 13/13、PSD 命名路径导出定向测试 1/1、Xomo CLI 测试 2/2、`git diff --check` 通过。

## 2.12.0-rc152 - 2026-07-17

### Added
- PSD Image Resources 中的 Path Resource 现在会导入为 Xomo 路径面板中的可编辑命名路径，支持闭合路径、开放路径和 Bézier 控制柄。
- 导入的路径会进入原生项目格式，保存重开后保留名称、闭合状态、子路径和画布坐标。
- 新增外部生成的 `path-resources.psd` 夹具，覆盖闭合路径与开放路径。

### Verification
- PSD 专项测试 12/12、路径资源定向测试 1/1、Xomo CLI 测试 2/2、`git diff --check` 通过。

## 2.12.0-rc151 - 2026-07-17

### Added
- PSD `vmsk` / `vsms` 导入支持多个闭合子路径，进入 Xomo 原生路径蒙版并保留偶数奇数填充规则，可表达带孔洞的形状。
- 新增外部生成的 `vector-mask-multi.psd` 夹具与项目保存重开验证；开放路径、反相/断链等复杂记录仍安全降级。

### Verification
- PSD 专项测试 11/11、多子路径矢量蒙版定向测试 1/1、Xomo CLI 测试 2/2、`git diff --check` 通过。

## 2.12.0-rc150 - 2026-07-17

### Added
- PSD `vmsk` / `vsms` 简单闭合路径导入为 Xomo 原生矢量蒙版，保留三点 Bézier 锚点、控制柄、闭合状态和启用状态。
- 复杂路径、开放路径以及反相/断链等未覆盖标志继续进入兼容性报告，不会静默伪装成可编辑路径。
- 新增外部生成的 `vector-mask.psd` 与复杂 vmsk 安全降级样本。

### Verification
- PSD 专项测试 10/10、简单矢量蒙版导入 1/1、复杂 vmsk 安全降级 1/1、Xomo CLI 测试 2/2、`git diff --check` 通过。

## 2.12.0-rc149 - 2026-07-17

### Added
- PSD 段落文字读取 TySh 的文字边界并映射为原生文本框宽高，保留溢出判断；项目保存重开后文本框尺寸和溢出状态不变。
- 外部 `editable-text.psd` 夹具改为真实段落文字样本，避免只验证点文字路径。

### Verification
- PSD 专项测试 9/9、段落文本框导入与项目保存 1/1、Xomo CLI 测试 2/2、`git diff --check` 通过。

## 2.12.0-rc148 - 2026-07-17

### Added
- PSD `EngineData` 基础字符样式导入：粗体、斜体、下划线、删除线、字距、行距及段落缩进进入 Xomo 原生文字模型，并随项目保存重开。
- 更新外部 `editable-text.psd` 夹具与 PSD 专项验证，确保样式解析不是只针对 Xomo 自己生成的文件。

### Verification
- PSD 专项测试 9/9、文字样式导入 1/1、Xomo CLI 测试 2/2、`git diff --check` 通过。

## 2.12.0-rc147 - 2026-07-17

### Added
- PSD 导入支持基础 `TySh` / `EngineData` 文字层，读取纯文本、字体、字号、颜色和基础段落对齐并映射为 Xomo 原生可编辑文字层；无法解析的文字数据继续按像素回退。
- 新增独立外部生成的 `editable-text.psd` 夹具，验证文字导入、兼容性报告和 `.qpicproject` 保存重开。

### Changed
- PSD 支持说明和路线图明确区分“基础文字可编辑导入”和复杂文字/PSD 导出仍会栅格化的边界。

### Verification
- PSD 专项测试 9/9、基础文字导入与项目保存 1/1、Xomo CLI 测试 2/2、`git diff --check` 通过。

## 2.12.0-rc146 - 2026-07-17

### Added
- 多选图层的 Figma 变量绑定可稳定去重后复制；属性面板与 `xomo.figma.bindings` MCP/CLI 工具共享同一批量读取、复制逻辑。

### Verification
- `selectedLayerFigmaVariableBindingsBatchCopyIsStableAndDeduplicated`、`registryListsAndCopiesFigmaBindingsFromSelectedLayers`、`registryAdvertisesBroadEditorCapabilities` 均通过；Xomo CLI 2 项测试通过；`git diff --check` 通过。

## 2.12.0-rc145 - 2026-07-17

### Added
- 新增 PSD 兼容性扫描与可重复查看的报告界面，按文件实际内容列出压缩、图层组、蒙版以及文字、矢量、智能对象、调整层、图层效果、填充层、ICC、额外通道和未知数据的降级情况。
- 增加三份不经过象墨编码器的 PSD 外部格式夹具，由 Ruby 按 Adobe 规范生成 ZIP、ZIP Prediction、分组、蒙版和不支持语义样本。
- 增加独立的 PSD 支持说明，区分原生支持、栅格化降级和暂不支持能力，并记录大文件边界、验证证据与后续实现顺序。

### Changed
- PSD 导入支持 ZIP 与 8-bit ZIP Prediction；图层组、栅格蒙版、27 种混合模式、Fill 不透明度以及透明/像素/位置/全部锁定支持双向往返。
- 新建画布或打开象墨项目时清理上一份 PSD 报告，避免报告与当前文档错配。

### Verification
- Debug `build-for-testing` 通过；PSD 兼容性 8/8、外部打开 4/4、三语本地化 4/4、CLI 2/2 通过，并生成 JSON / Markdown 报告。
- PSD 定向测试覆盖外部 ZIP 夹具、逐像素蒙版、组层级、完整混合模式、Fill、锁定和兼容性问题分类。

## 2.12.0-rc144 - 2026-07-16

### Added
- 注册 PSD 文档类型，支持从 Finder 双击或“打开方式”交给象墨；耗时打开时显示“一墨生万象”启动主视觉、原生转圈动画与中 / 英 / 日阶段文案，普通启动直接进入编辑器。
- PSD 结构读取与 RLE 解压移到后台任务，图层图像在主线程分批组装并主动让出执行权，加载动画在大文件解析期间保持响应。

### Changed
- 中文应用名由“像界”更新为“象墨”；项目内“打开项目”选择 PSD 时复用同一异步加载流程。

### Verification
- Debug `build-for-testing` 通过；外部打开策略 4/4、PSD 同步/异步解码 3/3、本地化资源 4/4、CLI 2/2 通过，并生成 JSON / Markdown 报告。
- 构建产物核对确认版本为 `2.12.0-rc144`、最低系统为 macOS 13.0、PSD 以 `Editor + Alternate` 注册且启动主视觉已编入 `Assets.car`。

## 2.12.0-rc143 - 2026-07-16

### Added
- `xomo.layer.list` 新增 `figmaBindings=all|bound|unbound` 筛选，可快速定位有或没有 Figma 变量绑定的图层，并对未知筛选值返回明确错误。

### Verification
- `registryLayerListExposesFigmaVariableBindings` 1/1、`XomoMCPServerTests` 2/2 和 `git diff --check` 通过；全套隔离测试在无关的修复画笔测试宿主处等待超时，未将其余用例标记为通过。

## 2.12.0-rc142 - 2026-07-16

### Added
- `xomo.layer.list` 现在返回图层携带的 Figma 变量绑定数量与逐项元数据（字段、变量 ID、稳定绑定 ID），让 MCP/CLI 可以检查导入保留的设计变量，而不需要读取项目私有结构。

### Verification
- `XomoAutomationTests` 40/40、`XomoMCPServerTests` 2/2 通过；真实安装版核验确认组件库模式使用系统箭头，组件仍可点击拖动。

## 2.12.0-rc141 - 2026-07-16

### Added
- 新增“刷新已映射组件”能力：导入新的本地设计 Tokens 后，可一次刷新所有携带本地映射的 UI 组件，跳过内置主题和局部覆写，并将整批刷新作为一个 Undo/Redo 步骤。
- `xomo.component.tokens` 新增 `action=refresh`，返回刷新组件数量，并与组件库 UI 共用同一套本地 Token 映射逻辑。

### Verification
- `XomoLeftSidebarTests` 43/43、`XomoAutomationTests` 39/39、`XomoMCPServerTests` 2/2 通过。

## 2.12.0-rc140 - 2026-07-16

### Verification
- 第 140 个小版本质量门禁覆盖全量隔离测试、Debug/Release 双架构构建、CLI、真实冒烟和 `/Applications/Xomo.app` 安装版核对。

## 2.12.0-rc139 - 2026-07-16

### Added
- `xomo.component.tokens` 新增 `action=clear`，清除当前本地 Token 映射并保留 Undo/Redo 恢复能力。

### Verification
- `XomoAutomationTests` 38/38、`XomoMCPServerTests` 2/2 通过。

## 2.12.0-rc138 - 2026-07-16

### Added
- `xomo.component.tokens` 新增 `action=apply`，可将当前本地 Token 应用到选中 UI 组件并写入单步 Undo/Redo。

### Verification
- `XomoAutomationTests` 37/37、`XomoMCPServerTests` 2/2 通过。

## 2.12.0-rc137 - 2026-07-16

### Fixed
- 修复 macOS 13 无 hover 坐标时光标不及时刷新的问题；工具、组件库、画笔尺寸、缩放和修饰键切换后立即重算。

### Verification
- `ImageEditorCanvasCursorTests` 9/9、`XomoLeftSidebarTests` 42/42 通过。

## 2.12.0-rc136 - 2026-07-16

### Fixed
- 修复画布平移状态未传入光标解析器的问题；组件库平时保持系统箭头，实际平移时才显示闭合手。

### Verification
- `ImageEditorCanvasCursorTests` 9/9、`XomoLeftSidebarTests` 42/42 通过。

## 2.12.0-rc135 - 2026-07-16

### Fixed
- 将组件拖动命中区域固定在已提交对象边界，拖动预览不再把命中目标一起移动；组件库模式下点击其他组件会切换选中对象。

### Verification
- `XomoCanvasObjectTests` 19/19、`XomoLeftSidebarTests` 42/42 通过。

## 2.12.0-rc134 - 2026-07-16

### Fixed
- 修复组件库插入的 UI 组件选中后无法可靠拖动的问题；独立命中区域使用画布坐标并避免父画布重复移动。

### Verification
- `XomoCanvasObjectTests` 18/18、`XomoLeftSidebarTests` 42/42 通过。

## 2.12.0-rc133 - 2026-07-16

### Added
- 增加 Option/Alt `+`、`-` 缩放快捷键，并保留 Command `+`、`-` 兼容。

### Verification
- `ImageEditorHistoryTests` 5/5 通过，覆盖 Command 与 Option 缩放快捷键解析。

## 2.12.0-rc132 - 2026-07-16

### Fixed
- 修复缩放工具 Option 减号光标与实际操作不一致的问题；现在普通点击放大，按住 Option 点击缩小。

### Verification
- `ImageEditorCanvasCursorTests` 8/8 通过，覆盖光标图像、Option 方向解析和现有工具路由。

## 2.12.0-rc131 - 2026-07-16

### Changed
- 缩放工具按住 Option 时显示减号放大镜，默认显示加号放大镜，直接反馈当前缩放方向。

### Verification
- `ImageEditorCanvasCursorTests` 7/7 通过，覆盖组件库系统箭头、工具光标路由、修饰键和缩放加/减光标。

## 2.12.0-rc130 - 2026-07-16

### Fixed
- 组件对象命中判断缓存上层图像的 alpha 探针，重复点击不再重复分配整张 RGBA 缓冲区，同时保持透明孔洞透传和真实覆盖层遮挡。

### Verification
- `XomoCanvasObjectTests` 18/18、`XomoLeftSidebarTests` 42/42 通过；项目加载主题上下文的编译修复也纳入本次回归。

## 2.12.0-rc129 - 2026-07-16

### Added
- 项目文件保存当前 Xomo 主题和本地 Token 映射，重新打开项目后恢复设计资产上下文；项目格式版本升至 7。

### Verification
- `XomoLeftSidebarTests` 42/42、`ImageEditorProjectDocumentTests` 8/8、`ImageEditorSavedPathTests` 28/28 通过。

## 2.12.0-rc128 - 2026-07-16

### Added
- 本地设计 Token 导入、清除和主题切换进入统一 Undo/Redo，并记录到历史面板。

### Verification
- `XomoLeftSidebarTests` 41/41、`ImageEditorHistoryTests` 5/5 通过，覆盖 Token 状态与普通历史栈。

## 2.12.0-rc127 - 2026-07-16

### Fixed
- 组件命中判断改为按点击点读取上层图层 alpha，透明孔洞不会再错误拦截组件选择与拖动。

### Verification
- `XomoCanvasObjectTests` 17/17 通过，覆盖透明空层、稀疏像素孔洞和真实覆盖层。

## 2.12.0-rc126 - 2026-07-16

### Fixed
- 组件命中判断改用上层图层的实际可见 alpha；透明空图层不再拦截组件点击，真实可见覆盖层仍会阻挡命中。

### Verification
- `XomoCanvasObjectTests` 16/16 通过，覆盖透明层透传与真实覆盖层遮挡。

## 2.12.0-rc125 - 2026-07-16

### Added
- UI 组件在参考线吸附开启时自动吸附到画布四边与水平/垂直中心，并显示对应对齐参考线。

### Verification
- UI 组件画布中心吸附与既有图层参考线测试通过。

## 2.12.0-rc124 - 2026-07-16

### Changed
- 工具箱移动工具改用独立四向移动光标，组件库模式继续使用系统箭头，避免两个上下文混淆。

### Verification
- 组件库箭头、移动工具光标与平移抓手专项测试通过。

## 2.12.0-rc123 - 2026-07-16

### Changed
- 统一画布光标解析入口；组件库模式不再继承工具箱上一次的自定义工具光标。
- 组件库模式保持系统箭头，只有 Space 或手形工具平移时切换为开放/闭合抓手。

### Verification
- 组件库箭头与平移光标专项测试通过。

## 2.12.0-rc122 - 2026-07-16

### Fixed
- 提高画布组件移动手势优先级，修复 macOS 13 拖放宿主抢占普通鼠标拖拽导致 UI 组件无法点击选中或移动的问题。

### Verification
- XomoCanvasObjectTests：14/14 通过（独立进程、已授权 macOS 测试服务）。
- 双架构 Debug 构建：通过（arm64 + x86_64，macOS 13.0）。

## 2.12.0-rc121 - 2026-07-16

### Added
- 支持导入 `.xomotokens.json` 作为本地设计 Token 映射，作用于新插入和已选 UI 组件，并随组件实例与项目往返保留。
- 组件库 UI 与 `xomo.component.tokens` MCP/CLI 共用 Token 导入入口，切换内置主题可清除本地映射。

### Verification
- 组件库 40/40、自动化/MCP 36/36、Figma 节点导入 25/25、三语资源 4/4 通过。

## 2.12.0-rc120 - 2026-07-16

### Verification
- 第 120 个小版本质量门禁覆盖全量隔离测试、Debug/Release 构建、双架构 CLI、真实冒烟和 `/Applications/Xomo.app` 安装版核对。

## 2.12.0-rc119 - 2026-07-16

### Changed
- 键盘修饰键按下和释放时即时刷新选择工具光标，不必移动鼠标才能看到添加、减去和相交模式。

### Verification
- 画布指针专项测试覆盖选择模式、组件库箭头、工具栏切换、拖动画布和全部工具光标家族，全部通过。

## 2.12.0-rc118 - 2026-07-16

### Changed
- 选择工具光标根据 Shift/Option 修饰键显示添加、减去和相交模式，降低选区布尔操作的误操作成本。

### Verification
- 画布指针专项测试覆盖四种选择光标模式、矩形、椭圆、画笔、橡皮擦、三种修图工具、三种色调工具、修复画笔、仿制图章、快速选择、红眼、吸管、组件库箭头及全部工具家族，全部通过。

## 2.12.0-rc117 - 2026-07-16

### Changed
- 矩形和椭圆工具拆分为独立光标家族，分别表达矩形框和椭圆框绘制。

### Verification
- 画布指针专项测试覆盖矩形、椭圆、画笔、橡皮擦、三种修图工具、三种色调工具、修复画笔、仿制图章、快速选择、红眼、吸管、组件库箭头及全部工具家族，全部通过。

## 2.12.0-rc116 - 2026-07-16

### Changed
- 画笔和橡皮擦工具改用带笔尖/笔触与透明缺口的独立语义指针，避免与普通工具光标混淆。

### Verification
- 画布指针专项测试覆盖画笔、橡皮擦、三种修图工具、三种色调工具、修复画笔、仿制图章、快速选择、红眼、吸管、组件库箭头及全部工具家族，全部通过。

## 2.12.0-rc115 - 2026-07-16

### Changed
- 模糊、锐化、涂抹工具改用液滴、星芒和涂抹旋涡组成的独立语义指针，避免与普通画笔光标混淆。

### Verification
- 画布指针专项测试覆盖三种修图工具、三种色调工具、修复画笔、仿制图章、快速选择、红眼、吸管、组件库箭头及全部工具家族，全部通过。

## 2.12.0-rc114 - 2026-07-16

### Changed
- 减淡、加深、海绵工具改用太阳、火焰、海绵纹理组成的独立语义指针，避免与普通画笔光标混淆。

### Verification
- 画布指针专项测试覆盖三种色调工具、修复画笔、仿制图章、快速选择、红眼、吸管、组件库箭头及全部工具家族，全部通过。

## 2.12.0-rc113 - 2026-07-16

### Changed
- 修复画笔工具改用绷带和取样十字指针，明确表达从源点取样并融合修复。

### Verification
- 画布指针专项测试覆盖修复画笔、仿制图章、快速选择、红眼、吸管、组件库箭头及全部工具家族，全部通过。

## 2.12.0-rc112 - 2026-07-16

### Changed
- 仿制图章工具改用印章、取样十字和方向箭头指针，明确显示源点到目标的盖印语义。

### Verification
- 画布指针专项测试覆盖仿制图章、快速选择、红眼、吸管、组件库箭头及全部工具家族，全部通过。

## 2.12.0-rc111 - 2026-07-16

### Changed
- 快速选择工具改用虚线选区环、笔刷和加号指针，明确表达增量选区操作。

### Verification
- 画布指针专项测试覆盖全部工具家族及组件库箭头，快速选择新增图稿与既有 Cursor 回归全部通过。

## 2.12.0-rc110 - 2026-07-16

### Changed
- 红眼工具改用独立的眼睛/红色瞳孔/定位十字指针，不再复用普通画笔圆环。

### Verification
- 画布指针专项测试覆盖组件库箭头、吸管、红眼、油漆桶、颜色采样器和精确工具图稿，全部通过。

## 2.12.0-rc109 - 2026-07-16

### Changed
- 吸管工具改用独立的高对比取样指针，显示吸管尖端和颜色水滴，不再使用普通十字准星。

### Verification
- 画布指针专项测试覆盖组件库系统箭头、吸管/油漆桶/颜色采样器差异及精确工具图稿，全部通过。

## 2.12.0-rc108 - 2026-07-16

### Added
- 新增 `xomo.component.tokens` MCP/CLI 工具，复用主题 Token 文件的稳定 JSON，可读取当前主题或导出指定 `.xomotokens.json` 路径。

### Verification
- 组件 Token 自动化读取/导出、MCP 工具目录与 CLI 目录专项测试通过；输出继续保持本机端点与本地文件操作，不联网写回第三方设计工具。

## 2.12.0-rc107 - 2026-07-16

### Added
- 组件库主题新增 `.xomotokens.json` 文件导出，可通过系统保存面板将当前主题 Token 保存为可复用设计资产。

### Verification
- 主题 Token 文件写入/JSON 往返、组件库导出按钮专项 37/37、三语资源专项 4/4 通过，报告见 `test-reports/rc107-theme-export/` 与 `test-reports/rc107-localization/`；Debug App 实际显示复制与导出两个按钮。

## 2.12.0-rc106 - 2026-07-16

### Added
- 组件库主题新增“复制主题 Tokens”入口，将当前原创/参考主题导出为带 schema 版本、颜色和尺寸 token 的稳定 JSON，便于 Sketch/Figma 设计系统复用。

### Verification
- 组件库主题专项 36/36、三语资源专项 4/4 通过，报告见 `test-reports/rc106-component-tokens/` 与 `test-reports/rc106-localization/`；Debug App 实际切换组件库并点击复制按钮，状态栏显示“已复制 极简 SaaS 主题 Tokens”。

## 2.12.0-rc105 - 2026-07-16

### Added
- 在属性面板显示选中图层的 Figma 变量绑定，并支持复制单个或全部变量 ID；该动作只读本地剪贴板，不向 Figma 写回。

### Verification
- Figma 变量绑定专项 7/7、三语资源专项 4/4 通过，报告见 `test-reports/rc105-figma-variable-binding/` 与 `test-reports/rc105-localization/`；rc104 组件对象与组件库回归报告继续保留。

## 2.12.0-rc104 - 2026-07-16

### Fixed
- 将选中 UI 组件的移动交给画布父级手势，避免 macOS 拖放宿主吞掉定位叠加层的拖动事件；虚线选框保留为视觉层，缩放控制柄继续独立响应。

### Verification
- rc104 Release 构建并安装到 `/Applications/Xomo.app`；组件对象专项 14/14、组件库专项 33/33 通过，报告见 `test-reports/rc104-canvas-object/` 与 `test-reports/rc104-component-sidebar/`。

## 2.12.0-rc103 - 2026-07-16

### Fixed
- 修正独立组件拖动手势的坐标空间，使用画布坐标而不是组件局部坐标，避免点击/拖动位置偏移。

### Verification
- Release 构建成功并安装到 `/Applications/Xomo.app`；组件库专项 33/33、组件对象命中/移动专项 14/14 通过，报告见 `test-reports/rc103-component-sidebar/` 与 `test-reports/rc103-canvas-object/`。

## 2.12.0-rc102 - 2026-07-15

### Fixed
- 为选中的 UI 组件增加独立矩形命中层与移动手势，避免组件内容或拖放宿主吞掉首次点击/拖动；画布父手势会跳过该对象，防止移动增量重复应用。

### Verification
- 组件库专项测试 33/33、组件对象命中/移动专项测试 14/14 通过；报告见 `test-reports/rc102-component-sidebar/` 与 `test-reports/rc102-canvas-object/`。

## 2.12.0-rc101 - 2026-07-15

### Fixed
- 组件选中框不再与画布父级拖动手势重复响应，避免拖动 UI 组件时出现位置漂移或尺寸异常。

### Verification
- rc101 Release 构建成功，Bundle ID 为 `im.some.xomo`，覆盖安装到 `/Applications/Xomo.app`；组件库插入、点击选中、画布拖动与撤销冒烟通过。

## 2.12.0-rc100 - 2026-07-15

### Verification
- Release 构建成功；全量独立进程测试 `908/908` 通过、`0` 失败，报告见 `test-reports/rc100-escalated/report.json` 与 `report.md`。

## 2.12.0-rc99 - 2026-07-15

### Performance
- 组件对象选中使用轻量图层选择路径，跳过无关属性面板同步，减少点击组件后的 UI 延迟。

### Tests
- 新增组件组快速选择、选中 ID、复合选择集与蒙版状态回归；Debug 目标编译产出成功。

## 2.12.0-rc98 - 2026-07-15

### Added
- 键盘监视器显式处理对象箭头移动：普通箭头 1px、Option 5px、Shift 10px；文字输入框仍完整保留原生输入行为。

### Tests
- 新增箭头 nudge 距离与修饰键组合回归测试；Debug 目标编译产出成功。

## 2.12.0-rc97 - 2026-07-15

### Fixed
- 切换到组件库时即使没有 hover 坐标，也立即恢复系统箭头，避免 macOS 13 继续显示工具箱上一枚光标。

### Tests
- 增加组件库切换后无 hover 坐标仍重置箭头的源码契约断言。

## 2.12.0-rc96 - 2026-07-15

### Tests
- 修正组件库交互契约测试，使其验证当前的语义光标路由和拖放目标并行手势，避免旧断言掩盖后续回归。

## 2.12.0-rc95 - 2026-07-15

### Fixed
- 组件库画布同时承担拖放目标和编辑手势时，改为同时识别零距离拖动，恢复已插入 UI 组件的点击选中与拖动移动。

### Tests
- Xomo 画布对象命中、选择、移动和删除回归继续通过；组件拖放手势改为同时手势路由。

## 2.12.0-rc94 - 2026-07-15

### Added
- 接入 Figma Variables 本地变量只读接口，按默认 mode 解析颜色值并递归解析颜色别名。

### Changed
- Figma 节点导入在有 Variables 权限时使用实时颜色覆盖静态填充/描边；网络或权限不可用时仍保留变量绑定 ID 并安全降级。

### Tests
- 新增 Variables API 请求、默认 mode、别名解析与导入计划颜色应用回归；Figma 导入专项 25/25 通过。

## 2.12.0-rc93 - 2026-07-15

### Added
- Figma 节点导入识别 `fills`、`strokes`、`characters` 的 `VARIABLE_ALIAS`，保留字段与变量 ID 到原生图层，并随项目保存重开。

### Changed
- 导入报告明确标记变量绑定已保留但暂未解析实时值，继续使用 Figma 返回的静态颜色/文字结果，避免伪装成完整 Variables API。

### Tests
- 新增变量绑定解码、材料化、项目 round-trip 与三语资源回归；Figma 导入专项 24/24 通过。

## 2.12.0-rc92 - 2026-07-15

### Changed
- 组件库模式继续使用系统箭头；选框、套索、魔棒、裁切、修补、渐变和矩形/椭圆工具改用各自的语义光标图形，不再机械复用同一枚十字光标。

### Tests
- 新增工具语义光标族与光标图形唯一性的回归测试；定向光标测试 3/3 通过。

## 2.12.0-rc91 - 2026-07-15

### Added
- 将 Figma 水平 Wrap 的 `counterAxisAlignContent=SPACE_BETWEEN` 映射为可编辑的原生行轨道分布，并在属性面板提供“行分布”设置。

### Changed
- 固定交叉轴布局会按行轨道均分剩余空间；Hug、项目保存重开、重排与未知值降级边界保持明确。
- 将 Figma 渐变颜色测试改为容忍系统色彩空间的显示误差，避免 macOS 颜色转换造成误报。

### Tests
- 新增 SPACE_BETWEEN 行轨道几何、项目 round-trip、属性面板契约与 Figma 导入回归。

## 2.12.0-rc90 - 2026-07-15

### Changed
- 组件库模式的画布光标固定为系统箭头，并保留空格/拖动画布时的抓手覆盖。
- 将油漆桶、取色器和颜色采样器改为语义化光标：油漆桶显示桶与水滴，取色器使用精确十字线，颜色采样器使用带中心采样点的范围镜。

### Tests
- 新增光标路由、组件库箭头覆盖、平移覆盖和语义化光标形状回归测试。

## 2.12.0-rc89 - 2026-07-15

### Fixed
- 修复组件库模式下 `dropDestination` 抢占画布手势，导致已插入 UI 组件无法稳定点击选中或拖动的问题；画布手势现在优先接收点击和拖动事件。

### Tests
- 新增组件库标签页强制使用移动工具并命中组件对象的回归测试。

## 2.12.0-rc88 - 2026-07-15

### Added
- Xomo 原生 Auto Layout 新增水平文字基线对齐；文字层从当前字体 ascender 与绘制起点实时推导首行基线，字号、字体或图层缩放变化后重新排版仍保持准确。
- 普通图形以底边作为基线回退；水平 Wrap 为每一行独立计算最大基线与下行空间，交叉轴 Hug 会扩展到完整基线包络，不会把较深的字形或混排子项裁掉。
- 属性面板仅在水平布局提供“基线”选项，项目保存、重开、Undo/Redo 与现有 Auto Layout 模型共用同一语义；垂直布局会规范化为起点对齐。
- Figma 水平 `counterAxisAlignItems=BASELINE` 映射为可编辑原生布局；非法垂直 Baseline 与 `counterAxisAlignContent=SPACE_BETWEEN` 继续明确降级。
- App、CLI、教程、Figma/MCP 文档、路线图与全部 Xcode target 版本同步为 `2.12.0-rc88`。

### Tests
- 新增固定与 Hug 基线包络、普通图形回退、Stretch 覆盖、逐行 Wrap、水平限定、字体度量、缩放、项目往返及 Figma 合法/非法边界回归。
- Auto Layout 23/23、Figma 节点导入 22/22、三语资源 4/4，共 49/49 通过；SwiftPM CLI 2/2 通过并输出 `2.12.0-rc88`。
- 隔离 Debug App 的版本、Bundle ID `im.some.xomo`、macOS 13.0 下限与 arm64 架构核对通过；完整 Release、全量测试、冒烟和 `/Applications` 覆盖仍按 20 版门禁在 rc100 执行。

## 2.12.0-rc87 - 2026-07-15

### Added
- Xomo 原生 Auto Layout 新增水平换行模式：固定宽度容器会按可用宽度分行，保留行内间距、独立行间距、每行交叉轴对齐，以及 Fill/Stretch 子项语义。
- 交叉轴为 Hug 时，换行容器会按各行最高子项、行间距和上下内距自动调整高度；项目保存重开、属性面板修改和单步 Undo/Redo 使用同一布局模型。
- Figma `layoutWrap=WRAP` 与 `counterAxisSpacing` 映射为可编辑原生布局，不再笼统标记为扁平化；Baseline、纵向 Wrap 与 `counterAxisAlignContent=SPACE_BETWEEN` 继续明确降级。
- App、CLI、教程、Figma/MCP 文档、路线图与全部 Xcode target 版本同步为 `2.12.0-rc87`。

### Changed
- Auto Layout 容器与子项属性控件从超大 `ImageEditorView.swift` 抽成独立小视图，避免新增条件控件把 SwiftUI 主编译单元拖入数十分钟类型检查，同时保持原有无焦点交互与辅助功能标识。

### Tests
- 新增多行位置/对齐、Hug 高度、逐行 Fill/Stretch、项目往返、属性修改与 Undo/Redo 回归；Auto Layout 17/17、Figma 节点导入 20/20、三语资源 4/4，共 41/41 通过。
- SwiftPM CLI 2/2 通过并输出 `2.12.0-rc87`；隔离 Debug App 的版本、Bundle ID `im.some.xomo`、macOS 13.0 下限与 arm64 架构核对通过。

## 2.12.0-rc86 - 2026-07-15

### Added
- Figma 图片填充导入读取官方 `filters` 的曝光、对比度、饱和度、色温、色调、高光与阴影 7 个字段，按官方 `-1...1` 范围校验并保留在导入计划中。
- 图片完成 Fill/Fit/Crop/Tile/旋转布局后，将滤镜近似烘焙进最终像素层；透明度保持不变，保存项目后仍保留视觉结果。
- 导入报告新增“图片滤镜已近似烘焙”降级项，明确提示导入后不能把这些参数作为独立滤镜继续编辑，不声称无损还原。
- App、CLI、教程、Figma/MCP 文档、路线图与全部 Xcode target 版本同步为 `2.12.0-rc86`。

### Tests
- 新增滤镜范围/非有限值、7 字段映射、颜色通道变化、材质化与项目重开 4 项回归；既有 Figma 图片资产 8 项、节点导入 19 项继续通过，共 31/31。
- 三语资源 4/4、SwiftPM CLI 2/2 通过并输出 `2.12.0-rc86`；隔离 Debug App 的版本、Bundle ID `im.some.xomo`、macOS 13.0 下限与 arm64 架构核对通过。

## 2.12.0-rc85 - 2026-07-15

### Fixed
- 顶部工具选项栏在深色界面中显式使用白色前景和深色原生控件环境，选区模式、形状菜单、羽化标签与数值不再出现黑字。
- 切到组件库时，画布有效工具立即回到移动/选择语义并显示系统箭头；此前选中的工具仍被保留，返回工具箱后继续使用，不会丢失用户上下文。
- 组件库模式下点击画布对象会切换并选中所属图层，拖动对象与空白处平移画布共用移动工具行为；光标与手势读取同一有效工具，避免箭头之下仍然落下画笔。
- 各工具按交互语义映射为系统箭头、抓手、文字插入、笔刷尺寸、精确十字、钢笔笔尖或缩放镜；缩放工具使用带加号的专用放大镜，不再机械复用工具栏图标。
- App、CLI、教程、Figma/MCP 文档、路线图与全部 Xcode target 版本同步为 `2.12.0-rc85`。

### Tests
- 新增顶部选项栏纯白前景、组件库有效工具切换/恢复、画布接线、28 个工具光标语义完整覆盖和缩放镜独立外观回归；选项栏 2、组件侧栏 33、对象 12、图层面板 8、光标 3、三语资源 4，共 62 项通过。
- SwiftPM CLI 2/2 通过并输出 `2.12.0-rc85`；隔离 Debug App 的版本、Bundle ID `im.some.xomo`、macOS 13.0 下限与 arm64 架构核对通过。
- 保存选项栏实机截图、参考对比图和 JSON/Markdown 测试报告，视觉核对无 P0/P1/P2 偏差。

## 2.12.0-rc84 - 2026-07-15

### Changed
- 径向渐变中心柄不再固定为灰色，半径柄也不再固定为白色；两者分别显示当前视觉起点与终点颜色，让用户无需猜测中心到边缘的颜色方向。
- 线性与径向控制柄共用同一套显示端点颜色解析，读取多色标真实首尾颜色；开启反向时两端颜色自动交换，中心柄仍保留高对比内点以区别半径柄。
- App、CLI、教程、Figma/MCP 文档、路线图与全部 Xcode target 版本同步为 `2.12.0-rc84`。

### Tests
- 新增三色渐变真实端点、反向交换与径向界面接线回归；形状样式套件 21/21、三语资源 4/4、SwiftPM CLI 2/2 通过。
- CLI 输出 `2.12.0-rc84`；隔离 Debug App 的版本、Bundle ID `im.some.xomo`、macOS 13.0 下限与 arm64 架构核对通过。

## 2.12.0-rc83 - 2026-07-15

### Added
- 径向渐变的中心到半径控制线支持双击新增中间色标；18pt 透明命中带让细线更容易点中，新增色标会立即同步成为画布与属性面板的当前选择。
- 新色标按双击位置的当前径向渐变结果插值，反向渐变会先把视觉位置换回逻辑色标位置，颜色与显示结果保持一致。

### Changed
- 径向新增复用线性渐变已经验证的 1% 最小间距、最多 16 个色标、锁定保护和单步 Undo/Redo，不为两种渐变维护两套插值逻辑。
- App、CLI、教程、Figma/MCP 文档、路线图与全部 Xcode target 版本同步为 `2.12.0-rc83`。

### Tests
- 新增正常/反向径向插值、颜色结果、一步撤销、16 色标上限、锁定拒绝与径向命中层源码约束；形状样式套件 20/20 通过。
- 三语资源 4/4、SwiftPM CLI 2/2 通过并输出 `2.12.0-rc83`；隔离 Debug 测试产品构建通过，App 版本、Bundle ID `im.some.xomo`、macOS 13.0 下限和 arm64 架构核对通过。

## 2.12.0-rc82 - 2026-07-15

### Added
- 径向渐变的中间色标现在显示在画布中心到半径柄的控制线上；点击色标会同步属性面板选择，拖动时沿真实显示半径投影并实时更新颜色位置。
- 径向色标复用线性色标的 Delete 删除入口、相邻色标 1% 最小间距与单步 Undo/Redo，锁定形状仍拒绝编辑。

### Changed
- 色标画布几何统一支持线性轴和径向半径线；反向渐变、偏心中心及非等比缩放后的画布坐标都使用同一逻辑位置换算，不改变中心柄或半径柄语义。
- App、CLI、教程、Figma/MCP 文档、路线图与全部 Xcode target 版本同步为 `2.12.0-rc82`。

### Tests
- 新增径向色标几何与交互回归，覆盖非等比画布、离轴拖动、反向位置、实时内容更新、单步撤销、删除恢复和锁定保护；形状样式套件 18/18 通过。
- SwiftPM CLI 2/2 通过并输出 `2.12.0-rc82`；隔离 Debug 测试产品构建通过，App 版本、Bundle ID `im.some.xomo`、macOS 13.0 下限和 arm64 架构核对通过。

## 2.12.0-rc81 - 2026-07-15

### Fixed
- Figma 线性与径向渐变共用的色标颜色解析不再错误继承 UI 的 `MainActor` 隔离，清除 rc80 通用 Release 暴露的 Swift 6 actor-isolation 预警。
- 色标与颜色响应值明确为 `nonisolated + Sendable` 纯数据，归一化函数可在后台任务安全执行；网络授权、节点映射、颜色/透明度校验和导入结果保持不变。

### Changed
- App、CLI、教程、Figma/MCP 文档、路线图与全部 Xcode target 版本同步为 `2.12.0-rc81`。

### Tests
- 新增 detached task 色标解析测试，覆盖合法 RGBA、非有限色标位置与越界颜色通道；完整 Figma 节点导入 19/19、CLI 2/2 通过。
- arm64/x86_64 通用 Release App 构建通过，quiet 编译阶段不再输出 Swift warning；产物版本 `2.12.0-rc81`、Bundle ID `im.some.xomo`、macOS 13.0 下限和双架构核对通过。

## 2.12.0-rc80 - 2026-07-15

### Fixed
- 右侧“图层 / 通道 / 复合 / 路径”等面板标题改由原生 AppKit 富文本标签直接绘制纯白文字，不再继承 SwiftUI 按钮的 tint、按压或焦点状态而变暗。
- 标题标签固定使用深色外观且不接受键盘焦点，图标与展开箭头继续保持白色，深色面板中的标题对比度一致。

### Changed
- App、CLI、教程、路线图、组件清单与全部 Xcode target 版本同步为 `2.12.0-rc80`。

### Tests
- 新增原生面板标题的富文本颜色、深色外观和不可聚焦回归测试；标题专项 8/8、全量隔离单元测试 866/866、SwiftPM CLI 2/2 均通过。
- arm64/x86_64 通用 Release App 与 CLI 构建成功；核对版本 `2.12.0-rc80`、Bundle ID `im.some.xomo`、macOS 13.0 下限、双架构及 ad-hoc 签名通过。真实启动 Release 与安装版，图层页及通道页的“图层 / 通道 / 复合 / 路径”标题均保持纯白；已覆盖安装 `/Applications/Xomo.app`。
- Release 编译报告一处非阻断 Swift 6 actor-isolation 预警，位于 Figma 渐变色标纯函数；为保证 866 项门禁对应最终实现，本版不在全量测试后改代码，留给 rc81 独立清理并复测。

## 2.12.0-rc79 - 2026-07-15

### Added
- 选中径向渐变形状并使用移动工具时，画布显示低干扰的灰色虚线半径、渐变边界、中心控制柄与半径控制柄；拖动中心或半径会实时更新原生形状渐变。
- 径向边界从形状局部圆经过当前图层变换后绘制，因此非等比缩放图层会显示与实际渲染对应的椭圆边界；半径拖动先逆换算回局部坐标，不会因画布缩放或图层拉伸而算偏。

### Changed
- 径向中心与半径拖动复用线性渐变的事务式历史路径：开始拖动保存原状态，过程中只预览，松手只写入一步 Undo；无位移点击不新增历史，锁定图层拒绝编辑。
- App、CLI、教程、三语帮助文案、路线图与全部 Xcode target 版本同步为 `2.12.0-rc79`。

### Tests
- 新增非等比图层的中心、半径与边界换算，以及中心/半径拖动、实时内容更新、单步 Undo、空操作和锁定保护测试；形状样式 16/16、三语资源 4/4、CLI 2/2 与隔离 Debug 测试产品构建通过。Debug App 版本、Bundle ID、macOS 13.0 下限和 arm64 架构核对通过；完整 Release、全量冒烟及 `/Applications` 覆盖安装将在 rc80 执行。
