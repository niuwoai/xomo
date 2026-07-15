# Changelog

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

## 2.12.0-rc78 - 2026-07-15

### Added
- Figma 节点导入新增 `GRADIENT_RADIAL`：2–16 个有序色标、公共透明度、偏心中心和圆形半径会映射为 rc77 的原生可编辑径向形状渐变。
- 径向半径在节点实际像素空间中计算，因此非正方形对象也能正确识别圆形渐变，不会把归一化坐标长度误当成视觉半径。

### Changed
- Figma 径向渐变的两条控制轴只有在实际像素空间等长且垂直时才标记精确导入；椭圆、倾斜、越界、无效色标或超出 Xomo 半径范围的几何继续报告 `unsupportedPaint`，不以圆形近似冒充无损结果。
- 线性与径向导入共用色标、透明度、顺序和数量校验，避免两套解析规则悄悄分叉；App、CLI、教程、Figma/MCP 文档、路线图与全部 Xcode target 版本同步为 `2.12.0-rc78`。

### Tests
- 新增非正方形圆形径向渐变的像素轴换算、多色标、透明度、中心、半径、材料化和椭圆轴降级测试；Figma 节点导入 18/18、三语资源 4/4、CLI 2/2 与隔离 Debug 测试产品构建通过。Debug App 版本、Bundle ID、macOS 13.0 下限和 arm64 架构核对通过；完整 Release、全量冒烟及 `/Applications` 覆盖安装仍按 20 版门槛在 rc80 执行。

## 2.12.0-rc77 - 2026-07-15

### Added
- 可编辑形状新增原生径向渐变填充；径向与线性渐变共享 2–16 个色标、反向、中心和缩放数据，继续参与形状裁切、独立描边、项目保存与 Undo/Redo。
- 属性面板的填充类型新增“径向渐变”，可编辑全部色标及 25%–400% 半径比例；三种填充标签保持单行并在窄面板内缩放文字。
- MCP/CLI `xomo.shape.create/get/update` 新增 `fillKind=radialGradient`，复用既有 `fillGradient.stops/scale/centerX/centerY` 协议，并在只更新参数时保留当前径向样式。

### Changed
- 形状规范化只保留明确支持的线性/径向样式；旧的反射或菱形值继续安全降级为线性。径向渐变不显示线性轴控制柄，避免把错误交互伪装成可用功能。
- App、CLI、教程、Figma/MCP 文档、路线图与全部 Xcode target 版本同步为 `2.12.0-rc77`。

### Tests
- 新增径向中心/边缘渲染、形状裁切、样式规范化、属性切换、半径单步 Undo、项目重开、锁定保护、线性控制柄隔离和 MCP 创建/读取/切换测试。
- 形状样式 14/14、MCP 自动化 34/34、三语资源 4/4、CLI 2/2 与隔离 Debug 测试产品构建通过；Debug App 版本、Bundle ID、macOS 13.0 下限和 arm64 架构核对通过。完整 Release、全量冒烟及 `/Applications` 覆盖安装仍按 20 版门槛在 rc80 执行。

## 2.12.0-rc76 - 2026-07-15

### Added
- 形状线性渐变轴支持双击指定位置新增中间色标；新色标按该位置的当前渐变颜色插值生成，并立即成为画布与属性面板的共同选中项。
- 使用移动工具且选中可删除的中间色标时，Delete/Forward Delete 会优先删除该色标；没有可删除色标时继续保留原有对象删除行为。

### Changed
- 指定位置插入与拖动共用同一套画布轴投影，反向渐变会从视觉位置换算到逻辑色标位置；色标仍限制为最多 16 个并保持至少 1% 间距。
- Delete 路由在文字输入控件活动时不再删除画布对象、历史步骤或渐变色标，避免编辑数值与文字时误操作。
- App、CLI、教程、Figma/MCP 文档、路线图与全部 Xcode target 版本同步为 `2.12.0-rc76`。

### Tests
- 新增指定轴位置投影、反向渐变换算、精确插入、单步新增/删除 Undo、锁定保护、双击命中标识和 Delete 文字输入保护测试。
- 形状渐变 13/13、三语资源 4/4、CLI 2/2 与隔离 Debug 测试产品构建通过；Debug App 版本、Bundle ID、macOS 13.0 下限和 arm64 架构核对通过。完整 Release、全量冒烟及 `/Applications` 覆盖安装仍按 20 版门槛在 rc80 执行。

## 2.12.0-rc75 - 2026-07-15

### Added
- 选中多色标线性渐变形状时，中间色标以彩色菱形显示在画布渐变轴上；点击会同步属性面板选择，拖动可直接修改位置并实时预览。

### Changed
- 色标拖动按鼠标到实际显示轴的正交投影计算，支持图层非等比缩放、偏心轴和反向渐变；位置始终限制在相邻色标之间。
- 画布色标拖动使用独立事务：松手只生成一步 History/Undo，无位移点击不写历史，锁定形状拒绝修改；端点控制柄继续只负责方向与跨度。
- App、CLI、教程、Figma/MCP 文档、路线图与全部 Xcode target 版本同步为 `2.12.0-rc75`。

### Tests
- 新增画布色标位置投影、垂直偏移忽略、轴保持、反向渐变映射、实时 ViewModel 更新、单步 Undo、无操作点击、锁定保护和画布交互标识测试。
- 形状渐变 12/12、三语资源 4/4、CLI 2/2 与隔离 Debug 测试产品构建通过；Debug App 版本、Bundle ID、macOS 13.0 下限和 arm64 架构核对通过。完整 Release 与全量冒烟仍按 20 版门槛在 rc80 执行。

## 2.12.0-rc74 - 2026-07-15

### Added
- 形状线性渐变新增最多 16 个有序色标；属性面板提供真实渐变条、色标选择、向最大空档添加、删除中间色标、颜色修改和百分比位置编辑。
- MCP `fillGradient.stops` 支持 2–16 个结构化色标，并继续接受旧的 `startColor/endColor`；读取结果同时返回新旧两种表示以兼容现有客户端。
- Figma `GRADIENT_LINEAR` 可保留 2–16 个 0/1 范围内的有序色标，导入后仍是 Xomo 原生可编辑形状渐变。

### Changed
- 渐变像素渲染改为按相邻色标分段插值；反向渐变会同时镜像色标顺序和位置，首尾颜色继续同步到旧项目字段。
- 旧项目没有 `colorStops` 时自动生成 0%/100% 两个可编辑端点；首尾色标固定位置且不可删除，中间色标限制在相邻色标之间。
- Figma 不同色标透明度、超过 16 个色标和非线性渐变继续明确标记 `unsupportedPaint`，不伪装成无损导入。
- App、CLI、教程、Figma/MCP 文档、路线图与全部 Xcode target 版本同步为 `2.12.0-rc74`。

### Tests
- 新增多色标像素插值、添加/修改/删除、Undo、项目往返、旧双端点解码、属性面板非焦点控件、MCP 数组往返/非法顺序及 Figma 多色标精确导入/透明度降级测试。
- 形状渐变 10/10、Figma 节点导入 17/17、MCP 自动化 33/33、三语资源 4/4、CLI 2/2 通过；隔离 `build-for-testing` 成功。Debug App 为 `2.12.0-rc74`、`im.some.xomo`、macOS 13.0、arm64。完整 Release 与全量冒烟仍按 20 版门槛在 rc80 执行。

## 2.12.0-rc73 - 2026-07-15

### Added
- 选中带线性渐变的形状时，画布显示灰色虚线渐变轴与双色起止控制柄；可直接拖动任一端调整方向、跨度和偏心中心，按住 Shift 以 15° 吸附。
- MCP `xomo.shape.create/get/update` 的 `fillGradient` 新增 `centerX`、`centerY`；Figma 偏心双停止点 `GRADIENT_LINEAR` 可映射为同一原生模型。

### Changed
- 拖动渐变控制柄期间实时预览，未被拖动的一端保持固定；松手只生成一步 History/Undo，锁定形状不会被修改。
- 形状专属渐变中心进入项目保存和旧项目兼容读取；普通渐变填充图层继续默认居中，不受新字段影响。
- 右侧“图层 / 通道 / 路径 / 复合”页签改由原生视图直接绘制浅色富文本，未选中标题使用浅灰白，不再允许 SwiftUI 按钮环境或系统外观把文字染黑。
- App、CLI、教程、Figma/MCP 文档、路线图与全部 Xcode target 版本同步为 `2.12.0-rc73`。

### Tests
- 新增控制柄几何、固定对端、偏心中心、项目/Undo、MCP 往返和 Figma 偏心渐变精确映射测试。
- 形状渐变 7/7、图层面板浅色文字 7/7、Figma 节点导入 17/17、MCP 自动化 33/33、三语资源 4/4、CLI 2/2 通过；隔离 `build-for-testing` 成功。完整 Release 与全量冒烟仍按 20 版门槛在 rc80 执行。

## 2.12.0-rc72 - 2026-07-15

### Added
- 可编辑矩形、椭圆和闭合路径新增原生两色线性渐变填充；属性面板可在纯色与线性渐变间切换，并编辑起始色、结束色、角度和公共填充不透明度。
- MCP `xomo.shape.create/get/update` 新增 `fillKind` 与结构化 `fillGradient`，支持创建、检查、部分更新和安全切回纯色；CLI 离线工具目录同步说明该能力。
- Figma 节点导入可将居中、两端色标、同透明度的 `GRADIENT_LINEAR` 映射为 Xomo 原生可编辑渐变形状。

### Changed
- 形状渐变进入项目保存/重开、Undo/Redo、圆角裁切、独立描边和多选外观更新链；旧项目缺少渐变字段时继续按纯色读取。
- Figma 多色、偏心控制轴、透明度不同、范围超限或非线性渐变继续在逐节点报告中标记 `unsupportedPaint`，不伪装成无损导入。
- App、CLI、教程、Figma/MCP 文档、路线图与全部 Xcode target 版本同步为 `2.12.0-rc72`。

### Tests
- 新增渐变像素方向、公共透明度、圆角裁切、独立描边、项目往返、Undo/Redo、纯色切换、非焦点控件、MCP 参数及 Figma 精确/降级映射测试。
- 形状渐变 6/6、Figma 节点导入 17/17、MCP 自动化 33/33、三语资源 4/4、SwiftPM CLI 2/2 通过；隔离 `build-for-testing` 成功。完整 Release 与全量冒烟仍按 20 版门槛在 rc80 执行。
- Debug App 版本为 `2.12.0-rc72`，Bundle ID 为 `im.some.xomo`，最低系统为 macOS 13.0，可执行文件为 arm64；App、CLI 与全部 Xcode target 版本一致。

## 2.12.0-rc71 - 2026-07-15

### Added
- 形状属性面板新增独立的填充颜色、填充不透明度、描边颜色、描边不透明度和描边宽度控件，全部保持非焦点控件并支持多选形状批量修改。
- MCP `xomo.shape.create/update` 新增独立填充/描边颜色与透明度参数；颜色对象执行有限数值及 0–1 范围校验。

### Changed
- MCP 形状更新改为只修改明确传入的字段，不再借用全局前景色、画笔宽度或通用透明度覆盖未指定的形状外观；旧 `opacity` 参数继续兼容并作用于填充和描边。
- “图层 / 通道 / 路径 / 复合”原生页签先固定深色外观与单元格白色，再写入白色富文本，避免系统外观刷新后把未选中标题染黑。
- App、CLI、教程、路线图与全部 Xcode target 版本同步为 `2.12.0-rc71`。

### Tests
- 新增填充/描边独立像素渲染、属性编辑、项目往返、Undo/Redo、锁定保护、非焦点控件、MCP 创建/部分更新/非法颜色保护和原生页签单元格白字测试。
- 形状样式 4/4、图层标题与页签白字 7/7、矢量形状回归 27/27、MCP 自动化 32/32、三语资源 4/4、SwiftPM CLI 2/2 通过；Debug 测试产品构建成功。
- Debug App 版本为 `2.12.0-rc71`，Bundle ID 为 `im.some.xomo`，最低系统为 macOS 13.0，可执行文件为 arm64；App、CLI 与全部 Xcode target 版本一致。

## 2.12.0-rc70 - 2026-07-15

### Added
- 矩形新增 0–100% 可编辑圆角平滑参数：统一或独立四角都可使用超椭圆曲线渲染，并保持为分辨率无关的原生形状。
- 属性面板可逐百分比调整圆角平滑；项目保存、重开、Undo/Redo、MCP `xomo.shape.create/get/update` 与 CLI 工具目录同步支持该参数。

### Changed
- Figma `cornerSmoothing` 现在会保留为 Xomo 原生参数并生成视觉接近的超椭圆；导入报告继续标记为部分保真，明确它是可编辑近似而非 Figma 私有几何的一比一复刻。
- 圆角半径随图像尺寸缩放，圆角平滑作为无量纲比例保持不变；旧项目缺少该字段时按 0% 圆角平滑读取。

### Tests
- 新增圆形圆角与超椭圆角落像素差异、属性编辑、项目往返、Undo/Redo、缩放不变量、Figma 映射/材质化和 MCP 创建/更新/读取测试。
- 圆角核心 6/6、Figma 节点导入 16/16、MCP 自动化 32/32、三语资源 4/4、SwiftPM CLI 2/2 通过；隔离 `build-for-testing` 与独立 DerivedData 干净 Debug App 构建成功。
- Debug App 版本为 `2.12.0-rc70`，Bundle ID 为 `im.some.xomo`，最低系统为 macOS 13.0，可执行文件为 arm64；App、CLI 与全部 Xcode target 版本一致。

## 2.12.0-rc69 - 2026-07-15

### Added
- 矩形形状新增四角独立圆角模式：属性面板可在统一圆角与左上、右上、右下、左下四个半径之间切换，每个角保持原生可编辑而非栅格化。
- Figma 非对称 `rectangleCornerRadii` 现在映射为 Xomo 原生四角属性；MCP `xomo.shape.create/get/update` 同步接受和返回 `cornerRadii` 对象。

### Changed
- 独立四角进入项目保存、重开、Undo/Redo 与图像缩放链路；旧项目只有 `cornerRadius` 时继续按统一圆角读取。
- Figma 仅在存在 `cornerSmoothing` 时报告圆角部分保真，合法的非对称四角不再被误报为降级。

### Tests
- 新增独立四角像素渲染、属性切换、逐角编辑、项目往返、Undo/Redo、缩放、Figma 映射/材质化及 MCP 参数冲突保护测试。
- 独立四角核心 5/5、Figma 节点导入 16/16、MCP 自动化 32/32、三语资源 4/4、SwiftPM CLI 2/2 通过；隔离 `build-for-testing` 成功，App、CLI 与全部 Xcode target 版本同步为 `2.12.0-rc69`。

## 2.12.0-rc68 - 2026-07-15

### Added
- 矩形形状新增原生统一圆角属性：属性面板可逐像素调整，保持可编辑矢量形状，并进入项目保存、重开、Undo/Redo 和图像缩放链路。
- Figma `cornerRadius` 与四角值相同的 `rectangleCornerRadii` 现在映射为 Xomo 原生矩形圆角；Frame/Component 背景形状也复用同一语义。
- MCP `xomo.shape.create/get/update` 与 CLI 工具目录同步支持统一矩形圆角，创建或更新仍各自只产生一个 Undo 步骤。

### Changed
- 非对称四角与 `cornerSmoothing` 继续明确报告为部分保真；可用的统一半径仍会保留，但不会把尚未支持的独立四角或平滑曲线冒充完整导入。
- 圆角半径按矩形短边的一半约束，调整图片尺寸时与形状、描边一同等比例缩放；锁定形状不会被属性面板改写。

### Tests
- 新增圆角像素渲染、属性编辑、范围约束、锁定保护、项目往返、Undo/Redo、图像缩放和属性面板入口测试。
- 更新 Figma 映射、材质化、项目往返与缩放断言，并新增统一四角、非对称四角和 corner smoothing 的保真度测试。
- 圆角核心 4/4、Figma 节点导入 16/16、MCP 自动化 32/32、三语资源 4/4、SwiftPM CLI 2/2 通过；隔离 `build-for-testing` 成功，App、CLI 与全部 Xcode target 版本同步为 `2.12.0-rc68`。

## 2.12.0-rc67 - 2026-07-15

### Fixed
- 图层面板的“搜索图层”占位文字和用户输入改由显式深色外观的 AppKit 文本框绘制，避免 SwiftUI 在 macOS 原生控件环境下重新套用深色前景色。
- 搜索框继续保留实时过滤与键盘输入能力；只移除系统焦点光圈，不影响文本框正常获得输入焦点。

### Tests
- 新增 AppKit 搜索框外观测试，验证占位文字、输入文字、深色外观、控件标识和无边框样式；图层面板样式专项 7/7、SwiftPM CLI 2/2 通过。
- 隔离 `build-for-testing` 成功；App、CLI 与全部 Xcode target 版本同步为 `2.12.0-rc67`。

## 2.12.0-rc66 - 2026-07-15

### Added
- Figma 图片填充新增视觉烘焙：REST `STRETCH + imageTransform` 按二维仿射矩阵还原移动、缩放和裁切，`TILE + scalingFactor` 按图片原始像素尺寸重复铺排。
- Fill、Fit 与 Tile 图片填充在缩放或铺排前应用 Figma 的 90°旋转；导入后仍落为普通像素层，可继续保存、导出和整批撤销。

### Changed
- 图片填充计划现在保留经过有限值与幅度校验的变换矩阵、铺排比例和旋转参数，供本地烘焙使用；参数不会作为凭据或远端引用写入项目。
- Crop、Tile 与旋转仍标记为“已烘焙”而非原生可编辑图片填充，避免把视觉还原误称为完整 Figma 语义兼容。

### Tests
- 新增图片参数映射、Crop 像素裁切、Tile 重复铺排和 90°旋转像素结果测试；既有下载安全、失败占位和项目往返测试继续执行。
- 图片填充专项 8/8、Figma 全链路 44/44、三语资源 4/4、SwiftPM CLI 2/2 通过；Debug 测试产品构建成功，App/CLI 版本为 `2.12.0-rc66`，Bundle ID 为 `im.some.xomo`，最低系统为 macOS 13.0，Debug App 为 arm64。

## 2.12.0-rc65 - 2026-07-15

### Added
- Auto Layout 直接子项新增主轴“固定 / 填满容器”和交叉轴“固定 / 填满容器”尺寸模式；属性面板可在选中子项时直接切换，并立即重排父组。
- 固定主轴容器中的多个 Fill 子项按 Figma `layoutGrow` 权重分配扣除固定子项、间距与内距后的剩余空间；Stretch 子项在固定交叉轴容器中填满内框。

### Changed
- Figma `layoutGrow` 与 `layoutAlign=STRETCH` 现在映射为可编辑、可保存的原生子项布局，不再误报为固定尺寸降级；Wrap 与 Baseline 仍在逐节点报告中明确降级。
- Fill 子项改变外框时，像素、文字与形状层使用新外框；嵌套组整体移动并在自身具有 Auto Layout 时递归重排。父轴为 Hug 时 Fill 暂保留导入尺寸，避免循环尺寸依赖。

### Tests
- 新增 Fill 权重分配、交叉轴 Stretch、属性面板切换、父组即时重排、项目往返、Undo/Redo 和 Figma 子项映射测试。
- Auto Layout 专项 10/10、图层标题与页签白字 6/6、Figma 全链路 40/40、三语资源 4/4、SwiftPM CLI 2/2 和独立 DerivedData 干净 Debug 构建通过；App/CLI 版本为 `2.12.0-rc65`，Bundle ID 为 `im.some.xomo`，最低系统为 macOS 13.0，Debug App 为 arm64。

## 2.12.0-rc64 - 2026-07-15

### Added
- Auto Layout 组新增主轴、交叉轴“固定 / 适应内容”尺寸模式；Figma 的 `primaryAxisSizingMode=AUTO` 与 `counterAxisSizingMode=AUTO` 会映射为原生 Hug 容器，属性面板可直接切换。
- 重新排列时，Hug 容器会依据直接流式子项、间距和四边内距重新计算组宽高；嵌套组按自身外框参与计算，绝对定位子项不参与。

### Changed
- Figma Frame 的合成背景层现在带有独立布局背景标记。Hug 改变组边界时，背景会同步调整到新边界；普通绝对定位子项保持原位置和大小。
- rc63 项目中没有尺寸模式字段的 Auto Layout 数据继续按“固定”解码；Wrap、Fill/Stretch 与 Baseline 仍在导入报告中明确按固定尺寸降级。

### Tests
- 新增双轴 Hug 尺寸计算、组与背景同步缩放、嵌套子树重排、Undo/Redo、项目往返、rc63 兼容解码和属性面板入口测试。
- Auto Layout 专项 8/8、Figma 全链路 40/40、三语资源 4/4、SwiftPM CLI 2/2 通过；Debug 测试产品构建成功，App/CLI 版本为 `2.12.0-rc64`，Bundle ID 为 `im.some.xomo`，最低系统为 macOS 13.0，Debug App 为 arm64。

## 2.12.0-rc63 - 2026-07-15

### Added
- Figma 水平与垂直 Auto Layout 现在会导入为 Xomo 原生组布局，保留固定容器尺寸、子项顺序、间距、四边内距、主轴对齐与交叉轴对齐；属性面板可直接修改并重新排列，整次变化支持 Undo/Redo。
- 自动布局组及“绝对定位/背景”排除标记进入项目保存与重开链路；直接嵌套组移动时会连同完整后代一起移动，不会拆散组件结构。

### Changed
- Wrap、Hug/Fill、Baseline、Stretch 等尚未原生实现的约束继续按固定尺寸导入，并在逐节点报告中明确降级；支持的基础水平/垂直布局不再误报为全部扁平化。

### Fixed
- 图层面板“图层 / 通道 / 复合 / 路径”标签继续使用白色富文本，并固定为深色 AppKit 外观，避免 macOS 按钮环境把未选中文字重新染成黑色。

### Tests
- 新增布局引擎、间距/内距/对齐、嵌套组移动、背景排除、项目持久化、Undo/Redo、属性面板入口与图层白字契约测试。
- Auto Layout 专项 5/5、图层标题与页签白字 6/6、Figma 全链路 40/40、三语资源 4/4、SwiftPM CLI 2/2 通过；Debug 测试产品构建成功，App/CLI 版本为 `2.12.0-rc63`，Bundle ID 为 `im.some.xomo`，最低系统为 macOS 13.0，Debug App 为 arm64。

## 2.12.0-rc62 - 2026-07-15

### Added
- Figma 节点读取现在会在用户明确操作后调用官方 `GET /v1/files/:key/images`，把所选节点子树引用的图片填充下载为真实像素图层；资源进入现有项目编码、重开与合成导出链路，不再一律停留在格纹占位层。

### Security
- PAT 只发送给官方图片清单端点；临时图片下载请求不携带 PAT、Authorization、Cookie 或浏览器会话，只接受无凭据、无自定义端口的 HTTPS URL，并拒绝 localhost、`.local` 与 IP 字面量；同时限制 24 个引用、单图 20 MB、总计 80 MB、最长边 16384 像素及 6400 万像素。
- 单张 URL 不安全、下载失败、响应非图片或超限时，不写入项目或日志，也不让整批导入失败；对应节点保留明确的图片占位层和降级原因。

### Changed
- 下载成功的图片填充在导入报告中显示为“图片像素层”，基础 Fill/Fit 会按目标图层尺寸烘焙；报告明确它已成为固定像素层，不冒充仍可编辑的原生 Figma 填充参数。

### Tests
- 新增官方清单请求、无凭据资源下载、恶意/本机 URL 拒绝、无效图片拒绝、真实像素层物化、项目保存重开和失败占位降级测试。
- Figma 全链路隔离测试 39/39、三语资源 4/4、SwiftPM CLI 2/2 通过；Debug 测试产品构建成功，App/CLI 版本为 `2.12.0-rc62`，Bundle ID 为 `im.some.xomo`，最低系统为 macOS 13.0，Debug App 为 arm64。

## 2.12.0-rc61 - 2026-07-15

### Fixed
- 将 Figma 节点 ID 的纯校验辅助方法，以及 SVG 路径的结果、词法、语法与弧线转换类型明确标记为 `nonisolated`，消除 Swift 6 在 `allSatisfy`、`compactMap` 方法引用及解析链内部的 actor-isolation 预警；解析结果、网络权限与导入行为不变。

### Tests
- SVG 路径覆盖用例改为从非主线程隔离测试方法调用解析入口，固定纯解析器不依赖 `MainActor` 的编译契约；Figma 链接、授权、节点映射、项目恢复与导出专项隔离测试 35/35 通过。
- SwiftPM CLI 2/2 通过且版本输出为 `2.12.0-rc61`；arm64/x86_64 通用 Release App 编译成功且不再报告 actor-isolation 预警，产物版本、Bundle ID `im.some.xomo`、macOS 13.0 下限和双架构核对通过。

## 2.12.0-rc60 - 2026-07-15

### Changed
- 将第 60 个小版本设为 Figma 可编辑导入闭环的完整质量门禁，不在同一版继续扩大远端读取范围；先固定已导入层级的撤销/重做、项目保存重开和合成导出契约，再决定图片资源或 Auto Layout 的下一条窄路径。

### Tests
- Figma 节点导入回归新增 Redo、实际 `.xomoproject` 编码/解码、层级与可编辑类型恢复、PNG 合成导出及项目数据不携带 PAT/请求头的验证。
- Debug `build-for-testing`、全量隔离单元测试 817/817 和 SwiftPM CLI 2/2 通过；arm64/x86_64 通用 Release App 与通用 Release CLI 均构建成功。App/CLI 版本为 `2.12.0-rc60`，Bundle ID 为 `im.some.xomo`，最低系统为 macOS 13.0，两个 Release 可执行文件均包含 arm64 与 x86_64。
- Computer Use 启动 rc60 Debug App，真实检查图层标题与四页签浅色可读、Figma 链接清理与无凭据禁用状态、组件插入后的组/文字/形状三层结构、画布对象点击自动选层，以及缩放工具条从 100% 到 120% 再缩回 100% 持续可点击；未输入令牌或发起网络请求。
- 通用 Release 编译仍报告两处非阻断的 Swift 6 actor-isolation 预警，涉及纯解析辅助方法；为保证全量门禁对应同一份源码，本版不在测试后临时改实现，留给独立小版本清理。

## 2.12.0-rc59 - 2026-07-15

### Added
- “导入 Figma 链接”可在用户明确点击后通过官方 `GET /v1/files/:key/nodes` 读取链接中 `node-id` 对应的子树，并在修改画布前展示逐节点的完整、降级与不支持映射报告。
- 映射计划可再次确认导入：Frame、Group 与组件建立嵌套图层组，Text 建立可编辑文字层，Rectangle、Ellipse 和常见 SVG 路径建立可编辑形状层；纯色填充、描边、文字字体/字重/对齐、显隐、透明度和固定坐标得到保留。
- 新增 SVG 路径解析器，覆盖绝对/相对 Move、Line、Horizontal、Vertical、Cubic、Smooth Cubic、Quadratic、Smooth Quadratic、Arc 与 Close 命令；图片填充暂以明确的格纹交叉占位层导入。

### Security
- 节点读取必须由包含 `node-id` 的可信规范链接、已存入 macOS 钥匙串的个人 PAT 和显式“读取”按钮共同触发；打开 Sheet、粘贴链接、预览或导入本地计划都不会自动联网。
- 请求固定使用 `ids`、`depth=6` 与 `geometry=paths`，可选版本只来自已校验链接；要求 `file_content:read`，最多接受 10 MB 响应和 2000 个节点，并对授权、限流、服务错误与畸形树分别失败。

### Changed
- 节点透明度与填充/描边透明度分开保存，矢量几何按官方节点局部尺寸缩放，避免重复衰减或错误裁切；不支持的节点、复杂填充、旋转/镜像/倾斜变换、圆角、蒙版、效果、混合模式、Auto Layout 与组件语义都会在确认前列出，不冒充无损还原。
- 一次节点导入只产生一个 History/Undo 步骤；根节点默认居中，只有超出画布安全区域时才等比缩小，层级与父组关系保持可继续编辑。

### Tests
- 新增官方节点请求边界、状态码、响应/节点上限、层级映射、降级原因、SVG 命令解析、画布坐标/等比适配、图层类型、占位层、项目保存恢复以及单步 Undo 的单元测试。
- Figma 链接/授权/元数据/节点导入 34/34、图层标题与页签白字 6/6、三语资源 4/4、Ruby 页签契约 4/4、CLI 2/2 通过；Debug `build-for-testing` 成功，App/CLI 版本均为 `2.12.0-rc59`，Bundle ID 为 `im.some.xomo`，最低系统为 macOS 13.0，Debug App 为 arm64。
- Computer Use 启动 rc59 Debug App，通过 `Option + Command + F` 打开 Sheet 并输入不含凭据的本地示例链接；实测规范 URL、参数清理、`file_metadata:read` / `file_content:read` 边界、节点/响应上限和“先预检、再导入”文案正确，未输入令牌或发起网络请求。

## 2.12.0-rc58 - 2026-07-15

### Added
- “导入 Figma 链接”预览新增用户显式发起的官方文件元数据读取：连接后可核对远端文件名、文件夹、最近修改时间、编辑器类型、版本、当前角色和链接访问级别。
- 新增本机个人连接入口。用户自行粘贴 Figma Personal Access Token，凭据只保存在 macOS 钥匙串，不进入项目文件、偏好、日志、测试报告或规范化 URL。

### Security
- rc58 仅调用 `GET /v1/files/:key/meta`，要求最小 `file_metadata:read` scope；打开 Sheet、粘贴链接和切换预览都不会自动联网，只有“保存并读取”或“读取元数据”按钮会访问 `api.figma.com`。
- 网络层禁用 Cookie、URL Cache 和重定向跟随，限制响应为 2 MB，并将 401/403、404、429、5xx、畸形响应和传输失败分别归类；断开连接会删除钥匙串凭据并清除旧元数据。
- 界面明确区分“本机个人 PAT 连接”和尚未接入的多人 OAuth 商业连接，不读取浏览器登录状态，也不把个人令牌伪装成团队授权。

### Changed
- Figma 预览 Sheet 使用可滚动内容与固定操作区，在较小窗口中仍可访问授权、读取、断开与复制操作。
- 复核当前源码中的图层面板标题和“图层 / 通道 / 复合 / 路径”页签均使用显式白色文字；用户截图来自仍安装在 `/Applications` 的 rc52，而非当前调试产物。

### Tests
- 新增个人令牌边界、最小权限请求、状态码映射、响应上限、显式联网门槛、钥匙串隔离和旧状态清理测试，并保留既有链接解析/预览安全回归。
- Figma 授权/链接 21/21、图层白字 6/6、三语资源 4/4、CLI 2/2 与 Ruby 页签契约 4/4 通过；Debug `build-for-testing` 成功，App/CLI 版本均为 `2.12.0-rc58`，Bundle ID 为 `im.some.xomo`，最低系统为 macOS 13.0。
- Computer Use 启动 rc58 Debug App，实测图层标题与四个页签均为浅色；`Option + Command + F` 打开 Sheet 后，本地解析、规范化 URL、安全令牌框和最小权限说明正确出现，过程中未输入令牌或发起网络读取。

## 2.12.0-rc57 - 2026-07-15

### Added
- “文件”菜单新增“导入 Figma 链接…”预览入口，并提供不与既有图像尺寸命令冲突的 `Option + Command + F` 快捷键。
- 新增 Figma 链接预览 Sheet：粘贴或输入后立即显示资源类型、文件名称与 Key、节点、原型起点、版本、后续导入范围、被清理参数数和规范化链接。
- 有效链接可复制已剥离非白名单参数的规范化 URL；界面明确标注访问权限尚未检查，当前不联网、不读取浏览器会话且不创建图层。

### Changed
- Figma 解析错误、资源类型、计划范围与权限状态全部接入中、英、日三语资源，不在 SwiftUI 中硬编码用户可见文案。
- 实际运行核验右侧“图层 / 通道 / 复合 / 路径”标题与页签继续使用白色/浅灰文字，避免深色面板出现黑字。

### Tests
- Figma 链接解析、预览状态、菜单/Sheet 接线、无冲突快捷键与安全边界 13/13 通过；三语资源 4/4、SwiftPM CLI 2/2 通过，Debug `build-for-testing` 成功。
- Computer Use 启动 rc57 Debug App，使用 `Option + Command + F` 打开预览，实测即时解析、敏感 query 清理、规范化链接复制反馈和深色图层页签文字。
- 核对 Debug App 与 CLI 版本均为 `2.12.0-rc57`；App Bundle ID 为 `im.some.xomo`、最低系统为 macOS 13.0、架构为 arm64。

## 2.12.0-rc56 - 2026-07-15

### Added
- 新增纯本地 `XomoFigmaLinkParser` 与可编码的只读链接预览模型，识别 Figma Design、旧版 File、Prototype、FigJam、Slides、Sites、Buzz 与 Make 文件路径。
- 解析结果提供资源类型、文件 Key、文件名、节点、原型起点、版本、计划导入范围和规范 URL；URL 节点 ID 会转换为 Figma API 使用的冒号形式。
- 新增 [FIGMA_LINK_IMPORT.md](FIGMA_LINK_IMPORT.md)，固定 rc56–rc60 的链接预览、用户授权、节点映射、降级报告与完整质量门槛。

### Security
- 只接受 `figma.com` / `www.figma.com` 的 HTTPS 链接，拒绝仿冒后缀域名、URL 凭据、自定义端口、fragment、重复选择参数、畸形标识和超长输入。
- 规范 URL 与预览模型只保留 `node-id`、`starting-point-node-id` 和 `version-id`；其余 query 名和值全部丢弃，避免令牌或跟踪数据进入项目、日志和持久化模型。
- rc56 不联网、不读取浏览器会话、不检查或绕过 Figma 权限，授权状态明确保持为 `notChecked`。

### Tests
- 新增 8 项 Figma 链接解析测试，覆盖官方资源路径、节点/版本规范化、敏感参数剥离、Codable 往返、域名伪装、凭据、端口、歧义选择器和输入上限。
- Figma 链接解析与安全边界 8/8、三语资源 4/4、SwiftPM CLI 2/2 通过，Debug `build-for-testing` 通过。
- 核对 Debug App 与 CLI 版本均为 `2.12.0-rc56`；App Bundle ID 为 `im.some.xomo`、最低系统为 macOS 13.0、架构为 arm64。

## 2.12.0-rc55 - 2026-07-15

### Added
- 路径面板中的保存路径可直接拖拽到目标行上方或下方，拖动目标使用高亮落点反馈。

### Changed
- 拖放落点会在移除源路径后重新计算精确索引，并复用现有路径重排命令，成功移动保持当前选择且只形成单步 History/Undo/Redo；原地和无效拖放不修改文档。
- “图层 / 通道 / 路径 / 复合”页签改用带显式白色前景色的富文本原生标签，避免深色界面运行时被系统按钮环境染成黑字。
- 产品路线明确为 Photoshop 像素与图层底座、Sketch 组件/画板、Fireworks 切片交付和 Figma 组件/变量/链接交换能力组成的现代混合编辑器；Figma 链接按安全解析、只读预览、授权读取和分层映射逐步实现。

### Tests
- 新增路径拖放向上、向下、移除前索引修正、原地和越界无副作用测试，以及拖放入口源码回归断言。
- 图层页签样式测试新增富文本前景色断言，既验证 `NSTextField.textColor`，也验证真正参与运行时绘制的 attributed string 颜色。
- 保存路径 28/28、图层页签样式 6/6、三语资源 4/4、SwiftPM CLI 2/2 与 Ruby 页签源码检查 4/4 通过。
- 使用全新 DerivedData 完成 Debug 构建，核对 App 版本 `2.12.0-rc55`、Bundle ID `im.some.xomo`、最低 macOS 13.0 和 arm64 架构；Computer Use 实际启动该产物，确认四个页签均显示白字。

## 2.12.0-rc54 - 2026-07-15

### Added
- `xomo.path.saved` 返回的每条保存路径新增零基 `index`，自动化可直接读取面板、项目持久化与固定轮廓绘制栈中的确切位置。
- 新增 `moveToIndex` 动作与 `index` 参数，可按路径 UUID 一次移动到指定零基位置。

### Changed
- 精确移动复用现有保存路径重排核心，成功后保持选择并形成单步 History/Undo/Redo；同位置、负数、小数和越界索引均在修改文档前拒绝。
- MCP 运行时 schema 同步公布 `moveToIndex` 和整数型 `index`，避免客户端把小数静默截断成另一个位置。

### Tests
- 新增业务层精确移动、Undo/Redo、无效目标无副作用，以及 MCP schema、返回索引、精确顺序和参数拒绝测试。
- 保存路径与既有工作流 27/27、真实 MCP 1/1、三语资源 4/4、SwiftPM CLI 2/2 通过；Debug `build-for-testing` 通过。
- 核对 Debug App/CLI 版本为 `2.12.0-rc54`、Bundle ID 为 `im.some.xomo`、最低系统为 macOS 13.0，Debug App 为 arm64 架构。

## 2.12.0-rc53 - 2026-07-15

### Added
- `xomo.path.saved` 新增 `moveUp`、`moveDown`、`moveToTop`、`moveToBottom`，MCP/CLI 可按保存路径 UUID 调整路径列表与固定轮廓绘制顺序。

### Changed
- 四种自动化排序动作直接复用路径面板的可撤销重排命令，保持当前路径选择，每次成功移动只写一条 History；路径不存在返回未找到，已在目标边界则明确失败且不修改文档。
- MCP 工具 schema 同步公布四种新动作，自动化客户端无需猜测未声明的参数值。

### Tests
- 新增运行时 schema、四向排序结果、选择保持、单步 History 与边界无副作用测试。
- 保存路径 MCP 新旧工作流及相关独立性回归 11/11、三语资源 4/4、SwiftPM CLI 2/2 通过；Debug `build-for-testing` 通过。
- 核对 Debug App/CLI 版本为 `2.12.0-rc53`、Bundle ID 为 `im.some.xomo`、最低系统为 macOS 13.0，Debug App 为 arm64 架构。

## 2.12.0-rc52 - 2026-07-14

### Added
- 路径面板和“路径”菜单新增“创建路径副本”，无需读写或覆盖系统剪贴板即可直接复制选中的独立路径。
- `xomo.path.saved` 新增 `duplicate` 动作，CLI/MCP 可使用保存路径 UUID 创建同样的独立副本。

### Changed
- 路径副本生成新 UUID、保留开放/闭合结构、复合子路径和贝塞尔控制柄，紧跟原路径插入并自动选中；副本默认不固定显示，重名按当前语言生成唯一名称。
- 直接复制形成单步 History 并支持 Undo/Redo；达到 100 条容量上限或目标不存在时在修改前拒绝，不留下半成品。
- 图层面板标题和“图层 / 通道 / 复合 / 路径”页签继续强制使用纯白文字，并补强样式应用回归；修正测试仍按旧的 3 个页签计数的问题。

### Tests
- 新增直接复制的相邻顺序、身份隔离、结构保真、容量拒绝和 Undo/Redo 单元测试，并扩展真实 MCP 保存路径工作流覆盖 `duplicate`。
- 保存路径与既有工作流 26/26、真实 MCP 1/1、图层面板白色文字 6/6、三语资源 4/4 和 SwiftPM CLI 2/2 通过；Debug `build-for-testing` 通过。
- 核对 Debug App/CLI 版本为 `2.12.0-rc52`、Bundle ID 为 `im.some.xomo`、最低系统为 macOS 13.0，Debug App 为 arm64 架构。

## 2.12.0-rc51 - 2026-07-14

### Added
- 路径面板和“路径”菜单新增“移到列表顶部”“移到列表底部”，长路径列表可用一次操作完成跨项排序。

### Changed
- 相邻上移/下移和顶部/底部跳转统一使用移除后插入的重排逻辑；面板行序、项目顺序与固定轮廓绘制栈继续共享唯一数组。
- 顶部/底部跳转保持当前路径选择并形成单步 History，支持 Undo/Redo；已在目标边界时按钮禁用，直接调用也不会修改文档。

### Tests
- 保存路径快速排序与既有路径工作流 24/24、三语资源 4/4 和 SwiftPM CLI 2/2 通过；Debug `build-for-testing` 通过。
- 核对 Debug App/CLI 版本为 `2.12.0-rc51`、Bundle ID 为 `im.some.xomo`、最低系统为 macOS 13.0，Debug App 为 arm64 架构。

## 2.12.0-rc50 - 2026-07-14

### Added
- 路径面板底部和“路径”菜单新增上移、下移；保存路径的列表顺序现在可以直接调整，多条固定轮廓按同一顺序稳定绘制。

### Changed
- 路径重排保持当前选择并作为单步 History 支持 Undo/Redo；首项上移、末项下移会禁用，直接调用也不会修改路径或写入 History。
- 面板行序、项目保存顺序与画布叠放顺序共用文档中的唯一数组，不引入容易失配的第二套层级状态。

### Tests
- 保存路径重排与既有路径工作流 23/23、三语资源 4/4 和 SwiftPM CLI 2/2 通过；第 50 个小版本从空 DerivedData 完成 clean Debug `build-for-testing`。
- 核对干净 Debug App/CLI 版本为 `2.12.0-rc50`、Bundle ID 为 `im.some.xomo`、最低系统为 macOS 13.0，Debug App 为 arm64 架构。

## 2.12.0-rc49 - 2026-07-14

### Added
- 路径面板和“路径”菜单新增独立路径复制、粘贴；自有剪贴板载荷保存开放/闭合状态、复合子路径、画布坐标以及每个锚点的入/出贝塞尔控制柄，可在同一或不同 Xomo 文档间复用。

### Changed
- 粘贴路径会生成新 UUID、自动选中新副本、默认取消固定轮廓并写入可撤销 History；同名路径按当前语言生成“副本”名称，长名称仍受 80 字符上限约束。
- 复制路径不修改文档或 History；无效/损坏载荷与 100 条路径容量上限均在写入前拒绝，不留下半成品。

### Tests
- 保存路径复制粘贴与既有路径工作流 21/21、三语资源 4/4 和 SwiftPM CLI 2/2 通过；Debug `build-for-testing` 通过。
- 核对 Debug App/CLI 版本为 `2.12.0-rc49`、Bundle ID 为 `im.some.xomo`、最低系统为 macOS 13.0，Debug App 为 arm64 架构。

## 2.12.0-rc48 - 2026-07-14

### Added
- 选中的独立保存路径现在会在画布轮廓上显示全部锚点、入控制柄和出控制柄；直线与贝塞尔结构都能直接辨认，复合子路径按各自保存坐标完整展示。

### Changed
- 保存路径锚点采用中性灰方形标记，控制柄使用细灰色虚线和较小端点，与可编辑路径的蓝色交互锚点明确区分；本版反馈完全只读，不接受鼠标命中。
- 只有当前选中的保存路径显示锚点与控制柄；眼睛固定但未选中的路径继续只显示克制轮廓，关闭“显示额外内容”统一隐藏。显示过程不修改像素、图层、保存路径或 History。

### Tests
- 保存路径锚点与既有路径工作流 19/19、三语资源 4/4 和 SwiftPM CLI 2/2 通过；Debug `build-for-testing` 通过。
- 核对 Debug App/CLI 版本为 `2.12.0-rc48`、Bundle ID 为 `im.some.xomo`、最低系统为 macOS 13.0，Debug App 为 arm64 架构。

## 2.12.0-rc47 - 2026-07-14

### Added
- 独立路径列表每行新增眼睛按钮，可把任意保存路径固定显示在画布上；多条固定路径可同时叠加，当前选中路径即使未固定也继续临时显示。
- `xomo.path.saved` 新增 `visibility` 动作和 `visible` 参数；列表结果新增持久化的 `visible` 与考虑当前选择和“显示额外内容”后的 `overlayVisible`，MCP 工具总数保持 112。

### Changed
- 路径固定可见状态随项目保存，更新路径时不会丢失；旧项目缺少该字段时默认关闭。切换眼睛只更新显示状态和状态栏，不增加文档 History，也不修改像素或图层。
- 多路径轮廓按路径列表稳定顺序绘制；选中项使用更清晰的灰色，未选中的固定项使用更克制的灰色，关闭“显示额外内容”仍会统一隐藏。

### Tests
- 保存路径可见性、旧项目兼容与既有路径工作流 18/18、真实 MCP 注册表 1/1、三语资源 4/4 和 SwiftPM CLI 2/2 通过；Debug `build-for-testing` 通过。
- 核对 Debug App/CLI 版本为 `2.12.0-rc47`、Bundle ID 为 `im.some.xomo`、最低系统为 macOS 13.0，Debug App 为 arm64 架构。

## 2.12.0-rc46 - 2026-07-14

### Added
- “路径”页签中选中的独立命名路径现在会以非破坏性的中性灰轮廓直接叠加在画布上；直线、贝塞尔曲线、开放路径、闭合路径和复合子路径均按保存的画布坐标准确显示。

### Changed
- 保存路径轮廓位于选区边缘之上、对象变换框之下，使用深色底线与细灰色前景线兼顾明暗图片和透明棋盘格；叠加层不接收鼠标事件、不写入像素、不新增图层或 History。
- 轮廓遵守“显示额外内容”：切换保存路径会即时更新，取消选择、删除路径或关闭额外内容后立即隐藏。

### Tests
- 保存路径轮廓及既有路径工作流 16/16、三语资源 4/4 和 SwiftPM CLI 2/2 通过；Debug `build-for-testing` 通过。
- 核对 Debug App/CLI 版本为 `2.12.0-rc46`、Bundle ID 为 `im.some.xomo`、最低系统为 macOS 13.0，Debug App 为 arm64 架构。

## 2.12.0-rc45 - 2026-07-14

### Added
- 独立命名路径新增直接填充与描边：闭合路径可用当前前景色和不透明度填充当前像素层，开放或闭合路径可按当前画笔宽度描边；均不创建临时路径图层。
- 路径面板底部与路径菜单新增填充/描边入口；`xomo.path.saved` 同步增加 `fill`、`stroke` 动作，MCP 工具总数保持 112。

### Changed
- 当前路径图层与保存路径复用同一套坐标换算和渲染提交入口；操作保持当前图层选择和图层数量，尊重像素锁、组继承锁与透明像素锁，并只增加一个 History/Undo 步骤。
- 填充只接受闭合路径；描边接受开放或闭合路径。目标不是可编辑像素层时，界面禁用且自动化调用在修改文档前失败。

### Tests
- 保存路径填充/描边 14/14、旧路径图层渲染回归 2/2、真实 MCP 注册表 1/1、三语资源 4/4 和 SwiftPM CLI 2/2 通过；第 45 个小版本的全新 DerivedData 干净 Debug `build-for-testing` 通过。
- 核对干净 Debug App 版本为 `2.12.0-rc45`、Bundle ID 为 `im.some.xomo`、最低系统为 macOS 13.0，App 为 arm64 架构。

## 2.12.0-rc44 - 2026-07-14

### Added
- 独立命名路径新增“从路径建立选区”：闭合路径可从路径面板或路径菜单直接栅格化为选区，不插入临时路径图层，也不改变当前图层选择。
- `xomo.path.saved` 新增 `selection` 动作，通过路径 ID 调用同一业务入口；MCP 工具总数保持 112。

### Changed
- 当前路径图层与独立保存路径复用同一套画布坐标栅格化和选区组合入口；替换、相加、相减、相交模式与既有 History/Undo 语义保持一致。
- 开放路径不能建立封闭选区，界面按钮禁用，直接调用会在修改文档和撤销栈前明确失败。

### Tests
- 保存路径直选区 9/9、旧路径图层转选区回归 1/1、真实 MCP 注册表 1/1、三语资源 4/4 和 SwiftPM CLI 2/2 通过；核对 Debug App/CLI 版本为 `2.12.0-rc44`、Bundle ID 为 `im.some.xomo`、最低系统为 macOS 13.0，Debug App 为 arm64 架构。

## 2.12.0-rc43 - 2026-07-14

### Added
- 新增独立命名路径：可把当前可编辑路径保存为画布坐标快照，并在“路径”页签中选择、重命名、更新、载入或删除；最多保存 100 条，删除源路径图层后仍可恢复为新的可编辑路径图层。
- 新增 `xomo.path.saved` MCP/CLI 工具，统一提供 `list`、`save`、`select`、`rename`、`update`、`load` 与 `delete` 动作，并返回完整画布坐标子路径；MCP 工具总数从 111 增至 112。

### Changed
- 项目格式升级到 v6，新增可选的命名路径和当前路径选择字段；旧 v5 项目缺少这些字段时按空路径列表载入。保存项保持独立快照语义，只有明确“更新”才会被当前路径改写。
- 图层面板扩展为“图层 / 通道 / 复合 / 路径”四页签；路径名称输入明确使用深色主题浅色文字，操作按钮继续拒绝键盘焦点。

### Tests
- 独立路径 5/5、真实 MCP 注册表 1/1、项目文档回归 8/8、三语资源 4/4 和 SwiftPM CLI 2/2 通过；核对 Debug App/CLI 版本为 `2.12.0-rc43`、Bundle ID 为 `im.some.xomo`、最低系统为 macOS 13.0，Debug App 为 arm64 架构。

## 2.12.0-rc42 - 2026-07-14

### Added
- `.xomostyles` 文件选择后新增导入预览确认页：显示文件名、总数、将导入、重复、容量不足和跳过总数，并逐项标记“可导入 / 已存在 / 容量已满”；用户确认前不会修改工作区预设或文档 History。
- `xomo.layer.style` 新增只读 `presetImportPreview` 动作，返回 `total`、`importable`、`duplicates`、`capacitySkipped`、`skipped` 及逐项 `outcome`；既有 `presetImport` 继续作为明确执行写入的动作。

### Changed
- 导入预检与实际导入共用同一份计划模型；文件内重复项会与本机预设及前面已计划项一起判重，容量冲突单独统计，确认后使用预检生成的稳定顺序和新 ID 写入。

### Tests
- 图层样式预设、导入预检、管理器与真实 MCP 调用 25/25，三语资源 4/4、SwiftPM CLI 2/2 通过；核对 Debug App/CLI 版本为 `2.12.0-rc42`、Bundle ID 为 `im.some.xomo`、最低系统为 macOS 13.0，Debug App 为 arm64 架构。

## 2.12.0-rc41 - 2026-07-14

### Added
- 图层样式预设新增收藏入口：内置和自定义样式都可在管理器列表或检查器中切换星标，并在图层样式菜单中直接访问收藏；收藏属于工作区偏好，不写入文档 History。
- 新增最多 8 项的“最近使用”：成功应用预设后按最新优先自动去重，管理器和图层样式菜单均可快速回访；删除自定义预设时同步清理失效的收藏与最近记录。
- `xomo.layer.style` 新增 `presetFavorite`、`presetFavorites` 与 `presetRecent` 动作；目录结果新增 `favorite`、`recent` 标记，MCP/CLI 与图形界面共享同一份持久化状态。

### Changed
- 预设管理器的“全部 / 收藏 / 最近使用”集合可与名称搜索及“全部 / 内置 / 自定义”来源筛选组合；收藏保持目录顺序，最近使用严格保持实际使用顺序。

### Tests
- 图层样式预设、管理器、查询、收藏/最近使用和真实 MCP 注册表调用 24/24，通过三语资源测试 4/4 与 SwiftPM CLI 2/2；核对 Debug App/CLI 版本为 `2.12.0-rc41`、Bundle ID 为 `im.some.xomo`、最低系统为 macOS 13.0，Debug App 为 arm64 架构。

## 2.12.0-rc40 - 2026-07-14

### Added
- 图层样式预设管理器新增即时搜索，匹配不区分大小写和重音符号；搜索结果保持内置和自定义预设的原始稳定顺序。
- 新增“全部 / 内置 / 自定义”来源筛选、可见项计数和无结果提示；筛选隐藏当前预设时自动选择第一个可见项，无匹配项时清空检查器选择，避免继续操作不可见预设。
- 新增确定性的 Debug UI 测试入口，仅在测试启动参数明确开启时自动展示预设管理器，用真实 macOS 界面验证搜索和来源切换。

### Changed
- 作为第 40 个经典 Photoshop 小版本，本版执行干净 Debug、arm64/x86_64 通用 Release、全量隔离单元测试、SwiftPM CLI 测试与真实界面冒烟门槛。

### Tests
- 新增 4 项搜索归一化、来源范围、选择修复和界面接线单元测试，并增加 1 项真实界面搜索/筛选冒烟测试；干净 Debug 测试产品和全量隔离测试 744/744、SwiftPM CLI 2/2 均通过。
- arm64/x86_64 通用 Release App 与通用 CLI 构建通过；核对 App/CLI 版本为 `2.12.0-rc40`、Bundle ID 为 `im.some.xomo`、最低系统为 macOS 13.0，两个 Mach-O 均包含 arm64 与 x86_64。
- XCTest UI runner 已成功编译并使用 Apple Development 签名，但本机 UI Automation 服务在执行断言前超时；改用同一 Debug App 完成 2/2 等价真实界面冒烟，确认预设搜索/来源空结果，以及组件插入后的组、文字和背景形状三层可编辑结构。

## 2.12.0-rc39 - 2026-07-14

### Added
- 新增“柔和投影、清晰描边、玻璃按钮、金色浮雕、霓虹发光、贴纸白边”6 套只读经典图层样式；内置项使用稳定 ID、不占 100 项自定义容量，可直接应用或复制为可编辑的用户预设。
- 样式菜单与预设管理器新增真实效果缩略图：缩略图通过现有图层样式合成器渲染描边、阴影、发光、渐变、斜面等效果，不再用统一占位图标代替。
- `xomo.layer.style` 新增 `presetCatalog` 与 `presetDuplicate` 动作；目录结果标记 `builtIn`，`presetApply` 同时接受内置和自定义 ID，MCP 工具总数保持 111。

### Changed
- 预设管理器按“内置经典样式 / 我的样式”分区；内置项不能重命名、排序或删除，但可应用、单项导出和复制为自定义项。
- 既有 `presetList` 继续只返回自定义项，避免改变已有 MCP/CLI 调用的数量与删除后空列表语义；复制、导入和导出仍不写入文档 History。

### Tests
- 新增 6 项内置目录、真实缩略图、应用撤销、只读持久化、复制持久化、内置项导出安全化与界面接线测试，并扩展 MCP 真实调用覆盖目录、应用和复制；图层样式、MCP 与三语资源共 84/84 次定向执行通过，CLI 测试 2/2 通过，并核对 Debug App 为 `2.12.0-rc39`、Bundle ID `im.some.xomo`、macOS 13.0 下限和 arm64 架构。

## 2.12.0-rc38 - 2026-07-14

### Added
- 新增轻量“图层样式预设管理器”：可重命名预设、置顶/上移/下移/置底、应用或删除所选预设，并可从当前图层继续创建；属性面板与“图层 → 图层样式 → 样式预设”均可打开。
- 新增版本化 `.xomostyles` 样式库格式，可导出单个或全部完整图层样式并在另一套 Xomo 工作区导入；文件保留预设顺序、名称、效果整体显隐、缩放及全部效果参数。
- `xomo.layer.style` 新增 `presetRename`、`presetMove`、`presetImport` 与 `presetExport` 动作；MCP/CLI 与图形界面调用同一组持久化命令，工具总数保持 111。

### Changed
- 导入预设会生成新的本机 ID，按名称与完整样式跳过重复项，并遵守 100 项容量；文件在解码前执行 5 MB 上限检查，未知格式版本、空库或损坏 JSON 不会修改现有预设。
- 重命名、排序、导入和导出属于工作区管理操作，不写入文档 History；导出使用原子文件写入，失败时保留原有预设和文档状态。

### Tests
- 新增 6 项预设管理器测试和 1 项真实 MCP 文件往返测试，覆盖跨会话顺序、名称校验、完整样式、全量容量、重复导入、新 ID、格式版本、文件上限、History 隔离、界面接线及导入导出动作；图层样式、MCP 与三语资源共 77/77 次定向执行通过，CLI 测试 2/2 通过，并核对 Debug App 为 `2.12.0-rc38`、Bundle ID `im.some.xomo`、macOS 13.0 下限和 arm64 架构。

## 2.12.0-rc37 - 2026-07-14

### Fixed
- 图层面板的“图层 / 通道 / 复合”三个页签统一使用纯白文字；当前页签继续用紫色背景表达选中状态，未选中页签不再以偏暗灰色降低可读性。

### Tests
- 收紧图层面板原生标签颜色断言，分别验证选中与未选中页签的 RGB 分量均保持纯白；图层面板专项 6/6、CLI 2/2 通过，并核对 Debug App 为 `2.12.0-rc37`、Bundle ID `im.some.xomo`、macOS 13.0 下限和 arm64 架构。

## 2.12.0-rc36 - 2026-07-14

### Added
- 新增可持久化的自定义图层样式预设：可从当前图层的完整样式创建预设，在属性面板或“图层 → 图层样式 → 样式预设”中应用，并删除当前匹配的自定义预设。
- 预设保存描边、阴影、内外发光、颜色/渐变/图案叠加、光泽、斜面浮雕，以及效果整体显隐和 1%–1000% 缩放比例；跨编辑器会话恢复时不会丢失效果字段。
- `xomo.layer.style` 新增 `presetList`、`presetCreate`、`presetApply` 和 `presetDelete` 动作，可选 `name` 并返回预设 ID、匹配状态、效果比例及效果清单；MCP 工具总数保持 111。

### Changed
- 多选应用样式预设会跳过锁定或不支持样式的图层，把全部可编辑目标记录为一个 History/Undo 步骤；创建和删除预设属于工作区设置，不污染文档历史。
- 自定义预设最多保存 100 项，载入时会修剪空白名称、限制名称长度、去除重复 ID，并对完整样式参数做兼容归一化。

### Tests
- 新增 5 项样式预设专项测试及 1 项真实 MCP 闭环测试，覆盖持久化、完整字段、归一化、多选锁定、单步撤销、工作区历史边界、界面接线和创建/列出/应用/删除自动化；图层样式、MCP 与三语资源共 70/70 次定向执行通过，CLI 测试 2/2 通过。

## 2.12.0-rc35 - 2026-07-14

### Added
- 图层样式新增非破坏式整体显隐：可隐藏或显示所选图层效果，也可一次隐藏或显示文档中的全部效果；效果参数、`fx` 标记和后续可编辑性均保留。
- 新增“缩放效果”，可把所选未锁定样式层统一设置为 1%–1000% 的绝对比例；描边、阴影、发光、图案、渐变、光泽与斜面等空间参数同步缩放，原始参数不被乘写。
- 图层菜单、图层面板、属性面板与 `xomo.layerStyle.action` / `xomo.layerStyle.setting` 共用同一业务入口，MCP 工具总数保持 111。

### Changed
- 图层面板在整体隐藏效果时仍保留低亮度 `fx` 标记，便于区分“临时隐藏”与“已清除样式”；旧项目没有新字段时按“显示效果、100%”兼容读取。
- 效果整体显隐可作用于锁定图层，但缩放效果遵守样式编辑锁定；多选操作分别写入单一 History 步骤并可一次撤销。

### Tests
- 新增 6 项图层效果显隐与缩放专项测试，覆盖渲染边界、参数保留、锁定混选、单步撤销、项目往返、旧项目兼容和界面接线；图层样式、MCP、项目文档、画布命令、三语资源与样式栅格化共 85/85 次定向执行通过，CLI 测试 2/2 通过。

## 2.12.0-rc34 - 2026-07-14

### Added
- “栅格化”子菜单新增“图层样式”目标：把图层样式及其前置的蒙版、智能滤镜、填充透明度和本图层 Blend If 烘焙为像素，同时保留图层名称、层级、图层不透明度、混合模式、下层 Blend If、剪贴关系和锁定状态。
- 新增独立“应用矢量蒙版”命令；“应用图层蒙版”现在只永久写入栅格蒙版，“应用矢量蒙版”只永久写入矢量蒙版，另一类蒙版、图层样式和外层合成属性继续可编辑。
- 图层菜单、图层面板与 `xomo.mask.action action=applyVector` 共用同一矢量蒙版应用入口；`xomo.layer.rasterize target=layerStyle` 复用目标栅格化入口，MCP 工具总数保持 111。

### Changed
- 应用已启用蒙版时会把文字、形状或生成填充的当前内容及智能滤镜结果转换为像素；应用被停用的蒙版只移除该蒙版，不会无故栅格化内容。
- 遵循 Photoshop 的智能对象约束：图层蒙版和矢量蒙版不能直接永久应用到智能对象，须先栅格化智能对象；原蒙版和 History 在拒绝时保持不变。

### Fixed
- 修正图层面板搜索框的输入文字与“搜索图层”占位文字在深色背景上偏黑、难以辨认的问题。
- 修复旧“应用图层蒙版”会同时清除栅格与矢量蒙版，以及形状/填充层写入像素后仍保留生成类型、导致应用结果被重新渲染覆盖的问题。
- 矢量蒙版转选区与直接应用统一使用左上画布坐标，不再沿用 AppKit 底部原点造成路径上下翻转。

### Tests
- 新增 6 项样式栅格化与独立蒙版应用专项回归，覆盖像素合成、属性边界、锁定混选、单步撤销、停用蒙版和智能对象保护；样式/蒙版、旧图层蒙版、矢量路径、目标栅格化、MCP、三语资源与图层面板样式共 9 组报告、66/66 次定向执行通过（去重 62 项），CLI 测试 2/2 通过。

## 2.12.0-rc33 - 2026-07-14

### Added
- 图层菜单和图层面板新增按目标分类的栅格化子菜单，可分别处理文字、形状、填充内容、矢量蒙版、智能对象或图层中的全部矢量数据；只转换实际目标，图层名称、样式、栅格蒙版、剪贴关系及未被目标覆盖的智能滤镜继续保留。
- “栅格化填充内容”会把形状或纯色、图案、渐变填充转换为像素，同时让形状轮廓继续作为可编辑矢量蒙版；“栅格化智能对象”会烘焙当前变换和智能滤镜，并按显示尺寸生成像素内容。
- MCP/CLI 新增 `xomo.layer.rasterize`，以严格枚举 `target` 暴露六类栅格化入口，工具总数从 110 增至 111。

### Fixed
- 栅格化矢量蒙版在已有但被停用的栅格蒙版上不再静默覆盖原蒙版；命令会保持禁用，避免丢失用户蒙版数据。

### Tests
- 新增 7 项目标栅格化专项回归，覆盖内容边界、图层属性保留、像素合成一致性、锁定混选、单步撤销、矢量蒙版保护和智能对象变换烘焙；目标、旧行为、智能对象、形状、智能滤镜、MCP 与三语资源定向测试合计 40/40，CLI 测试 2/2 通过。

## 2.12.0-rc32 - 2026-07-14

### Changed
- 将 rc31 完成的选区布尔坐标修复以新的唯一版本 rc32 正式发布；GitHub 上既有 `v2.12.0-rc31` 标签保持不变，不覆盖、不强推历史标签。

### Tests
- 重新构建 rc32 测试产品，非对称选区布尔坐标回归 1/1、CLI 2/2 通过；App、CLI 版本及 macOS 13 系统下限同步核对。

## 2.12.0-rc31 - 2026-07-14

### Fixed
- 修复选区相加、相减与相交在栅格化矢量选区时把 y 坐标上下翻转的问题；矩形后追加圆形等非对称组合现在会落在实际拖拽位置。
- 保留既有 raster mask 的行序，不会把魔棒、快速蒙版或通道选区在再次参与布尔运算时二次翻转。

### Tests
- 新增非对称相加、相减、相交 3 项坐标回归，覆盖矢量选区首次栅格化及已有 raster mask 与新矢量选区混合运算的行序，并分别确认对应 History 文案。
- macOS 13 Debug `build-for-testing` 通过；选区操作套件 26/26、旧布尔模式、通道载入与补丁套索回归 3/3、CLI 2/2 通过。完整 Release 与全量冒烟继续按每 20 个版本在 rc40 执行。

## 2.12.0-rc30 - 2026-07-13

### Fixed
- “转换为背景”现在遵守单一背景层约束：文档已有锁定背景层时会禁用并拒绝转换，用户须先执行“背景转图层”，不再生成两个同名背景层。
- 普通图层转换为背景时，会把图层位置、透明像素、整体不透明度、混合模式、Blend If、蒙版、图层样式与智能滤镜的可见结果烘焙到当前背景色，生成铺满画布的不透明锁定像素层；隐藏状态、图层 ID 与标签颜色保持不变。
- 转换会把嵌套图层提升到根级最底部，清除所有幸存图层指向原图层的双向链接，并解除失去原基底的剪贴层；“背景转图层”则保留像素、身份、标签和链接，只解除全部背景锁。

### Tests
- 新增单背景拒绝、四类锁解除、像素与链接保持、不透明度/背景色烘焙、嵌套组提升、双向链接清理、孤立剪贴解除、隐藏状态及矢量外观烘焙共 7 项专项回归。
- 更新既有背景转换往返用例并增加 MCP 真实动作回归；专项、旧行为与自动化定向测试合计 9/9、CLI 2/2 通过。本版本按第 30 个小版本门槛完成 macOS 13 干净 Debug 编译，完整 Release 与全量冒烟仍留在 rc40。

## 2.12.0-rc29 - 2026-07-13

### Changed
- “合并可见”改为按完整图层树确定结果落点：可见叶图层会合成为根级像素层，嵌套可见空组递归清理，隐藏组及其后代完整保留，结果不会再被塞进组子树中间。
- 合并结果接管被合并叶图层及被清理组的外部双向链接；幸存剪贴层只有在合并结果确实位于原基底位置时才继续剪贴，否则明确解除，避免静默绑定无关图层。
- “盖印可见”放在最高可见根的安全边界；“盖印所选”先消除父组与后代的重复选择，同父级选择在组内生成局部像素，跨父级选择在根级安全边界生成，均保持原图层、链接与剪贴关系不变。
- “拼合图像”改为经典 Photoshop 语义：丢弃隐藏图层，把可见结果铺在白色不透明背景上，并生成唯一、锁定的“背景”像素层；四项命令仍各自产生单一 History/Undo 步骤。
- MCP/CLI 新增专用 `xomo.layer.stamp_selected` 与 `xomo.layer.flatten`，工具总数从 108 增至 110；界面与自动化复用同一业务入口。

### Tests
- 新增嵌套可见组递归清理、有效隐藏子树保留、链接替换与剪贴基底、盖印可见安全边界、组内局部盖印、跨父级盖印和白色锁定背景拼合共 7 项层级专项回归。
- 扩展既有盖印、合并可见、拼合图像、MCP 工具目录与真实自动化调用测试；Debug `build-for-testing` 通过，层级专项、旧行为和 MCP/App 自动化定向回归合计 31/31 通过，CLI 2/2 通过。完整 Release 编译与全量冒烟仍按每 20 个版本执行，下次门槛为 rc40。

## 2.12.0-rc28 - 2026-07-13

### Fixed
- 修复图层面板“图层 / 通道 / 复合”页签在真实 macOS 运行时仍被按钮环境色覆盖成黑字的问题：页签标题改由不可编辑、不可选中且拒绝第一响应者的原生 AppKit 标签绘制，选中项使用纯白，未选中项使用浅灰白。
- 保留自绘页签的强调色选中背景、三语标题、点击区域和 `focusable(false)` 行为；未引入系统分段控件的焦点环。

### Tests
- 扩展 Swift Testing，直接验证原生页签标签在选中与未选中状态下的实际 `NSTextField.textColor`、标题和拒绝第一响应者约束；Ruby 样式契约同步验证 AppKit 标签接线。
- Debug 构建通过，并用当前源码真实启动 Xomo 对照截图：修复前可稳定复现黑字，修复后“图层”为纯白、“通道 / 复合”为浅灰白。完整 Release 编译和全量冒烟继续按每 20 个小版本执行，下次门槛为 rc40。

## 2.12.0-rc27 - 2026-07-13

### Changed
- “向下合并”改为按图层树寻找同父级的紧邻下方像素层，不再把底层数组中碰巧相邻、实际属于另一父级的图层误当目标；选择图层组时会把完整嵌套子树合并为一个像素层，并保留原组名称和父级。
- “合并所选”按所选层级根处理完整子树，只允许合并同父级的可编辑分支；锁定选择会留在原位并保持选中，含锁定后代的组不会被部分压平。整批操作仍只产生一个 History/Undo 步骤。
- 合并结果会继承原分支的外部双向链接；多个剪贴层共享外部基底时，结果继续绑定该基底。其他幸存剪贴层若原基底参与合并，则明确改绑到合并结果，不能保持原绑定时会解除剪贴，避免静默串链。
- 图层菜单和面板会在选择组时把“向下合并”显示为“合并组”；新增 `xomo.layer.merge_selected`，App、MCP 与 CLI 共用同一层级合并规划器。

### Tests
- 新增跨父级相邻拒绝、组内紧邻合并与撤销、嵌套组完整压平、跨父级所选拒绝、锁定混选保留、锁定后代保护、外部链接替换和剪贴基底保留共 8 项专项回归。
- MCP 自动化增加真实“合并所选”调用与锁定选择保留覆盖；层级合并、MCP、旧合并行为、菜单接线和本地化按 AppKit 隔离套件合计 43/43 通过，CLI 2/2 通过。完整 Release 编译和真实界面冒烟继续按每 20 个小版本执行，下次门槛为 rc40。

## 2.12.0-rc26 - 2026-07-13

### Changed
- 批量删除改为层级安全规划：选择图层组会删除其完整嵌套子树，同时选择父组和后代也只处理一次；受自身或祖先锁定影响的显式选择会被跳过并保留。
- 删除后的选择不再按底层数组索引猜测。仍然存在且可见的锁定选择会继续保留；没有幸存选择时，优先选择图层面板中原主选择下方的可见行，再回退到上方，折叠组的隐藏后代不会被误选。
- 删除会移除幸存图层中指向已删图层的链接，并保持其余双向链接；如果幸存剪贴层的原基底被删除，会明确解除剪贴状态，不再静默改绑到更下方的另一图层。
- 图层面板、菜单、画布对象删除和 `xomo.layer.delete` 共用独立删除规划器，整批操作继续只产生一个 History/Undo 步骤；MCP/CLI 工具说明同步层级语义。

### Tests
- 新增完整嵌套子树与单步撤销、锁定混选保留、折叠组可见落点、剪贴基底删除不改绑、链接清理和禁止删空画布共 6 项删除回归。
- `XomoAutomationTests` 18/18 通过，增加 MCP 实际删除完整子树并保留锁定选择的覆盖；既有链接删除、图层组删除、多选删除与画布组件对象删除 4/4 通过，联合回归合计 28/28。旧链接缩放/删除测试改用真实像素夹具，避免透明占位层没有内容边界而提前退出缩放。
- 本版本 Debug 定向单元测试 28/28、CLI 测试 2/2 通过；完整 Release 编译和真实界面冒烟继续按每 20 个小版本执行，下次门槛为 rc40。

## 2.12.0-rc25 - 2026-07-13

### Changed
- 多选复制改为按原父级分簇：同一父级的不连续选择保持相对顺序形成连续副本块，不同图层组中的选择分别插回各自组内，不再把带旧父级 ID 的副本整块塞到另一个组旁边。
- 复制图层组会携带完整嵌套子树并重映射全部父组 ID；只有显式复制根增加“副本”名称，隐式复制的组成员保留原名。同时选择父组与后代时只复制一次，并只把原来显式选择的项目映射为副本选择。
- 副本之间的图层链接通过全局新 ID 映射重建，未随选择复制的外部链接不会倒挂回原图层；智能对象仍保持共享来源语义。
- 复制剪贴基底时，插入边界会越过依赖该基底的原剪贴层，避免原剪贴链改绑到副本；完整剪贴链副本会绑定副本基底，孤立剪贴层的副本自动降级为普通图层。整批复制继续只产生一个 History/Undo 步骤。
- 菜单、图层面板与 `xomo.layer.duplicate` 共享独立的层级复制规划器，MCP/CLI 工具说明同步标注层级安全语义。

### Tests
- 新增跨父组不连续复制、嵌套组显式选择映射、跨子树链接重映射、原剪贴链边界保护、剪贴链副本与孤立剪贴降级共 5 项回归；图层复制套件合计 7/7 通过。
- `XomoAutomationTests` 17/17 通过，包含 MCP 实际复制后的落点、完整子树、选择、链接和 History；普通图层、智能对象、单层组与嵌套组 4 项旧复制回归通过，定向测试合计 28/28。
- macOS 13 干净 Debug 测试产品构建与 CLI 2/2 测试通过；完整 Release 编译和界面冒烟继续按每 20 个小版本执行，下次门槛为 rc40。

## 2.12.0-rc24 - 2026-07-13

### Changed
- “移入上方图层组”不再只修改父组 ID：不连续的可编辑选择会连同所选组的完整后代子树保持相对顺序，收拢到目标组标题之前，成为该组顶部的连续成员；目标组会自动展开。
- “移出图层组”会把每个所选根及其完整子树放到原父组标题之后，也就是图层面板中原组的正上方；一次选择可跨多个同级或嵌套父组，每个分支都使用自己的可见边界和正确的新父级。
- 两个命令都跳过锁定项并保留全部有效选择与主选择；选择父组及其后代时只移动一次，跨无关父级的移入请求会被拒绝，整批操作继续只产生一个 History/Undo 步骤。
- 新增独立的纯图层组移动规划器，菜单、图层状态判断与 `xomo.layer.action` 共享同一结构结果；写回后统一规范化剪贴蒙版，避免层级变化留下孤立剪贴层。

### Tests
- 新增不连续子树移入、跨父级拒绝、完整子树移出、多个嵌套父组边界、锁定跳过、父组与所选后代去重共 6 项层级移动测试。
- `XomoAutomationTests` 16/16 通过，包含 MCP 实际移入和移出后的顺序、父级、选择与 History；rc22/rc23 的编组 7 项、可见排序 6 项及旧拖放、嵌套组和剪贴蒙版 5 项回归通过，定向测试合计 40/40。
- macOS 13 Debug 测试产品构建与 CLI 测试通过；完整 Release 编译和界面冒烟继续按每 20 个小版本执行，下次门槛为 rc40。

## 2.12.0-rc23 - 2026-07-13

### Changed
- 多选图层编组改为层级安全规划：不连续同级图层会按原相对顺序收拢成连续子树，并在最高所选项的位置建立展开组，避免仅修改父组 ID 后在面板中与无关图层交错。
- 选中组及其后代时，显式选中的后代会提升为新组的直接成员且只出现一次，未选中的完整后代分支继续留在原子组；不同父级且没有共同所选祖先的项目不会被错误编入同一组。
- 编组与解组都会跳过锁定项并保留未处理选择；嵌套组、折叠组及同时解组多层祖先时会计算正确替代父级，整批操作只产生一个 History/Undo 步骤。
- 选中图层组进行变换时，透明成员没有像素边界会改用其图层 frame 计算组变换框，使包含透明占位层的组仍可整体移动；普通透明像素层单独选择的行为不变。
- `xomo.layer.group` 与 `xomo.layer.ungroup` 的 App、MCP 和 CLI 工具说明同步层级、锁定跳过与选择保留语义。

### Tests
- 新增不连续同级、锁定跳过、嵌套父组、显式后代提升、跨父组拒绝、嵌套多组解组、折叠组解组与撤销共 7 项层级一致性测试。
- `XomoAutomationTests` 15/15 通过，包含实际调用 MCP 编组/解组并核对顺序、选择和 History；旧的多选编组、折叠组、嵌套复制/移动、移动入组/出组和剪贴蒙版清理 5 项回归通过，定向测试合计 27/27。
- macOS 13 Debug 测试产品构建与 CLI 测试通过；完整项目编译与界面冒烟仍按每 20 个小版本执行，下次门槛为 rc40。

## 2.12.0-rc22 - 2026-07-13

### Changed
- 图层面板、图层菜单和快捷命令的“上移 / 下移 / 置顶 / 置底”改为按照当前实际可见行排序；搜索或筛选隐藏的非匹配行会被跳过，不再按底层数组盲目交换。
- 折叠图层组作为包含全部后代的完整子树移动，保持组结构和子层相对顺序；跨越展开组标题时，上下移动会按可见层级语义进入或离开该组。
- 不连续多选可按各自可见区段同步移动，整批操作只写入一个 History / Undo 步骤；排序完成后继续保留原选择。
- 将图层层级排序与既有拖放重排抽到独立模块，面板按钮、菜单、拖放和 `xomo.layer.order` 复用同一套层级边界、循环保护与剪贴蒙版规范化逻辑。

### Tests
- 新增筛选跳行、折叠组整树移动、展开组进出边界、不连续多选、置顶/置底单步撤销，以及面板/菜单传递可见顺序共 6 项测试。
- `XomoAutomationTests` 14/14 通过，包含 `xomo.layer.order` 移动折叠组子树的实际调用；旧的栈边缘移动、跨组拖放和孤立剪贴蒙版清理 3 项隔离回归通过。
- macOS 13 Debug 测试产品构建与 CLI 测试 2/2 通过；完整项目编译与界面冒烟仍按每 20 个小版本执行，下次门槛为 rc40。

## 2.12.0-rc21 - 2026-07-13

### Added
- 图层组支持快速递归展开与折叠：按住 `Option` 点击组行展开箭头，可一次切换该组及全部嵌套组。
- “图层”菜单与图层面板“更多”菜单新增“展开所选组”和“折叠所选组”，可批量处理所选组的完整分支。
- `xomo.layer.action` 新增 `expandSelectedGroups` 与 `collapseSelectedGroups`，App、MCP 与 CLI 复用同一图层树逻辑。

### Changed
- 折叠组时，如果当前选择包含即将隐藏的后代图层，会保留仍可见的同级选择，并用可见父组替换隐藏项，避免选择落到看不见的行。
- 图层组展开状态继续作为工作区视图状态，不写入文档 History/Undo；实际图层结构变化仍保持独立撤销语义。
- 经典 Photoshop 路线的完整项目编译与冒烟门槛由每 10 个小版本调整为每 20 个小版本；rc20 已完成本轮完整门槛，下次为 rc40。

### Tests
- 新增嵌套组递归展开/折叠、普通点击单组切换、折叠后选择归一化、菜单接线和 MCP 实际调用测试。
- 干净 Debug 测试产品构建通过；图层组、MCP 与三语资源定向测试 21/21、CLI 测试 2/2 通过，App 包与 CLI 实际版本均核对为 `2.12.0-rc21`。

## 2.12.0-rc20 - 2026-07-13

### Added
- 段落文字框新增“文本框适合内容”和“扩高以显示全部”命令，可从属性面板与“窗口 → 段落”菜单直接执行。
- MCP/CLI 新增 `xomo.text.fitBox`，支持 `fitContent` 与 `expandHeight` 两种严格枚举模式，工具目录增至 107 项。

### Changed
- 两种适配命令保持图层原点、文本框宽度、字号和段落样式不变；前者可精确增减高度，后者只处理溢出且不会收缩已有留白。
- 多选操作跳过点文字、自动高度文字框、非文字层和像素锁定层，整批变化只写入一个 History / Undo 步骤。

### Fixed
- “图层 / 通道”、导航器和历史等停靠面板标题改用专用纯白前景色，不再受通用次级浅灰文字色影响。

### Tests
- 新增精确收缩、溢出扩高、字号与位置保持、撤销、批量锁定跳过、单步 History、界面接线和 MCP 实际调用测试。
- 作为第 20 个经典小版本，本版完成 Debug 测试构建、Release 构建、628/628 隔离单元测试、36 项专项回归、真实界面启动与组件插入冒烟，以及 2 项 CLI 测试和 arm64/x86_64 通用二进制验证。

## 2.12.0-rc19 - 2026-07-13

### Added
- 段落文字框在固定高度容纳不下内容时，画布右下角显示经典的加号溢出标记，属性面板同步给出可读警告。
- `xomo.text.get` 新增 `requiredBoxHeight` 与 `hasOverflow`，自动化调用可以判断文本框是否需要扩高。

### Changed
- 移动工具的八个变换手柄对段落文字改为调整容器边界：只改变换行宽高并实时重排，不再缩放字号；点文字和普通图层继续保持原缩放行为。
- 段落文字的选中框始终覆盖完整文本框，而不是只包围已有字形像素；边界调整保持对侧锚边稳定，支持吸附、History 与单步撤销。

### Fixed
- 点文字的变换范围改为扫描动态渲染后的真实字形，不再因为文字图层的底图透明而缺失选框与缩放手柄。

### Tests
- 新增溢出测量、对边锚定、文字框手柄调整、Shift 不缩放字形、撤销恢复、溢出状态消除及界面提示接线测试；MCP 自动化同步验证新增诊断字段。

## 2.12.0-rc18 - 2026-07-13

### Added
- 文字工具支持 Photoshop 式双入口：单击画布创建点文字，按住并拖出矩形则创建固定宽高的段落文字框。
- 拖拽期间以画布坐标实时显示虚线框，支持任意方向拖动；输入浮层和最终文字图层复用同一矩形尺寸。

### Changed
- 段落文字模型新增可选固定高度；旧项目缺少高度字段时继续按内容自动增高，转换为点文字会同步清除宽高约束。
- 图像尺寸缩放会按水平、垂直比例分别缩放文字框宽高；属性面板与 `xomo.text.create/get/update` 同步开放文字框高度。

### Tests
- 新增拖拽阈值、反向矩形归一化、精确宽高、创建与更新撤销、项目新旧格式、非等比图像缩放及画布手势接线 7 项测试；自动化测试同步覆盖 MCP 文字框宽高。

## 2.12.0-rc17 - 2026-07-13

### Added
- 文字图层新增显式的“转换为点文字 / 转换为段落文字”命令，可从属性面板和“窗口 → 段落”菜单直接执行。
- MCP 新增 `xomo.text.convert`，`xomo.text.get` 同步返回 `layoutMode`；离线 CLI 工具目录扩展至 106 项。

### Changed
- 点文字转换为段落文字时以当前自然文字宽度建立文本框，不移动图层；转换回点文字时移除自动换行宽度，同时保留文字内容、字体、字符与段落样式。
- 多选转换只处理目标模式不同且未锁定的文字层，跳过非文字层和锁定层，并把整批转换记录为一个 History / Undo 步骤。
- 项目文件继续复用既有 `boxWidth` 表达两种模式，无需提升项目格式版本，旧项目仍可直接打开。

### Tests
- 新增模式判定与宽度映射、双向转换、坐标与样式保留、撤销、批量锁定跳过和项目 round-trip 5 项测试；自动化与 CLI 测试同步覆盖新 MCP 工具及 106 项目录计数。

## 2.12.0-rc16 - 2026-07-13

### Added
- 段落文本新增左右两端对齐、左缩进、右缩进和首行缩进；现有文本框宽度成为完整的段落排版容器。

### Changed
- 新建文字、单层更新和多选文字层批量更新会保留全部段落设置，批量操作继续跳过锁定与非文字图层并只产生一个 History 步骤。
- 项目文件保存三类缩进，旧项目缺少字段时回退为零；属性面板、段落摘要、中英日三语资源及 `xomo.text.get/update` MCP 参数同步更新。
- SVG 文字导出识别两端对齐并以段落左缩进作为起点，不再因新增对齐枚举中断导出编译。

### Tests
- 新增段落样式映射、真实换行渲染差异、创建与更新、撤销、批量更新、锁定跳过、项目 round-trip、旧项目兼容和 SVG 入口 6 项测试，并继续验证段落菜单、MCP 与三语资源。

## 2.12.0-rc15 - 2026-07-13

### Added
- 字符样式新增独立的下划线与删除线；属性面板和“窗口 → 字符”菜单均可切换，两种装饰可以同时使用。

### Changed
- 新建文字、单层文字更新和多选文字层批量更新会保留两种字符装饰；批量操作继续跳过像素锁定和非文字图层，并只写入一个 History 步骤。
- 项目文件保存下划线与删除线状态，旧项目缺少字段时安全回退为关闭；字符面板摘要、中英日三语资源及 `xomo.text.get/update` MCP 参数同步更新。

### Tests
- 新增字符属性独立组合、真实渲染差异、创建与编辑、撤销、批量更新、锁定跳过、项目 round-trip 和旧项目兼容 5 项测试，并继续验证字符菜单、项目格式与三语资源。

## 2.12.0-rc14 - 2026-07-13

### Added
- 图层面板行内的眼睛、总锁、像素锁、位置锁和透明像素锁现在支持当前多选集合；点击任一已选行即可一次统一全部适用图层的状态。

### Changed
- 混合状态不再逐项反转，而是以被点击行的相反状态作为整组目标：点击可见行统一隐藏，点击隐藏行统一显示，四类锁定同理。
- 点击未选中行的行内控件仍只修改该行且不改变当前图层选择；透明像素锁等细分锁自动跳过文字等不适用图层。
- 批量行内操作只生成一个 History 步骤，撤销会原样恢复每个图层此前不同的状态；单行调用继续保留原有 History 语义。
- 图层面板标题以及“图层 / 通道 / 复合”标签改用显式浅色前景，避免 macOS 控件状态将文字渲染成深色。

### Tests
- 新增混合可见性、总锁与细分锁统一、不可用图层跳过、未选中行回退、选择保持、单步 History/Undo 和界面调用契约 6 项测试，并补充图层面板标题浅色可读性测试。

## 2.12.0-rc13 - 2026-07-13

### Added
- 图层面板支持经典连续多选：普通点击建立锚点，`Shift` 点击选择锚点与目标之间的连续图层，`Command+Shift` 点击把该区间追加到现有选择。

### Changed
- `Command` 点击继续只切换单个图层，不再与 `Shift` 共用同一种逐项切换行为；连续范围严格按当前搜索、过滤和图层组折叠后的可见行计算，不会暗中选择面板里不可见的图层。
- 连续选择保留原始锚点，支持向上、向下反复扩展；清除图层选择会同步清除锚点。

### Tests
- 新增正向与反向区间、锚点保持、`Command+Shift` 追加、过滤/折叠可见范围、清除锚点和面板修饰键映射 6 项测试。

## 2.12.0-rc12 - 2026-07-13

### Added
- 修补工具支持“源 / 目标”两种经典模式：源模式用拖到的干净纹理修复原选区，目标模式把原选区纹理修补到拖拽位置并移动选区边缘。
- 修补工具现在可以直接手绘闭合选区；从有效选区内部拖动时，画布以最高 30 FPS 显示真实合成预览、拖动连线和同形状虚线目标轮廓，松手后才写入图层。
- 选项栏增加不可聚焦的模式切换、透明度和羽化控制；`xomo.paint.special` 同步支持 `patch`、`mode` 与 `feather` 参数。

### Changed
- 修补预览复用与最终提交完全相同的像素算法及透明像素锁保护；预览不修改文档、History 或当前选区，切换工具会立即清理临时状态。

### Tests
- 新增源模式预览无副作用、提交与撤销、目标模式像素与选区位移、修补工具手绘选区、MCP 参数和界面交互契约测试，并保留既有透明像素锁回归。

## 2.12.0-rc11 - 2026-07-13

### Added
- 画笔与橡皮擦的选项栏增加画笔预设菜单；用户可以从当前大小、硬度、流量、间距和笔压设置创建自定义预设，随后一键恢复完整画笔定义。
- 自定义画笔预设支持删除并通过工作区偏好跨编辑器会话持久化；五个内置圆头预设继续保留且不可删除。
- `xomo.brush.preset` MCP/CLI 工具支持列出、创建、应用和删除预设，并返回完整参数及当前匹配状态。

### Changed
- “大小预设”升级为“画笔预设”；选项改变后会实时重新匹配当前预设，避免菜单仍错误标记旧预设。
- 自定义预设加载时会夹取异常参数、清理空白名称、去除重复 ID，并限制最多保存 100 项。

### Tests
- 新增预设完整参数恢复、创建/应用/删除、跨会话持久化、损坏数据回退、参数夹取、重复 ID、内置项保护、当前匹配和 MCP 全流程测试。

## 2.12.0-rc10 - 2026-07-12

### Added
- 普通画笔与橡皮擦支持数位笔压力采样，压力可分别控制笔尖大小和流量，并提供 0%–100% 灵敏度曲线选项。
- `xomo.paint.stroke` 的点对象支持可选 `pressure`，同时增加 `pressureSize`、`pressureFlow` 和 `pressureSensitivity` 参数。

### Changed
- 压力沿重采样路径连续插值；普通鼠标没有压力信息时按满压处理，确保既有鼠标笔触保持一致。
- 像素层、快速蒙版和图层蒙版统一使用同一套压力动态，并允许单击生成一个有效笔尖印章。
- 画布显式发布为包含子元素的辅助功能容器，使 UI 自动化和辅助技术可以稳定定位画布，同时保留画布内文字编辑等子元素。

### Tests
- 新增压力曲线、灵敏度、路径插值、大小/流量独立控制、无压设备回退、输入夹取、单击笔触、History/Undo、两类蒙版和 MCP 参数回归测试。
- 作为第 10 个经典小版本，执行完整 Xcode 项目编译、全量单元测试、界面冒烟与 SwiftPM CLI 测试。
- 隔离测试脚本为每项并发测试写入独立 xcresult，避免同秒启动时结果包互相覆盖；同时支持复用指定 DerivedData。

## 2.12.0-rc9 - 2026-07-12

### Fixed
- 右侧停靠面板的“图层 / 通道”标题、图层图标和展开箭头分别显式使用浅色主题，避免 macOS 按钮状态覆盖父容器前景色后出现深色文字。

### Tests
- 增加停靠面板标题颜色与源码契约回归测试，验证标题主题色的 RGB 分量均保持在深色背景可读范围，并确保标题、图标和箭头各自显式应用该颜色。

## 2.12.0-rc8 - 2026-07-12

### Added
- 普通画笔与橡皮擦增加 1%–100% 流量和 1%–200% 笔尖间距选项；`xomo.paint.stroke` 同步接受 `hardness`、`flow` 与 `spacing` 参数。
- 画笔改为按路径等距重采样笔尖印章：流量按印章逐次沉积并受整笔不透明度上限约束，间距按笔尖直径百分比控制，鼠标事件稀疏或密集不会改变结果。

### Fixed
- 普通画笔此前显示“硬度”选项却仍以固定圆头路径绘制；现在硬度实际控制笔尖径向软边。
- 流量、间距与硬度统一作用于像素层、快速蒙版和图层蒙版，避免切换编辑上下文后参数失效。

### Tests
- 新增重采样稳定性、流量累积与不透明度封顶、宽/窄间距、硬度软边、选区、透明像素锁、History/Undo、快速蒙版、图层蒙版和 MCP 参数测试；三语资源键同步通过验证。
- Xcode `build-for-testing` 通过；画笔/MCP/本地化 22 项定向测试、全工具左上坐标套件及 SwiftPM CLI 2 项测试均通过。

## 2.12.0-rc7 - 2026-07-12

### Fixed
- 图层面板的“图层 / 通道 / 复合”切换从系统分段选择器改为自绘深色页签，三个页签无论是否选中都明确使用浅色文字，不再被 AppKit 控件外观覆盖成黑字。
- 页签继续保持不可聚焦状态，并通过强调色背景表达当前选中项。

### Tests
- 新增 Swift Testing 页签前景色用例，并增加可独立运行的 Ruby 样式契约测试；契约测试验证自绘按钮、统一浅色前景、非系统分段控件和不可聚焦约束。

## 2.12.0-rc6 - 2026-07-12

### Added
- 修复画笔改为显式设置采样源，支持 Option 点击或选项栏按钮取样，并在画布显示来源十字标记。
- 修复画笔增加对齐 / 非对齐模式，以及当前图层、当前及以下、所有可见图层三种采样范围；同一能力同步暴露给 `xomo.paint.special` MCP 工具。

### Fixed
- 修复过程改用落笔前固定快照，避免连续笔触把刚生成的像素反复采回；颜色融合以整段笔触中心周围的目标与来源颜色为基准，减少瑕疵颜色污染边缘。
- 笔触边缘按硬度生成连续软遮罩，并继续受选区与透明像素锁约束。

### Tests
- 新增来源缺失、颜色融合、选区、软边硬度、稀疏/密集连续采样一致性、可见图层采样和 MCP 参数回归测试；仿制图章共享采样偏移、全工具左上坐标测试同步通过。

## 2.12.0-rc5 - 2026-07-12

### Added
- 仿制图章增加对齐 / 非对齐模式：对齐模式跨笔触保持源点偏移，非对齐模式每笔从原始源点重新开始。
- 增加当前图层、当前及以下图层、所有可见图层三种采样范围；合成采样使用落笔前快照，并支持从当前小图层边界外取样。
- 工具选项栏增加不可聚焦的对齐开关和采样范围菜单；`xomo.paint.special` 同步接受 `aligned` 与 `sampleSource` 参数。

### Tests
- 新增偏移解析、连续两笔对齐差异、三种图层范围、小图层越界采样、选区与透明像素锁保护及撤销/重做像素测试。
- 既有左上原点仿制坐标、MCP 参数和三语本地化键一致性均通过独立 `xcodebuild -only-testing` 验证。
- 第 5 个经典小版本的 Xcode App 与独立 SwiftPM CLI 干净 Debug 构建通过；App 产物确认版本 `2.12.0-rc5`、Bundle ID `im.some.xomo`、最低系统 macOS 13、可执行文件与签名正常，CLI `--version` 同步返回 `2.12.0-rc5`。

## 2.12.0-rc4 - 2026-07-12

### Fixed
- 栅格选区边缘改为从 mask 提取的连续闭合轮廓，正确显示凹口、孔洞、反相边界和对角接触的多个孤岛，不再只显示选区矩形 bounds。
- 选区轮廓只在选区或画布尺寸变化时重建，缩放和平移复用缓存；矩形和套索拖出画布时夹取到画布边界，正方形/圆形越界后仍保持固定比例。

### Tests
- 新增凹形、孔洞、反相、对角孤岛、连续轮廓、三次缓存稳定性、缩放/平移变换和画布外拖拽边界测试。
- 矩形、椭圆、套索、魔棒和快速选择全部通过快速蒙版编辑、退出、撤销和重做贯通测试；既有固定比例选区及快速蒙版画笔回归通过。

## 2.12.0-rc3 - 2026-07-12

### Added
- 左侧快速蒙版控制增加独立选项入口，可切换颜色表示“被蒙版区域”或“选中区域”，并自定义覆盖颜色与 5%–100% 不透明度。
- 快速蒙版显示选项会即时刷新活动画布，并作为工作区偏好跨编辑器会话持久化；损坏的偏好数据会安全回退到红色、50%、“被蒙版区域”的默认值。

### Tests
- 新增两种覆盖语义、颜色与透明度像素渲染、偏好 round-trip、透明度边界、异常数据回退、ViewModel 即时刷新与重启恢复测试。
- 上一版默认红色遮罩与 `Q` 快捷键回归、三语本地化键一致性均通过独立 `xcodebuild -only-testing` 验证。

## 2.12.0-rc2 - 2026-07-12

### Added
- 快速蒙版开启时，画笔会从选区减去笔触区域，橡皮擦会把笔触区域恢复到选区；笔刷直径和不透明度参与实际 mask 运算。
- 每次快速蒙版笔触都进入 History，可在模式保持开启时撤销和重做；绘制不会修改当前图层像素，退出后保留真实栅格选区。

### Tests
- 新增画笔减选、橡皮恢复、图层像素不变、遮罩缓存刷新、撤销/重做和退出后选区保留测试。
- 新增笔刷直径与 50% 不透明度的纯 mask 运算测试；快速蒙版编辑、上一版预览回归和三语本地化键一致性均通过独立 `xcodebuild -only-testing` 验证。

## 2.12.0-rc1 - 2026-07-12

### Added
- 增加经典 Photoshop 快速蒙版预览：通过左侧按钮、选择菜单或 `Q` 键切换，未选区域显示半透明红色遮罩。
- 快速蒙版启用时隐藏普通选区虚线；清除选区会自动退出快速蒙版，文字输入期间不会吞掉 `Q` 字符。
- 新增经典图像编辑路线图，后续优先完成可独立测试的小能力，把色彩模式、完整 PSD 与大文档架构等高风险改造放到后期。

### Tests
- 新增快速蒙版遮罩像素、状态切换、清除选区退出与 `Q` 快捷键解析测试。
- 新增用例与三语本地化键一致性测试均通过独立 `xcodebuild -only-testing` 验证；整套选区套件的并行尝试仍复现仓库已记录的 AppKit 进程级颜色污染，因此不把该并行结果作为本版门槛。

## 2.11.0-rc3 - 2026-07-12

### Fixed
- 修复 Release 全模块优化编译时，拖拽结束回调中的局部 `imagePoint` 覆盖同名坐标转换函数、导致画布移动手势无法编译的问题。
- 拖拽结束坐标统一改名为 `endImagePoint`，避免与坐标转换方法发生名称遮蔽。

## 2.11.0-rc2 - 2026-07-12

### Fixed
- 修复拖动画布组件时使用“首个移动事件的当前位置”做命中判断的问题；快速拖动时即使鼠标已经离开组件，也会根据真实按下点选中并移动组件。
- 首个拖拽事件立即应用从按下点到当前点的完整位移，松手时再补齐最后一帧到释放点的差值；单事件快拖和短拖不再丢失移动距离或被误判为画布平移。
- 组件移动改用无界画布坐标，拖出画布边缘后仍保持连续预览；空白处平移画布同样不会丢失第一帧位移。
- 已选组件的可见外轮廓现在拥有独立拖动手势，避免画布父级手势或变换叠层抢占组件本体的拖动事件。

### Tests
- 新增视口像素到画布像素的拖动位移换算测试，并使用独立 Bundle ID 的本机测试副本复现组件拖动路径。

## 2.11.0-rc1 - 2026-07-12

### Added
- 抓手工具支持在画布工作区任意位置按住鼠标拖动画布。
- 默认移动/选择状态下，在没有命中可选对象的空白位置直接拖动即可平移画布；命中对象时仍保持对象选中与移动行为，无需用户预先切换工具。
- 任意工具下按住空格可临时进入抓手模式，松开空格后恢复原工具；文字输入框获得焦点时，空格仍正常输入文字。
- 平移时鼠标由张开手掌切换为闭合手掌，画布位移按视口像素实时更新，不随缩放倍率改变拖动距离。

### Tests
- 新增抓手指针状态与画布视口位移测试。

## 2.10.0-rc5 - 2026-07-12

### Fixed
- 修复从组件库拖入画布时，拖拽预览与实际组件使用不同定位锚点、导致松手后组件向右下偏移的问题。
- 释放点现在对应组件预览中心，随后换算为组件左上角并夹取到画布边界；预览贴近左、上、右、下边缘时，最终组件保持相同贴边结果。
- 拖拽释放在实际画布之外时返回失败，不再把 `nil` 落点误解为“居中插入”。

### Tests
- 新增覆盖全部 22 类 UI 组件的中心落点和四周边界夹取测试。

## 2.10.0-rc4 - 2026-07-12

### Fixed
- 为画布中选中的 UI 组件增加贴合圆形、胶囊形或矩形外轮廓的浅色背景、灰色虚线边框和柔和阴影；左侧组件库的对应卡片同步显示强调背景、描边与阴影。
- 点击组件库卡片时先立即发布选中反馈，再在下一个主线程周期执行组件插入，避免复杂画布重绘遮住点击响应。
- 将组件对象目录从“每个组件重复扫描全部图层”改为一次线性归集；选中外框只扫描当前组件子图层，避免组件数量增加后点击切换逐步变慢。
- 重复点击当前图层不再触发无效状态同步，普通组件切换也不再重复发布未变化的路径编辑状态。

### Tests
- 新增跨组件连续切换回归测试，验证组件类型、选中图层和外框在点击后同步更新。

## 2.10.0-rc3 - 2026-07-12

### Fixed
- 修复从组件库拖入 UI 组件时，跟随鼠标的虚线预览仍沿用组件库卡片尺寸、与实际落入画布后的组件外框不一致的问题。
- 组件拖拽预览现在复用实际插入尺寸，并按当前画布适配比例与缩放级别换算屏幕大小；圆形、胶囊形和矩形组件继续保留各自的虚线轮廓。

### Tests
- 新增覆盖全部 UI 组件的拖拽预览尺寸回归测试，确保预览宽高始终等于组件画布尺寸乘以当前显示比例。

## 2.10.0-rc2 - 2026-07-12

### Changed
- 根据目标用户覆盖范围，将 Xomo App、测试工程和 `xomo` CLI 的正式最低支持版本从 macOS 12 调整为 macOS 13。
- 保留 macOS 14 专属 SwiftUI API 的运行时兼容分支，以及 arm64、x86_64 双架构发布能力。

### Tests
- 更新部署目标回归测试，并重新验证 App 与 CLI 的通用 Release 产物均标记 `minos 13.0`。

## 2.10.0-rc1 - 2026-07-12

### Added
- 正式将 Xomo App 与 `xomo` CLI 的支持范围扩展到 macOS 12 及以上。

### Changed
- 将 Xcode 工程、单元测试、UI 测试与 Swift Package 的最低部署目标统一为 macOS 12。
- 对 macOS 13/14 才提供的滚动背景、焦点效果、组件拖放、连续悬停和捏合手势 API 增加运行时版本分支；macOS 12 保留点击插入、传统缩放手势与基础悬停等降级交互。
- 将 macOS 13 的 `LabeledContent` 与 `AnyShape` 用兼容 macOS 12 的组合视图替代，并把新版双参数 `onChange` 回调回退为兼容写法。
- 移除仅在 macOS 13 提供的 SwiftUI 窗口默认尺寸修饰符，继续由编辑器最小窗口尺寸保证初始布局可用。

### Tests
- 新增部署目标和兼容层的源码回归检查，并以 macOS 12 deployment target 完成 App 与 CLI 编译验证。

## 2.9.0-rc2 - 2026-07-12

### Fixed
- 修复文字图层在 AppKit 画布中被重复执行纵向坐标翻转、导致文字上下颠倒的问题；文字位置继续使用左上原点，但字形保持正常朝向。

### Tests
- 新增不对称字形方向回归测试，明确区分正常文字与纵向翻转文字。

### Documentation
- 新增 `docs/xomo-tutorial/` 图文教程：包含总索引、6 个独立章节、28 个工具实机图标，以及选区、裁剪、文字、渐变、钢笔、仿制、组件、图层、通道、历史、导入和剪贴板流程截图。

## 2.9.0-rc1 - 2026-07-12

### Added
- 文件菜单新增“导入文件…”，文件选择器明确支持 PNG 与 JPEG，导入后在当前画布中创建可编辑像素图层并自动选中。
- `Command+V` 粘贴图片继续创建新图层，并新增对 Finder 中复制的 PNG/JPG 文件资源的识别，不再只依赖剪贴板位图数据。

### Tests
- 新增剪贴板图片粘贴为图层测试，并补充文件菜单导入入口断言。

## 2.8.0-rc8 - 2026-07-12

### Fixed
- 图层面板的“图层 / 通道 / 复合”分段选择器改为深色系统控件外观，未选中标签使用柔和浅色，避免深灰背景上的黑字不可读。
- 分段选择器保持不进入键盘焦点链，避免鼠标切换后出现额外焦点描边。

## 2.8.0-rc7 - 2026-07-12

### Fixed
- 文字工具在已有画布输入框时再次点击画布，会先提交当前文字到原位置，再在新点击位置开启空白输入框，不再丢失当前输入或把输入框直接挪走。
- 新位置的文字命中测试会排除刚提交的文字层，避免点击其宽文本框内的空白区域时又重新编辑旧文字。

### Tests
- 新增文字层排除命中回归测试，覆盖“提交旧文字后在新位置继续输入”的关键边界。

## 2.8.0-rc6 - 2026-07-12

### Fixed
- 字体选择下拉强制采用深色系统控件外观，并显式使用编辑器浅色文字色，修复“系统字体”和其他字体名称在深色选项栏中显示为黑色的问题。
- 字体下拉继续保持不进入键盘焦点链，避免修复颜色时重新引入 focus ring。

## 2.8.0-rc5 - 2026-07-12

### Fixed
- 统一画布交互为左上原点，修复画笔、橡皮、仿制、色调笔刷、涂抹、修复、选区、路径、文字与形状等工具在 AppKit 绘图边界发生上下镜像的问题。
- 统一像素缓冲区的行方向，点取、区域填充、通道、滤镜、调整、蒙版与选择编辑不再把画布顶部误当成底部。

### Tests
- 新增覆盖全部 28 种编辑工具的坐标审计矩阵，以及 11 组不对称方向回归测试；坐标专项和既有工具冒烟测试全部通过。
- 使用真实 Xomo 界面逐个切换工具，并验证画笔从左上拖到右下后视觉方向与鼠标一致。

## 2.8.0-rc4 - 2026-07-12

### Fixed
- 选区工具的形状展开热区与形状列表不再使用会进入 AppKit 键盘焦点链的原生按钮，消除右下角紫色焦点块和弹出列表首项的紫色焦点框。
- 选区形状列表保留鼠标悬停与当前形状勾选反馈，并补齐无焦点的辅助功能点击动作。

## 2.8.0-rc3 - 2026-07-12

### Fixed
- 字体下拉将 AppKit 内部默认字体名显示为本地化的“系统字体”，不再向用户暴露 `.AppleSystemUIFont`。

## 2.8.0-rc2 - 2026-07-12

### Fixed
- 系统字体族直接沿用 AppKit 系统字体解析，避免把内部系统字体名误交给字体管理器后产生异常文字尺寸。

## 2.8.0-rc1 - 2026-07-12

### Added
- 文字工具支持直接在画布位置创建和编辑文字，组件中的文字层可被文字工具直接命中并修改。
- 文字模型新增字体族，顶部文字选项栏与属性面板都可选择系统字体，字体信息随项目保存并兼容旧项目。

### Changed
- 组件库缩略卡按当前主题的颜色、圆角、边框和组件类型显示差异化预览，不再使用同一套符号占位。

## 2.7.0-rc5 - 2026-07-12

### Fixed
- 将选区工具主体、右下角形状 Popover 热区及 Popover 内全部形状选项设为 `focusable(false)`。
- 同时禁用 SwiftUI focus effect，避免鼠标点击后出现紫色键盘焦点描边。

## 2.7.0-rc4 - 2026-07-12

### Fixed
- 彻底移除工具格中的原生 `Menu`，改用独立透明小按钮打开自定义形状 Popover，避免系统扩大菜单热区或绘制黑色/巨型下拉指示器。
- 选区工具主体保持普通按钮语义和白色 Canvas 图标，右下角仍可单独切换矩形/椭圆形状。

## 2.7.0-rc3 - 2026-07-12

### Fixed
- 将选区工具拆为普通白色 Canvas 图标按钮与独立菜单热区，避免 macOS `Menu` 忽略自定义标签、只显示黑色原生指示器。
- 隐藏系统菜单指示器并保留自绘白色小三角；点击主体可立即选中选区工具，点击右下角仍可切换矩形/椭圆选区。

## 2.7.0-rc2 - 2026-07-12

### Fixed
- 修复深色工具栏中的矩形/椭圆选区图标被 macOS `Menu` 原生控件重新着色为黑色、与其他白色工具图标不一致的问题。
- 选区图标改用 Canvas 直接绘制白色虚线轮廓和白色菜单指示符，避免系统模板图标 tint 覆盖应用主题色。

## 2.7.0-rc1 - 2026-07-12

### Added
- MCP 工具总数扩展至 104 个，新增画布创建、完整项目导入导出、图像图层导入、文字与形状检查编辑、详细调整/滤镜/图层样式设置、图层变换、对齐与分布、属性与链接、智能对象、Layer Comps、选区像素编辑和系统剪贴板操作。
- 新增矢量路径检查与动作工具，可创建路径并操作锚点、子路径、填充、描边、选区、图层蒙版与矢量蒙版。
- 蒙版自动化补齐应用、反相、选区布尔运算、跨图层复制、矢量化与栅格化等动作。
- 补齐画布级变换、选区保存与几何修改、历史快照、特殊绘画工具、Alpha 通道几何操作和智能滤镜逐项管理。
- CLI 新增 `project export/import` 与 `import-image`，可无损往返完整图层项目或从文件创建图层；本机协议请求/响应上限提升以支持大型画布数据。

### Changed
- CLI 离线工具目录和 App 实时严格参数 Schema 同步扩展，版本统一为 `2.7.0-rc1`。

### Tests
- 新增路径创建、结构检查、Layer Comps、画布与文字编辑和完整项目往返自动化测试，并将 App/CLI 的 MCP 工具目录数量纳入精确断言。

## 2.6.0-rc1 - 2026-07-12

### Added
- Xomo App 新增仅监听本机回环地址的自动化服务，使用每次启动随机生成的 0600 权限令牌鉴权，并把当前编辑器注册为 MCP 操作目标。
- 首批 73 个自动化工具覆盖工具选择、颜色、画笔与渐变、形状与文字、画布、图层与图层效果、蒙版、选区、通道、历史、参考线与网格、智能滤镜、调整、组件和多格式导出。
- 新增独立 Swift `xomo` CLI 二进制，支持 `status`、`tools`、`call`、`export`、`doctor`、`install`、`mcp-config` 和 MCP stdio 服务器。
- MCP 服务器支持 `initialize`、`ping`、`tools/list` 与 `tools/call`；App 未运行时仍可返回内置工具目录，启动后自动使用 App 的实时严格 schema。

### Security
- 自动化端口拒绝非 loopback 连接；端点令牌只写入 Xomo 沙盒容器，不通过命令行参数或日志暴露。

### Tests
- CLI MCP 协议测试 2/2 通过；App 自动化注册表测试 3/3 通过，覆盖能力目录、图层增改、选区、通道、工具与组件操作。

## 2.5.0-rc16 - 2026-07-12

### Fixed
- 矩形、椭圆等选区工具的菜单标签强制使用单色浅白图标和下拉角标，与其余工具栏图标保持一致。

## 2.5.0-rc15 - 2026-07-12

### Fixed
- 渐变工具生成选区蒙版时统一使用左上原点，矩形、椭圆和套索选区不再在画布上发生垂直镜像偏移。

### Tests
- 新增非居中矩形选区的渐变回归用例，验证顶部选区不会被绘制到其垂直镜像位置。

## 2.5.0-rc14 - 2026-07-12

### Added
- 选中的组件 Object 始终显示低对比灰色虚线外框；方向键按 1pt 移动，Option + 方向键按 5pt 快速移动。
- 鼠标拖动组件时只移动与组件最外圈一致的虚线预览框，吸附线按预览位置实时计算，松开后才一次性提交真实图层位置。

### Fixed
- 切换图层选择不再清空画布、导航器与直方图渲染缓存，消除无内容修改时的整张画布重合成延迟。

### Tests
- 增加组件拖动延迟提交、连续位移累计、选中缓存保留和 Option 五倍方向键映射回归测试。

## 2.5.0-rc13 - 2026-07-12

### Fixed
- 顶部文件、编辑、图像等菜单改用可控的 plain 标签，深色工作区始终显示高对比浅色文字与箭头。
- 组件库主题选择改为白字自绘菜单；未选中的“组件库”选择器图标也固定以单色浅白线条显示。

## 2.5.0-rc12 - 2026-07-12

### Added
- 组件组作为可命中的画布 Object：移动工具点击未遮挡组件会选中其所在组；上层组件优先，被普通上层图层遮挡时不会错误抢占。
- 选中 Object 后可用 Delete 删除整个组件组与子图层；拖动期间显示随鼠标即时移动的虚线预览边框。

### Tests
- 新增 Object 命中、前后层级、遮挡、整组删除和拖拽预览生命周期回归测试。

## 2.5.0-rc11 - 2026-07-12

### Fixed
- 顶部菜单显式使用高对比浅色 tint，避免 macOS 默认菜单标签在深色工作区呈现近黑文字。
- 左栏“工具 / 组件库”切换改为纯图标按钮，保留悬停提示和无障碍名称，消除窄栏内文字拥挤。

## 2.5.0-rc10 - 2026-07-12

### Fixed
- 侧边导航的选中项底板改用当前组件主题的强调色和边框色，补齐七套风格包的可编辑 token 覆盖。

## 2.5.0-rc9 - 2026-07-12

### Fixed
- 组件库测试先计算组件主题支持结果再交给 Swift Testing 断言，兼容宏对高阶函数表达式的可抛分析。

## 2.5.0-rc8 - 2026-07-12

### Fixed
- 当 XCTest 已将 `.xctest` 临时复制到测试宿主时，Debug app 的自定义签名脚本会交还签名职责给 Xcode 与测试 target，避免再次破坏测试宿主的签名装配。

## 2.5.0-rc7 - 2026-07-12

### Fixed
- 调整 Debug ad-hoc 签名脚本：宿主 app 不再尝试深度重签 XCTest 临时嵌入的 `.xctest`，避免定向测试在签名阶段错误终止。

## 2.5.0-rc6 - 2026-07-12

### Added
- 组件库新增五套像界原创可编辑风格包：柔和安卓、社交内容、玻璃拟态、高密度后台与极简 SaaS；每套均可一键插入六组件页面骨架。
- 增加 Chakra UI 与 Radix Themes 的原生可编辑参考包，并在界面、来源清单和第三方声明中标注 MIT 来源与非官方关系。
- 移动组件时会对相邻组件的左/中/右与上/中/下位置吸附，并即时显示水平或垂直的蓝色对齐引导线。

### Changed
- 顶部菜单改用高对比冷色文字与分层按钮；“导出”升级为明确的蓝色主操作。
- 工具 Tab 恢复为紧凑的 Photoshop 式双列图标网格，组件库 Tab 保持独立展开宽度。

### Tests
- 扩展组件库和引导线模型测试，覆盖七套风格来源、每套页面骨架，以及移动过程中的对齐线显示与结束清理。

## 2.5.0-rc5 - 2026-07-12

### Fixed
- 同步 Xcode 产品、单元测试与 UI 测试 target 的 `MARKETING_VERSION` 至 `2.5.0-rc5`，与应用内版本号保持一致，避免安装包显示旧的 `rc1`。

## 2.5.0-rc4 - 2026-07-12

### Changed
- 完成阶段 5 的真实路径验收与下一轮立项决策：下一轮先做固定范围的布局容器与设计 token 交换，不直接进入 Figma 文件兼容、协作或插件生态。

### Tests
- Computer Use 实测：网页桌面画布 → 柔和移动端主题页面示例 → 新增 `Xomo UI Kit` 可编辑文字图层 → 导出面板确认 PNG/JPEG/WebP/PDF/SVG/PSD、命名规则和 1x/2x/3x 批量控件。

## 2.5.0-rc3 - 2026-07-12

### Added
- 导出面板增加文件名规则和多倍率导出：可选择仅文档名、文档名加范围或文档名加范围和倍率，并可一次输出主倍率及 1x / 2x / 3x 变体。

### Tests
- `ImageEditorExportFormatTests` 扩展至 3/3，通过批量倍率命名、命名规则和 PDF 不参与位图倍率批处理的回归测试。

## 2.5.0-rc2 - 2026-07-12

### Added
- 导出面板新增 PDF 与纯矢量 SVG：PDF 可稳定封装混合画布的合成结果；SVG 直接写出形状、路径和文字，绝不把位图伪装为 SVG。

### Changed
- SVG 只在没有实际位图、蒙版、滤镜、裁切、非普通混合和图层特效的画布上可选；不满足条件时明确拒绝导出。

### Tests
- 新增 `ImageEditorExportFormatTests` 2/2，通过纯矢量 SVG 结构与混合画布 PDF/SVG 边界测试。

## 2.5.0-rc1 - 2026-07-12

### Added
- 组件库新增主组件—实例的基础关系：可设定主组件、链接同类实例、按主组件同步主题样式，或将实例明确脱离；关系随项目文件保存。

### Tests
- `XomoLeftSidebarTests` 30/30 通过，覆盖主组件同步、实例脱离和项目文件往返。

## 2.4.0-rc4 - 2026-07-12

### Added
- 组件库可按当前主题插入原创页面示例：原生工作台、柔和移动端个人页和高密度后台设置页；每个示例由六个可单独编辑的组件组组成。

### Tests
- `XomoLeftSidebarTests` 29/29 通过，覆盖三套主题示例的组件组成、主题实例标记和可编辑子图层。

## 2.4.0-rc3 - 2026-07-12

### Added
- 已插入的按钮、输入框、搜索框、文本域、选择框和卡片可应用所选主题；组件类型、当前主题与“保留局部样式”标记会随项目文件保存和恢复。

### Tests
- `XomoLeftSidebarTests` 28/28 通过，覆盖已有按钮的局部覆写保留与项目文件往返、已有输入框和卡片的主题应用，以及旧组件首次换肤时的元数据迁移。

## 2.4.0-rc2 - 2026-07-12

### Added
- 输入框、搜索框、文本域、选择框和卡片接入三套 Xomo 组件主题 token；表面、边框、正文与标题颜色随当前主题生成。

### Tests
- `XomoLeftSidebarTests` 25/25 通过，覆盖三套主题下输入框和卡片的表面、边框与文字颜色。

## 2.4.0-rc1 - 2026-07-12

### Added
- 开始阶段 4：组件库提供像界原生、柔和移动端和高密度后台三套原创主题 token；主按钮会按当前主题生成对应的强调色、描边和文字颜色。

### Tests
- `XomoLeftSidebarTests` 24/24 通过，包含三套主题 token 与主题化主按钮的回归覆盖。

## 2.3.0-rc6 - 2026-07-12

### Added
- 补齐组件库 v1 的资源清单，逐项记录 18 个固定组件家族的原创来源、许可证、资源类型与首次版本。
- 增加移动端登录和网页设置两条六组件组合回归路径，覆盖插入、撤销/重做与项目文件保存/恢复。

### Tests
- `XomoLeftSidebarTests` 扩展至 22 项，覆盖两条组合页面的图层分组和项目文件往返。
- Computer Use 实测从组件库点击插入轮播卡片、按钮与输入框；状态栏与图层面板分别显示组件组及其可编辑文字、形状、像素子图层。

## 2.3.0-rc5 - 2026-07-12

### Added
- 组件库新增轮播卡片和空状态；轮播图片、标题、指示点与空状态图标、文案均可独立编辑。

### Tests
- `XomoLeftSidebarTests` 20/20 通过，覆盖两个新增内容组件的图层结构。

## 2.3.0-rc4 - 2026-07-12

### Added
- 组件库新增列表行、顶部导航、侧边导航和 Tab 栏；它们分别拆为可编辑背景、选中状态和导航文案图层。

### Tests
- `XomoLeftSidebarTests` 19/19 通过，覆盖四种导航与列表组件的图层结构。

## 2.3.0-rc3 - 2026-07-12

### Added
- 组件库新增开关、复选框、标签和徽标；每项拆为可独立编辑的背景、圆点或文案图层。

### Tests
- `XomoLeftSidebarTests` 18/18 通过，覆盖四种选择与标记组件的图层结构。

## 2.3.0-rc2 - 2026-07-12

### Added
- 组件库新增搜索框、文本域和选择框；搜索与选择框的图标、占位文字和背景均保持为独立可编辑图层。

### Tests
- `XomoLeftSidebarTests` 17/17 通过，覆盖三种新增表单输入组件的图层结构。

## 2.3.0-rc1 - 2026-07-12

### Added
- 组件库新增主按钮、次按钮、幽灵按钮和图标按钮四个原创按钮层级；每项均生成可编辑的背景形状与文字图层。

### Tests
- `XomoLeftSidebarTests` 16/16 通过，覆盖新增按钮变体的可编辑图层结构。

## 2.2.0-rc8 - 2026-07-12

### Tests
- 新增 XCUITest，模拟系统级长按拖入组件库按钮至画布，避免将“可点击插入”误当成“可拖入”。测试目标已编译；本机 Xcode UI 测试运行器在 worker materialize 阶段停滞，尚未将该用例记为通过。

## 2.2.0-rc7 - 2026-07-12

### Added
- 组件库新增可直接插入或拖入画布的图标；生成一个组与可编辑的星形矢量路径图层，可在原有路径编辑工作流中继续修改。

### Tests
- `XomoLeftSidebarTests` 15/15 通过，覆盖图标组件的十锚点路径与项目文件往返保存。
- Computer Use 阶段 2 验收：组件库首屏六项均可点击；实测头像生成头像组、文字与椭圆背景，图标生成图标组与星形路径图层。

## 2.2.0-rc6 - 2026-07-12

### Added
- 组件库新增可直接插入或拖入画布的头像；生成一个独立组、可编辑椭圆背景形状和可编辑首字母文字图层。

### Tests
- `XomoLeftSidebarTests` 13/13 通过，覆盖头像组件的椭圆形状、文字子图层与项目文件往返保存。

## 2.2.0-rc5 - 2026-07-12

### Added
- 组件库新增可直接插入或拖入画布的图片组件；生成一个组和真实、可继续编辑的像素图片图层，而非以形状假装图片。

### Tests
- `XomoLeftSidebarTests` 11/11 通过，覆盖图片组件的真实像素图层、位图表示与项目文件往返保存。
- Computer Use 实测点击“图片”后，画布显示抽象渐变占位图；右侧图层面板可见“图片”组及其“图片占位图”像素子图层。
- 已执行完整 `xcodebuild test` 门槛；该仓库已知的 AppKit/Swift Testing 并行渲染不稳定问题再次触发，既有 `ImageEditorFilterTests` 的锐化断言失败后，相邻 Core Image 测试失去进展。本次定向组件测试独立通过。

## 2.2.0-rc4 - 2026-07-12

### Added
- 组件库新增可直接插入或拖入画布的卡片；生成独立组、可编辑背景形状、标题文字和说明文字图层。

### Tests
- `XomoLeftSidebarTests` 9/9 通过，覆盖按钮/输入框/卡片组件的图层结构、组件目录和项目文件往返保存。
- Computer Use 实测点击“卡片”后，画布显示卡片，右侧图层面板可见独立的卡片组、标题文字、说明文字和背景形状图层。

## 2.2.0-rc3 - 2026-07-12

### Added
- 组件库新增可直接插入或拖入画布的输入框；生成独立组、可编辑矩形背景与可编辑占位文字图层。

### Tests
- `XomoLeftSidebarTests` 7/7 通过，覆盖按钮/输入框组件的图层结构、组件目录和项目文件往返保存。

## 2.2.0-rc2 - 2026-07-12

### Added
- 组件库的“按钮”现在可点击插入或直接拖入画布；生成一个组、可编辑矩形背景及可编辑文字图层，而不是位图预览。

### Tests
- `XomoLeftSidebarTests` 4/4 通过，覆盖双 Tab 状态、按钮组件的组/形状/文字图层结构及项目文件往返保存。
- Computer Use 实测点击组件库的“按钮”会在透明画布中央插入按钮组；右侧图层面板可见独立的组、文字与形状子图层，并可通过撤销/重做完整移除、恢复。

## 2.2.0-rc1 - 2026-07-12

### Added
- 左侧栏升级为固定宽度的“工具 / 组件库”双 Tab；默认进入工具，切换组件库时保留当前工具与画布位置，避免画布横跳。
- 组件库首屏提供按钮、输入框、卡片、图片、头像、图标等可编辑组件类别的预览；下一小版本再接入真实拖入画布，明确不会插入不可编辑截图。

### Tests
- `XomoLeftSidebarTests` 2/2 通过，覆盖双 Tab 目录以及切换时保留当前工具状态；Computer Use 实测切换“组件库”后画布尺寸和选中移动工具保持不变，切回“工具”后移动工具仍选中。

## 2.1.0-rc3 - 2026-07-12

### Added
- 设计画布现在会将预设、背景、导出倍率和建议边距作为文档元数据保存进项目文件；重新打开时恢复 8pt 网格、尺寸和默认导出倍率。

## 2.1.0-rc2 - 2026-07-12

### Fixed
- 修复新建设计画布时选择的默认导出倍率未传递给导出面板的问题；手机和平板预设现在会自动使用 3x。

### Tests
- `XomoCanvasPresetTests` 4/4 通过，覆盖 12 项预设、尺寸/倍率边界、创建画布状态与项目元数据往返恢复；Computer Use 实测透明手机预设保存并重开后仍为 390×844、3x 导出。

## 2.1.0-rc1 - 2026-07-12

### Added
- 新增“新建设计画布”流程：提供固定 12 项手机、平板、网页、桌面应用与社交预设，可修改自定义宽高、背景与 1x/2x/3x 导出倍率。
- 新建 UI 画布默认启用 8pt 网格及网格吸附，建立混合图层文档；预设模型单独覆盖尺寸、倍率及尺寸边界测试。

### Tests
- `XomoCanvasPresetTests` 3/3 通过；Computer Use 实测网页桌面预设创建为 1440×1024 设计画布。

## 2.0.0-rc3 - 2026-07-12

### Removed
- 删除 Xomo 内部已无调用方的对象存储配置、上传阶段、历史记录、变体与反馈数据模型，完成旧 QPic 工作流在 Xomo 的代码边界清理。

### Tests
- 干净 Debug `xcodebuild build` 成功；Computer Use 验证当前构建可启动、创建图层、缩放并导出 1440×900 PNG。

## 2.0.0-rc2 - 2026-07-12

### Removed
- 删除 Xomo 内部不再可达的系统托盘、截图快捷键、区域截图标注、对象存储上传、上传历史与登录项模块，以及与其绑定的工作台界面和测试；这些能力继续由独立的 QPic 承担。

### Changed
- 移除旧工作流的窗口兼容桥，Xomo 只保留普通编辑器主窗口作为产品入口。

## 2.0.0-rc1 - 2026-07-11

### Changed
- Xomo 从系统托盘应用切换为普通 macOS 主窗口：启动后直接显示未命名画布，不再注册截图快捷键、不再显示上传配置引导，也不再以 `MenuBarExtra` 作为入口。
- 新增 `XomoEditorWorkspaceView`，以完整的图片编辑器承载空白画布；Xomo/QPic 功能拆分进入阶段 0 的逐步清理过程。

### Tests
- 将应用入口范围测试改为验证普通窗口、直接画布和托盘/截图入口缺失。

## 1.457.0-rc26 - 2026-07-11

### Changed
- 品牌基础信息迁移为“像界 / Xomo”：macOS 应用显示名、产物名、安装包卷标与中英日本地化名称统一为 Xomo（简体中文显示为“像界”）。
- 主应用 Bundle ID 改为 `im.some.xomo`；测试包使用对应的 `im.some.xomoTests` 与 `im.some.xomoUITests` 标识，以便与拆分后的 QPic 独立安装和保存状态。
- 新增 `XOMO_UI_DESIGN_ROADMAP.md`：定义 Xomo 与 QPic 拆分、混合画布、UI 预设、组件库、主题 token 的阶段顺序、收敛条件、相关测试节奏、每 5/10 版本构建门槛、Git 提交/推送节奏及 Computer Use 真实点击验收要求。

## 1.457.0-rc25 - 2026-07-11

### Fixed
- 替换 macOS 不存在的 `paintbucket.fill` SF Symbol；油漆桶工具栏现在使用内置矢量油漆桶图标，其他入口使用已验证可用的系统后备图标。

## 1.457.0-rc24 - 2026-07-11

### Fixed
- 缩放工具条改为画布工作区的顶层覆盖层，画布放大、平移或滚动时不会遮挡；其下方保留独立布局空间，鼠标始终可点击缩放控件。

## 1.457.0-rc23 - 2026-07-11

### Fixed
- 图层行将可见性眼睛图标调整为最左侧控件，并收紧左右留白；右侧停靠栏扩展至 384pt。
- 图层行的不透明度百分比设为固定单行最小宽度，`100%` 不再逐字符换行。

## 1.457.0-rc22 - 2026-07-11

### Fixed
- 最终修复形状图层绘制坐标与 macOS 图形上下文原点不一致的问题；拖到画布上方或下方的图形现在会显示在对应位置。

### Tests
- 新增并通过形状图层顶部坐标回归测试；独立通过图层合成方向回归测试。

## 1.457.0-rc21 - 2026-07-11

### Changed
- 全量独立测试脚本改用 `/tmp` 隔离 DerivedData，统一跳过测试构建的产品签名与用户脚本沙盒，避免受本机全局 Xcode 缓存及嵌套沙盒权限影响。

### Fixed
- 修复多图层连续合成时，既有画面会随着新增图层次数奇偶而上下翻转的问题。
- 将所有已声明的图片编辑器菜单快捷键接入窗口级事件分发，避免自定义窗口只显示快捷键但按键不生效。
- 修复形状图层合成未转换 AppKit 坐标原点，导致拖到画布顶部的形状出现在底部的问题。

### Tests
- 开始执行图片编辑器全部快捷键、29 个工具及从空白画布创作流程的分层自动化验收。

## 1.457.0-rc20 - 2026-07-11

### Fixed
- 图片编辑器现在在窗口级处理 `Command+A`，无论焦点状态如何都会立即全选当前画布。

### Tests
- 新增 `Command+A` 全选画布快捷键映射测试。

## 1.457.0-rc19 - 2026-07-11

### Changed
- 图片编辑器顶部菜单、操作按钮及工具选项中的下拉和按钮不再进入键盘焦点链。
- 前景色与背景色色块改为直角 1px 白色边框。
- 历史面板改为单击选中历史步骤，并保留独立的恢复按钮。

### Fixed
- 修复裁剪完成后仍保留旧选区偏移、导致选区越出新画布的问题；裁剪后会自动全选新画布。
- 补齐 `Command+Z`、`Option+Z` 撤销和 `Command+Shift+Z` 重做的窗口级快捷键处理。
- 历史面板展开时可按 Delete 删除选中步骤及其后的全部操作，并回到前一步状态。
- 命名历史快照现在同时保存当时的渲染结果，恢复后显示与创建快照时一致。

### Tests
- 新增裁剪全选、历史截断与撤销快捷键映射测试。

## 1.457.0-rc18 - 2026-07-11

### Changed
- 画布光标按工具语义重新设计：画笔类显示黑白双描边的实际笔刷直径、中心落点与独立工具徽标；选区、填充、渐变、形状和缩放类使用精确十字热点与工具徽标；移动、抓手和文字保留系统标准光标。
- 钢笔使用明确的倾斜笔尖光标，热点固定在笔尖；当至少三个锚点且指针进入首个锚点的真实闭合阈值时，笔尖旁出现闭合圆环，点击会按同一判定闭合路径。
- 裁剪确认与取消从画布浮层移动到“未命名画布”和缩放控件所在的贴顶工具栏，缩放或平移画布时位置保持不变。
- 前景色与背景色色块改为直角纯色块和完整 3px 白色内边框，不再复用带圆角裁切的通用图标按钮样式。

### Fixed
- 修复画笔、橡皮和其他笔刷型工具光标固定为 28px、未反映当前笔刷大小与画布缩放的问题。
- 修复前景/背景色色块边框被圆角按钮裁切后只剩不完整白线的问题。

### Testing
- 新增笔刷光标直径、热点、钢笔闭合状态图像和闭合阈值测试；使用 Computer Use 实测不同笔刷大小、画笔/橡皮徽标、钢笔笔尖与闭合提示、直角色块边框及贴顶裁剪确认条。

## 1.457.0-rc17 - 2026-07-11

### Changed
- 画布坐标系统一为左上角 `(0,0)`，横向向右、纵向向下；顶部与左侧坐标尺、指针状态、选区和工具落点使用同一坐标约定。
- 裁剪工具改为两阶段交互：拖拽只生成虚线裁剪预览，画布上方通过确认或取消按钮决定是否实际裁剪。
- 快速选择与画笔改用不同图标，钢笔改用贝塞尔曲线图标；画笔、橡皮、渐变等工具进入画布时显示对应工具光标。

### Fixed
- 修复移动、裁切或缩放过的图层上，画笔、橡皮、仿制图章、修复、涂抹、模糊、锐化、减淡、加深等像素工具直接误用画布坐标，造成笔迹与鼠标轨迹错位及图层位置被重置的问题。
- 修复渐变端点和选区蒙版没有完整映射到图层局部像素空间，导致渐变落在选区镜像位置或越过当前选区的问题。
- 修复方向键上下微移与左上原点坐标约定相反的问题。

### Testing
- 新增左上原点画布换算、移动缩放图层画笔/橡皮落点、纵向选区渐变约束回归测试；定向测试通过，并使用 Computer Use 复测真实画布轨迹、裁剪确认控件和坐标尺。

## 1.457.0-rc16 - 2026-07-11

### Added
- 选区工具改为形状工具组，支持矩形、正方形、椭圆和圆形，并保持拖拽预览与最终选区一致。
- 新增 8-bit RGB/RGBA PSD 导入导出：保留图层名称、位置、显隐、透明度和常见混合模式；QPic 专有文字、形状和填充内容按独立栅格图层交换。

### Changed
- Debug 编辑器直接打开“未命名画布”和空白“图层 1”，移除全屏“正在打开图片编辑器”等待页；初始合成图缓存、右侧栏分阶段挂载、App Debug 目标启用优化编译，图层首屏工具收敛为常用操作与“更多”菜单。
- 选项栏按当前工具显示相关参数：文字工具直接提供内容与字号，画笔类显示大小/硬度，选区显示羽化，移动与裁剪不再显示无关滑块；默认前景/背景色恢复为黑/白。
- 导航器默认折叠，图层列表保持首屏可见；图层变换旋转手柄缩短连线并增加旋转图标。

### Fixed
- 图层变换框改按非透明内容边界显示，纯透明图层不再出现铺满画布的蓝色虚线框与旋转手柄。
- 修复文字工具必须先存在文字图层才能输入文字的循环依赖。
- Debug ad-hoc 签名脚本支持测试构建显式跳过，避免测试插件嵌入后被提前深度签名破坏。

### Testing
- 使用 Computer Use 从空白画布实际完成渐变、圆形选区、油漆桶填充、裁剪、形状图层和多图层构图，并据此修正空白层变换框、文字入口与无关参数噪声。
- PSD 往返测试同时验证 macOS `NSImage` 可读取导出文件；选区形状、PSD 和三语资源定向测试通过。

## 1.457.0-rc15 - 2026-07-11

### Changed
- 图层页将搜索、常用操作、图层行、显隐按钮和拖拽把手提升到首屏；混合条件、蒙版和筛选等高级控件收进默认折叠的“高级图层设置”，导航器继续紧跟图层面板。
- 图层名称改为纯展示文本，单击名称或行内空白会立即选中图层，避免常驻文本框抢走选择手势；重命名仍可在属性面板完成。
- 图层整行拖放统一使用 `NSItemProvider` 与 macOS `DropDelegate`；把手额外使用直接垂直拖拽手势，按位移锁定目标图层并调用同一重排模型，兼容真人拖放和自动化原子拖动，同时保留插入带反馈。

### Fixed
- 修复右侧图层面板被高级控件占满、实际图层列表在默认窗口高度完全不可见的问题。

### Testing
- 使用仓库内 Computer Use UI QA 技能完成基线截图、整行切层、眼睛显隐及恢复、正反向拖拽排序、`Alt +` / `Alt -` 缩放和工具栏常驻截图回归；同时定位 Sky Computer Use 26.708.1000366 在转换完整 QPic AX 树时的固定数组越界崩溃。

## 1.457.0-rc14 - 2026-07-11

### Added
- 新增仓库内 `computer-use-ui-qa` 技能，以“截图—单步操作—复截图—检查—修正—重测”的方式验收桌面界面，并覆盖图层选择、显隐、拖拽排序与滚动可见性。

### Fixed
- 右侧栏顶部的图层与导航器默认展开；图层列表提供明确的拖拽把手，并为列表、图层行和显隐按钮补齐稳定辅助功能标识，方便快速切层、开关显示和重排。
- 左侧工具栏继续与画布视口分栏布局，画布放大、缩小或平移时始终保持可见。

## 1.457.0-rc13 - 2026-07-11

### Fixed
- 右侧图层、导航器、历史、滤镜与属性面板改用稳定的固定侧栏布局，面板头和展开内容保持同宽且不再溢出到画布。
- 滤镜主操作独占一行，滤镜图层与智能滤镜操作在第二行紧凑排列，避免按钮被压缩后显示本地化 key。
- 左侧工具栏获得固定布局优先级，任何按钮、快捷键、滚轮或触控板缩放都会自动保持工具栏可见。

## 1.457.0-rc12 - 2026-07-11

### Added
- 图片编辑器支持 `⌥-` 缩小与 `⌥+` 放大，并兼容使用 `⌥=` 触发放大的键盘布局。

## 1.457.0-rc11 - 2026-07-11

### Changed
- 画布标签栏新增常驻缩小、对数缩放滑块、放大和适合窗口按钮，可在 8%–800% 范围内直接调整画布大小。
- Debug 示例文档名称由内部调试文案改为“未命名画布”，避免与用户画布名称混淆。

### Fixed
- 测试启用 Xcode 原生本地签名时自动跳过自定义 Debug 签名脚本，避免两套签名机制互相覆盖测试宿主。

## 1.457.0-rc10 - 2026-07-11

### Fixed
- 新建选区后不再为菜单可用性整图栅格化选区，也不再误清空画面合成缓存，鼠标松开后立即显示选区边缘。
- 透明画布改用更清晰的灰白交替棋盘格；Debug 示例画布保留透明背景，便于直接验证透明区域。

## 1.457.0-rc9 - 2026-07-11

### Changed
- 编辑器顶部提交按钮精简为“预览”，保留完整的辅助功能名称。
- 左侧工具栏收紧为 30px 双列图标网格，并为主要按钮补充悬停、按下与选中颜色状态，同时禁用无必要的键盘焦点停留。
- 前景/背景色板支持一键交换；点击任一色块会打开 macOS 全屏取色器并更新对应颜色。

## 1.457.0-rc8 - 2026-07-11

### Fixed
- 补齐图片编辑器“应用滤镜”操作的中、英、日文案，避免滤镜面板直接显示本地化 key。

## 1.457.0-rc7 - 2026-07-11

### Fixed
- Debug 启动图片编辑器时先显示轻量启动窗口，再异步构造开发画布与完整编辑器视图，避免主窗口被同步初始化阻塞数秒才出现。
- Debug 与测试目标在本地缺少有效开发证书时改用可验证的 ad-hoc 签名，并显式携带测试所需的沙盒权限，修复测试启动前因无效代码签名触发 SIGTRAP 的问题。
- 笔刷和橡皮擦不再在提交结果后重复整图位图化，降低单次笔划结束时的卡顿。
- 调试期间固定显示系统 Dock 图标，方便发现和切回应用。
- Debug 启动将轻量编辑器窗口前置到全局截图快捷键初始化之前，缩短首窗口出现前的主线程工作。
- Debug 构建记录首窗口与完整编辑器两个启动阶段的耗时，便于后续定位启动回归。
- 启动计时使用会保留的日志级别，确保本机可读取实际分段耗时。
- Debug 开发样例画布缩至 960×600，避免启动时以大尺寸样例放大编辑器首帧成本。

## 1.457.0-rc1 - 2026-07-11

### Fixed
- 通道页的已保存 Alpha 通道操作改为紧凑菜单，修复操作按钮横向撑开右栏、内容溢出到画布左侧的问题。
- 通道列表改用 84×56 缓存缩略图，切换图层、通道和图层复合页时不再为每个条目生成整张画布预览图。

## 1.457.0 - 2026-07-11

### Changed
- 图层面板改为与导航、历史、滤镜和属性一致的折叠分组；展开时纳入右侧栏统一滚动布局，自动将下方分组推开，不再覆盖。

## 1.456.0 - 2026-07-11

### Added
- 图片编辑器窗口底边中央新增常驻工具提示，显示当前工具名称与具体用法，并随点击或快捷键切换即时更新。

## 1.455.0 - 2026-07-11

### Added
- 图片编辑器左侧每个工具图标均提供包含具体使用方式的本地化悬停提示。

## 1.454.0 - 2026-07-11

### Changed
- 图片编辑器左侧工具栏改为两列图标网格，工具过多时网格独立滚动，前景/背景色板固定在底部。

## 1.453.0-rc1 - 2026-07-11

### Fixed
- 将通道与图层复合页收进图层面板内部滚动区域，修复内容溢出覆盖历史、滤镜和属性分组的问题。

## 1.453.0 - 2026-07-11

### Changed
- 图片编辑器左侧工具栏改为整格点击命中，点击图标所在按钮区域即可选择工具。
- 右侧工作区改为图层面板固定可见，导航、历史、滤镜和属性面板按需折叠展开，避免图层列表被密集属性控件挤出可视区域。

## 1.452.0-rc2 - 2026-07-11

### Fixed
- 将图层描边纯色转换到 deviceRGB 后再绘制，修复命名色空间下描边颜色错误与不透明度回归测试失败。

## 1.452.0-rc1 - 2026-07-11

### Fixed
- 图层模型移动与键盘微移保持精确 delta；只有画布拖拽才应用网格与参考线吸附，避免组成员发生意外坐标偏移。

## 1.452.0 - 2026-07-11

### Added
- 颜色取样器支持 `Option+X` 快捷键清空画布样点。

## 1.451.0 - 2026-07-11

### Changed
- 颜色取样器改为 3×3 像素平均取样，降低压缩噪点与单像素异常对 RGBA 读数的影响。

## 1.450.0 - 2026-07-11

### Added
- 颜色取样器 RGB 标签新增 Alpha 读数，半透明素材与图层蒙版可直接检查 RGBA。

## 1.449.0 - 2026-07-11

### Added
- 颜色取样器在画布标记旁显示实时 RGB 读数，方便对比修图前后的目标色。

## 1.448.0 - 2026-07-11

### Added
- 颜色取样器选项栏新增清除取样点命令，可在不重开文档的情况下重置画布上的编号样本。

## 1.447.0 - 2026-07-11

### Added
- 图片编辑器新增颜色取样器；在 `I` 工具组中与吸管切换，可在画布保留最多四个编号取样点且不改变前景色。

## 1.446.0 - 2026-07-11

### Added
- 仿制图章新增“设置图章取样点”命令；无需按住 Option，也可从工具选项栏进入取样模式并在画布点击源点。

## 1.445.0 - 2026-07-11

### Added
- 图片编辑器新增红眼工具；在 `J` 修复工具组中与修复画笔、修补切换，点击异常红色瞳孔可按笔刷半径降低红色通道而保留透明度和局部亮度。

## 1.444.0 - 2026-07-11

### Added
- 图片编辑器新增海绵工具；在 `O` 工具组中与减淡、加深切换，可沿笔触提升局部饱和度并保留亮度与透明度。

## 1.443.0 - 2026-07-11

### Added
- 图片编辑器新增快速选择工具；在 `W` 工具组中与魔棒切换，按笔刷路径抽样并合并连续颜色区域，同时支持替换、添加、减去和相交选区模式。

## 1.442.0-rc5 - 2026-07-11

### Fixed
- 图层缩放和旋转手柄现在只在移动工具启用时显示并接收手势，避免刷子、选区等画布工具被变换控制抢占操作。

## 1.442.0-rc4 - 2026-07-11

### Fixed
- 图片编辑器的 Select 菜单不再为了判断“存储当前通道为 Alpha 通道”是否可用而反复合成整张图，避免编辑操作后出现布局循环和内存失控。

## 1.442.0-rc3 - 2026-07-11

### Fixed
- 图片编辑器为工具栏、当前工具状态、画布、菜单、导航器、属性面板和顶部命令补齐稳定的辅助功能标识，真实桌面自动化可准确逐项操作，不会误点到动态属性控件。

## 1.442.0-rc2 - 2026-07-11

### Fixed
- 图片编辑器的“从图层透明度载入选区”可用性判断改为按文档缓存；属性面板、图层面板和菜单的 SwiftUI 刷新不会再反复扫描所选图层的 alpha 像素并导致主线程满核。

## 1.442.0-rc1 - 2026-07-11

### Fixed
- 图片编辑器把整图合成、通道预览、Alpha 通道缩略图与直方图改为文档级缓存；画布、导航器和信息面板在同一 SwiftUI 刷新中不再重复执行逐像素图层合成，避免编辑时主线程持续满核和界面转圈。

## 1.442.0 - 2026-07-11

### Changed
- Debug 图片编辑器示例画布改为深色背景层加已选中的透明形状编辑层，启动后可立即测试画笔、变换、图层样式与混合；编辑器同时支持从预先构造的文档启动，正式图片编辑入口行为不变。

## 1.441.0 - 2026-07-11

### Added
- Debug 构建启动 App 时默认直接打开图片编辑器，并提供一张内置开发测试画布；测试宿主与 Release 构建保持原有启动路径，不会弹出编辑窗口。

## 1.440.0 - 2026-07-11

### Tooling / Tests
- 扩展图片编辑器图层样式颜色回归测试，覆盖光泽、渐变叠加两端与斜面浮雕高光/阴影的命令层和内联取色器绑定，防止既有可编辑颜色回退为固定默认色。

## 1.439.0 - 2026-07-11

### Added
- 图片编辑器补齐 Photoshop 风格 `R` 工具组快捷键：按 `R` 选择模糊工具，按 `Shift + R` 可在模糊、锐化和涂抹工具间轮换。

## 1.438.0 - 2026-07-11

### Added
- 图片编辑器图层样式属性面板为斜面浮雕新增高光色与阴影色的内联取色器，可直接调整效果两侧的明暗颜色并实时预览。

## 1.437.0 - 2026-07-11

### Added
- 图片编辑器图层样式属性面板为渐变叠加新增起点色与终点色的内联取色器；调节样式、透明度、角度或缩放时不再覆盖用户已选的两端颜色。

## 1.436.0 - 2026-07-11

### Added
- 图片编辑器图层样式属性面板为光泽（Satin）新增内联取色器，可直接选取任意颜色并实时预览；原“使用前景色”按钮保留。

## 1.435.0 - 2026-07-10

### Added
- 图片编辑器图层样式属性面板为外发光、内发光和颜色叠加新增内联取色器：此前这三种效果的颜色是写死的默认值（黄/青/红）无法调整，现在可直接选取任意颜色并实时预览。

- 图片编辑器画布新增 ⌘ / ⌥ + 鼠标滚轮缩放：复用已有触控板捏合缩放的 `magnifyCanvas(_:at:viewportSize:)` 锚定数学，缩放围绕光标位置锚定；每个离散滚轮 tick 结束一次缩放会话，保证连续滚动正确叠加。滚轮缩放通过透明的 AppKit 承载视图 + 本地 `scrollWheel` 监听实现，作用域严格限制在编辑器窗口且光标落在画布视口内，避免主窗口误触发；捕获层对点击完全透明，不影响画布点击、绘制和拖拽平移。

### Tooling / Tests
- 新增 `scripts/run_tests_isolated.rb`：逐测试独立 `xcodebuild` 进程运行 `veilpicTests`，规避 Swift Testing 并行时踩坏 AppKit 进程级绘图 / 命名色彩空间状态导致的像素测试假失败，输出 JSON + Markdown 报告，支持 `--jobs`、`--filter`、`--skip-build`、`--fail-fast`。详见 `product-overview.md` 的「测试运行注意事项」。

## 1.434.0 - 2026-07-10

### Added
- 图片编辑器图层样式属性面板为描边色和投影色新增内联取色器（ColorPicker），可直接选取任意颜色实时预览，不必再绕道“设为前景色”；原“使用前景色”快捷按钮保留。

## 1.433.0-rc1 - 2026-07-10

### Fixed
- 图片编辑器的画布坐标换算改为仅读取画布尺寸，避免显示图层变换控制框或更新焦点树时反复执行全图分层合成，显著降低窗口首次显示和交互更新的主线程 CPU 峰值。

## 1.433.0 - 2026-07-10

### Added
- 图片编辑器画布捏合缩放升级为“光标锚定缩放”：以手势落点为锚点缩放，缩放时该点在画布中保持不动（而非围绕画布中心），同时联动平移偏移，手感更接近专业编辑器。

## 1.432.0 - 2026-07-10

### Added
- 图片编辑器 Filter 菜单新增 Artistic 分类(Oil Paint),并把 Vignette 接入 Distort 分类;至此引擎支持的每一个滤镜都在菜单中有入口。
- 新增滤镜菜单完整性测试,遍历所有 `ImageEditorFilter` case 断言其均有菜单入口,防止后续新增滤镜漏挂菜单。

## 1.431.0 - 2026-07-10

### Added
- 图片编辑器补齐经典 `J` 工具快捷键组：修复画笔（Healing Brush）与修补工具（Patch）共享 `J`，按 `Shift + J` 在两者间循环，与 Photoshop 7 工具键位一致。

## 1.430.0 - 2026-07-10

### Added
- 图片编辑器画布支持触控板捏合缩放：在画布上双指捏合即可以手势起点缩放为基准放大/缩小，缩放比例限制在 8% 到 800%，状态栏实时显示当前缩放百分比。

## 1.429.0 - 2026-07-10

### Added
- 图片编辑器 Image > Adjustments 子菜单补齐经典调整项：Exposure、Vibrance、Shadows/Highlights、Black & White、Photo Filter 和 Color Lookup 可直接选择并打开属性面板准备参数。

## 1.428.0 - 2026-07-10

### Added
- 图片编辑器 Image 菜单新增经典 Adjustments 子菜单：Brightness/Contrast、Channel Mixer、Selective Color、Gradient Map、Posterize 和 Threshold 可直接选择已有调整并打开属性面板准备参数。

## 1.427.0 - 2026-07-10

### Added
- 图片编辑器 Filter 菜单新增 Liquify 分类入口：Push、Twirl 和 Pucker/Bloat 可直接选择已有液化滤镜并打开属性面板准备参数。

## 1.426.0 - 2026-07-10

### Added
- 图片编辑器 Layer > Layer Style 新增 Photoshop 7 风格 Blending Options 入口，可直接打开属性面板准备编辑当前图层样式。

## 1.425.0 - 2026-07-10

### Added
- 图片编辑器 Filter 菜单继续补齐 Photoshop 7 风格分类入口：Stylize 提供 Emboss / Find Edges，Distort 提供 Offset / Wave / Ripple / Pinch / Spherize。

## 1.424.0 - 2026-07-10

### Added
- 图片编辑器新增 Filter 菜单经典滤镜分类入口：Blur、Sharpen、Noise、Pixelate 和 Other 可直接选择已有轻量滤镜并打开属性面板。

## 1.423.0 - 2026-07-10

### Added
- 图片编辑器新增 Filter 菜单经典 `Command + F` 上次滤镜命令，可将当前滤镜参数直接应用到当前可编辑图层或所选图层。

## 1.422.0 - 2026-07-10

### Added
- 图片编辑器新增 Image 菜单经典反相命令：`Command + I` 对当前可编辑图层或所选图层执行 Invert。

## 1.421.0 - 2026-07-10

### Added
- 图片编辑器新增 Image 菜单经典去色命令：`Shift + Command + U` 对当前可编辑图层或所选图层执行 Desaturate。

## 1.420.0 - 2026-07-10

### Added
- 图片编辑器新增 Image 菜单经典调整快捷入口：`Command + L` 色阶、`Command + M` 曲线、`Command + B` 色彩平衡、`Command + U` 色相/饱和度。

## 1.419.0 - 2026-07-10

### Added
- 图片编辑器新增 View 菜单经典参考线快捷键：`Shift + Command + ;` 开关参考线吸附、`Option + Command + ;` 锁定或解锁参考线。

## 1.418.0 - 2026-07-10

### Added
- 图片编辑器新增 Select 菜单经典羽化快捷键：`Option + Command + D` 执行 Feather Selection。

## 1.417.0 - 2026-07-10

### Added
- 图片编辑器新增 View 菜单经典显示快捷键：`Command + R` 显示标尺、`Command + ;` 显示参考线、`Command + '` 显示网格。

## 1.416.0 - 2026-07-10

### Added
- 图片编辑器新增 Image 菜单经典自动校正快捷键：`Shift + Command + L` 自动色阶、`Option + Shift + Command + L` 自动对比度、`Shift + Command + B` 自动颜色。

## 1.415.0 - 2026-07-10

### Added
- 图片编辑器新增 Window 菜单经典面板快捷键：`F5` 显示 Brushes 面板摘要、`F6` 显示 Color 面板摘要。

## 1.414.0 - 2026-07-10

### Added
- 图片编辑器新增 Window 菜单经典面板快捷键：`F7` 聚焦 Layers 面板、`F8` 显示 Info 信息摘要。

## 1.413.0 - 2026-07-10

### Added
- 图片编辑器新增 File 菜单经典快捷键：`Command + O` 打开项目、`Command + S` 保存项目、`Option + Shift + Command + S` 打开导出面板。

## 1.412.0 - 2026-07-10

### Added
- 图片编辑器新增 Layer 菜单经典盖印可见快捷键：`Option + Shift + Command + E` 直接执行 Stamp Visible。

## 1.411.0 - 2026-07-10

### Added
- 图片编辑器新增 Image 菜单经典尺寸快捷键：`Option + Command + I` 调整图像尺寸、`Option + Command + C` 调整画布尺寸。

## 1.410.0 - 2026-07-10

### Added
- 图片编辑器新增 Edit 菜单 `Command + X` 剪切选区：将当前选区复制到剪贴板后清除原图层选区像素，补齐经典 Cut 工作流。

## 1.409.0 - 2026-07-10

### Changed
- 图片编辑器将 `Command + T` 的可见入口调整到 Edit > Free Transform，View 菜单仍保留变换控制框显示开关但不再占用快捷键。

## 1.408.0 - 2026-07-10

### Added
- 图片编辑器在 Edit 菜单中公开 `Delete` 清除选区像素、`Option + Delete` 前景色填充和 `Command + Delete` 背景色填充，补齐经典可见菜单入口。

## 1.407.0 - 2026-07-10

### Changed
- 图片编辑器将 `Command + J` 调整为上下文式经典复制：有选区时通过拷贝创建新图层，没有选区时继续复制当前图层。

## 1.406.0 - 2026-07-10

### Added
- 图片编辑器新增 `Shift + Command + J` 通过剪切创建新图层快捷键，复用现有 Layer via Cut 逻辑补齐经典图层工作流。

## 1.405.0 - 2026-07-10

### Added
- 图片编辑器新增 `Command + T` 变换控制快捷键，复用现有变换框显示逻辑，补齐轻量 Photoshop 风格的快速变换入口。

## 1.404.0 - 2026-07-10

### Added
- 图片编辑器新增 `Option + Delete` 前景色填充选区、`Command + Delete` 背景色填充选区快捷键，贴近 Photoshop 7.0 的经典键盘工作流。

## 1.403.0 - 2026-07-10

### Added
- 图片编辑器新增 `Delete` 清除选区像素快捷键，复用现有选区像素清除逻辑并保留图层锁定保护。

## 1.402.0 - 2026-07-10

### Added
- 图片编辑器新增方向键微移快捷键：方向键按 1 px 移动选区或当前图层，`Shift + 方向键` 按 10 px 大步进移动。

## 1.401.0 - 2026-07-10

### Added
- 图片编辑器新增 `D` / `X` 经典颜色快捷键，可快速恢复默认前景/背景色或交换前景/背景色。

## 1.400.0 - 2026-07-10

### Added
- 图片编辑器新增 `1`...`9` / `0` 数字键不透明度快捷键，按 Photoshop 7.0 习惯快速设置 10%...90% / 100%。

## 1.399.0 - 2026-07-10

### Added
- 图片编辑器新增 `Shift + [` / `Shift + ]` 画笔硬度快捷键，可按 25% 步进调整当前笔触边缘硬度。

## 1.398.0 - 2026-07-10

### Added
- 图片编辑器新增 `[` / `]` 无修饰键快捷键，可按 1 px 步进缩小或放大当前画笔大小，并复用选项栏状态摘要。

## 1.397.0 - 2026-07-10

### Changed
- 图片编辑器工具快捷键改为集中注册，单键选择工具组主工具，Shift+同键在渐变/油漆桶、减淡/加深、矩形/椭圆等共享快捷键工具组内循环，避免多个工具按钮抢占同一快捷键。

## 1.396.0 - 2026-07-10

### Added
- 图片编辑器工具栏补齐移动、选区、画笔、橡皮、仿制图章、减淡/加深、渐变/油漆桶、吸管、文字、形状、钢笔、抓手和缩放等经典 Photoshop 单键工具快捷键。

## 1.395.0 - 2026-07-10

### Added
- 图片编辑器 Layer 菜单补齐新建、复制、编组、取消编组、图层顺序、向下合并和合并可见的经典 Command 快捷键，继续收敛到轻量 Photoshop 7.0 操作习惯。

## 1.394.0 - 2026-07-10

### Added
- 图片编辑器 Edit 与 Select 菜单补齐撤销、重做、复制、粘贴、全选、取消选择、重新选择和反选的经典 Command 快捷键。

## 1.393.0 - 2026-07-10

### Added
- 图片编辑器 View 菜单为放大、缩小、实际像素和适合窗口补齐 Command 快捷键，复用已有缩放能力并贴近经典 Photoshop 操作习惯。

## 1.392.0 - 2026-07-10

### Added
- 图片编辑器 Window 菜单新增状态栏显示/隐藏命令，恢复默认工作区会同步恢复底部状态栏，便于在轻量工作台里按需扩大画布空间。

## 1.391.0 - 2026-07-10

### Added
- 图片编辑器 Window 菜单新增右侧 dock 面板的隐藏/显示命令，并绑定 Shift+Tab，保留工具栏和选项栏以便专注查看画布。

## 1.390.0 - 2026-07-10

### Added
- 图片编辑器 Window 菜单的工作区面板隐藏/显示命令新增 Tab 快捷键，更贴近 Photoshop 7.0 的专注画布操作。

## 1.389.0 - 2026-07-10

### Added
- 图片编辑器 Window 菜单新增“隐藏/显示工作区面板”，可一键收起或恢复工具面板、选项栏和右侧 dock 面板，便于专注查看画布。

## 1.388.0 - 2026-07-10

### Added
- 图片编辑器 Window 菜单新增“恢复默认工作区”，可一键恢复工具面板、选项栏、右侧 dock 面板并回到 Layers 页签，避免隐藏面板后迷失工作台。

## 1.387.0 - 2026-07-10

### Added
- 图片编辑器 Window 菜单新增 Navigator、History、Layers/Channels/Layer Comps 与 Properties 右侧 dock 面板的显示/隐藏控制，默认保持现有面板可见，全部隐藏时自动收起右侧 dock。

## 1.386.0 - 2026-07-10

### Added
- 图片编辑器 Window 菜单新增 Tools 工具面板与 Options 选项栏的显示/隐藏控制，默认保留当前工作台 UI，并可按 Photoshop 7.0 风格临时收起基础面板。

## 1.385.0 - 2026-07-10

### Added
- 图片编辑器 Window 菜单新增 Tools 工具面板和 Options 选项栏入口，复用已有工具切换、选区模式、大小、不透明度和硬度参数。

## 1.384.0 - 2026-07-10

### Added
- 图片编辑器 Window 菜单新增 Styles 样式面板入口，复用已有图层样式复制、粘贴、清除以及描边、投影、发光、叠加、光泽和斜面浮雕开关。

## 1.383.0 - 2026-07-10

### Added
- 图片编辑器 Window 菜单新增 Character 与 Paragraph 面板入口，复用已有文字内容、字号、粗斜体、字距、行距、对齐和文本框宽度设置。

## 1.382.0 - 2026-07-10

### Added
- 图片编辑器 Window 菜单新增 Brushes 画笔面板入口，复用现有画笔类工具、大小、不透明度和硬度状态，并提供基础尺寸预设。

## 1.381.0 - 2026-07-10

### Added
- 图片编辑器 Window 菜单新增 Swatches 色板面板入口，提供默认基础色板并可快速设置前景色或背景色，继续补齐轻量 Photoshop 7.0 面板工作流。

## 1.380.0 - 2026-07-10

### Added
- 图片编辑器 Window 菜单新增 Color 面板入口，复用已有前景/背景色状态，提供显示颜色读数、恢复默认黑白、交换前景/背景和切换吸管。

## 1.379.0 - 2026-07-10

### Added
- 图片编辑器 Window 菜单新增 Info 与 Histogram 面板入口，复用已有坐标、尺寸、颜色和直方图读数，让经典信息面板更容易发现。

## 1.378.0 - 2026-07-10

### Added
- 图片编辑器 Window 菜单新增 Properties 面板动作子菜单，集中暴露调整、调整图层、滤镜图层、智能滤镜和文字入口。

## 1.377.0 - 2026-07-10

### Added
- 图片编辑器 Window 菜单新增 Layers 面板动作子菜单，复用已有新建、复制、删除、编组、向下合并和扁平化图层能力。

## 1.376.0 - 2026-07-10

### Added
- 图片编辑器 Window 菜单新增 Navigator 面板动作子菜单，复用已有缩放、实际像素和适合窗口命令，让基础导航面板入口更符合轻量 Photoshop 7.0 工作流。

## 1.375.0 - 2026-07-10

### Added
- 图片编辑器 Window 菜单新增 Layer Comps 面板动作子菜单，复用已有图层复合保存、应用、更新、复制、删除与前后切换能力。

## 1.374.0 - 2026-07-10

### Added
- 图片编辑器 Window 菜单新增 History 面板动作子菜单，集中暴露已有历史快照与清空历史入口，让轻量 Photoshop 7.0 风格面板工作流更容易发现。

## 1.373.0 - 2026-07-10

### Changed
- 本地化资源测试进一步锁定仅发布简体中文、英文、日文三种语言，并要求每个语言目录只包含已跟踪的 `Localizable.strings` 与 `InfoPlist.strings`。

## 1.372.0 - 2026-07-10

### Added
- 图片编辑器 Window 菜单新增 Channels 面板动作子菜单，集中暴露既有通道预览、从通道载入选区、保存 Alpha 通道和选中 Alpha 常用操作。

## 1.371.0 - 2026-07-10

### Added
- 图片编辑器 Window 菜单新增 Paths 面板动作子菜单，集中暴露既有路径描边、填充、建立选区、转矢量蒙版和转栅格蒙版工作流。

## 1.370.0-rc1 - 2026-07-10

### Fixed
- 图片编辑器 Select 菜单移除重复出现的“保存选区 / 恢复选区”入口，保留经典菜单位置并用范围测试防止回归。

## 1.370.0 - 2026-07-10

### Changed
- 图片编辑器 Select 菜单补齐“保存选区 / 恢复选区”入口，复用既有保存选区状态，让经典 Photoshop 7.0 风格选区管理更容易发现。

## 1.369.0 - 2026-07-10

### Changed
- 图片编辑器 Layer 菜单补齐“通过拷贝新建图层 / 通过剪切新建图层”入口，复用既有选区转图层能力，让 Photoshop 7.0 风格图层工作流更集中。

## 1.368.0 - 2026-07-10

### Added
- 图片编辑器 Image 菜单新增“裁剪到选区 / Crop to Selection”，可按当前选区边界裁剪画布，并复用裁剪流程维护图层、选区、Alpha 通道和参考线坐标。

## 1.367.0 - 2026-07-10

### Added
- 图片编辑器 Image 菜单新增“显示全部 / Reveal All”，可把画布扩展到当前可见图层的完整渲染边界，并同步维护图层、选区、Alpha 通道和参考线坐标。

## 1.366.0 - 2026-07-10

### Added
- 图片编辑器 Image 菜单新增“裁切透明像素 / Trim Transparent Pixels”，可按当前合成图的非透明 alpha 边界自动裁掉透明画布边缘，并复用现有裁剪流程维护图层、选区、Alpha 通道和参考线坐标。

## 1.365.0 - 2026-07-10

### Added
- 图片编辑器 Image 菜单补齐“逆时针旋转 90° / Rotate 90° CCW”和“旋转 180° / Rotate 180°”画布级基础命令，顺时针旋转文案也明确为 90°。

## 1.364.1-rc1 - 2026-07-10

### Fixed
- 图片编辑器 View 菜单的“适合窗口 / Fit on Screen”现在会按当前画布视口执行，并给出明确状态提示；视口尚未可用时不会误改缩放和偏移。

## 1.364.0 - 2026-07-10

### Added
- 图片编辑器 View 菜单和属性面板新增“锁定参考线 / Lock Guides”开关，可防止误拖动已有参考线，并随项目保存恢复。

## 1.363.0 - 2026-07-10

### Added
- 图片编辑器 View 菜单和属性面板新增“显示变换控制框 / Show Transform Controls”开关，可隐藏或恢复所选图层的变换边框、缩放手柄和旋转手柄，并随项目保存恢复。

## 1.362.0 - 2026-07-10

### Added
- 图片编辑器 View 菜单和属性面板新增“显示额外辅助 / Show Extras”总开关，可统一隐藏或恢复参考线、网格和选区边缘等辅助显示，同时保留各自真实状态并随项目保存恢复。

## 1.361.0 - 2026-07-10

### Added
- 图片编辑器 View 菜单和属性面板新增“显示选区边缘”开关，可隐藏或恢复选区蚂蚁线但保留真实选区，并随项目文件保存恢复。

## 1.360.0 - 2026-07-10

### Added
- 图片编辑器 Select 菜单和属性面板新增“重新选择 / Reselect”基础选区命令，取消选区后可快速恢复上一次选区，并增加定向测试覆盖历史、状态和撤销行为。

## 1.359.0 - 2026-07-10

### Added
- 图片编辑器 View 菜单新增“实际像素 / Actual Pixels”基础缩放命令，会根据当前画布视口把图像切到 1:1 显示并复位画布偏移，同时增加定向测试覆盖该轻量 Photoshop 7.0 视图能力。

## 1.358.0 - 2026-07-10

### Changed
- 移除图片编辑器工具栏和本地化资源里已过时的 coming-soon / 后续支持占位路径，所有保留工具都按已实现入口展示，并增加测试防止未完成提示回流。

## 1.357.0 - 2026-07-10

### Added
- 图片编辑器范围测试新增源码级重型入口扫描，防止后续在编辑器源码中重新引入生成式修图、插件、3D、Camera Raw 或精细抠图等扩散方向。

## 1.356.0 - 2026-07-10

### Fixed
- 标注项目文档与 Layer Comp 快照捕获入口的主线程隔离，并把相关测试改为按可见像素和颜色语义校验，清理项目文档 / 图层复合相关 Swift 并发 warning，不改变现有编辑器能力。

## 1.355.0 - 2026-07-10

### Fixed
- 更新区域截图蒙层保存面板和状态监听的 macOS 新版 API 用法，清理相关弃用 warning，不改变现有截图标注 UI 或能力。

## 1.354.0 - 2026-07-10

### Fixed
- 清理图片编辑器项目文档测试中的既有 Swift warning，减少定向测试输出噪音。

## 1.353.0 - 2026-07-10

### Added
- 图片编辑器范围测试新增产品概览校验，确保文档持续声明保留现有能力和 UI、不追求完整 Photopea、不扩展精细 AI 抠图、3D、插件等重型能力。

## 1.352.0 - 2026-07-10

### Added
- 增加图片编辑器能力范围护栏测试，固定当前工具、调整和滤镜集合，避免继续扩展到 3D、插件、生成式修图等重型能力。

### Changed
- 明确轻量 Photoshop 7.0 方向下保留现有能力和 UI 组件，后续重点转向整理、稳定和体验收敛，而不是删减入口或继续扩散功能。

## 1.351.0 - 2026-07-10

### Changed
- 后处理预览的编辑入口移动到预览图右上角浮层，点击后继续打开独立图片编辑器。
- 图片编辑器产品范围收敛为轻量 Photoshop 7.0 风格，不再继续扩展精细抠图、3D、插件等重型 Photopea 能力。

## 1.350.0 - 2026-07-10

### Added
- 选区填充、描边、清除和内容感知填充支持批量处理所选可编辑像素图层，锁定和非像素图层自动跳过，并可一次撤销恢复。

## 1.349.0 - 2026-07-10

### Added
- 文字层和形状层参数更新支持批量处理所选同类型未锁定图层；多选文字层更新时保留各层原文字内容，仅同步样式参数，并可一次撤销恢复。

## 1.348.0 - 2026-07-10

### Added
- 纯色、图案和渐变填充层参数更新支持批量处理所选同类型未锁定图层，并可一次撤销恢复。

## 1.347.0 - 2026-07-10

### Added
- 调整层和滤镜层参数更新支持批量处理所选同类型未锁定图层，并可一次撤销恢复。

## 1.346.0 - 2026-07-10

### Added
- 手动应用调整支持批量处理所选可编辑像素图层：每层独立应用同一调整参数，锁定和不适用图层自动跳过，并可一次撤销恢复。

## 1.345.0 - 2026-07-10

### Added
- Auto Levels、Auto Contrast 和 Auto Color 支持批量处理所选可编辑像素图层，并自动跳过锁定或不适用图层。

## 1.344.0 - 2026-07-10

### Added
- 图层样式复制支持多选场景：以主选中图层作为来源，粘贴时自动排除来源图层并批量应用到其余可编辑图层。
- 补充多选图层样式复制、锁定跳过、来源保留与撤销回归测试；统一版本号到 1.344.0。

## 1.343.0 - 2026-07-10

### Added
- 智能对象替换内容支持批量处理所选智能对象源；同源实例继续同步更新，像素锁定的选中对象不参与目标源集合，并可一次撤销恢复。
- 补充多选智能对象替换内容的多源、锁定跳过、选择保持与撤销回归测试；统一版本号到 1.343.0。

## 1.342.0 - 2026-07-10

### Added
- 智能对象重置变换支持批量处理所选图层：逐层保留中心位置、跳过位置锁定图层，并使用一次撤销恢复整个操作。
- 补充多选智能对象重置变换的锁定跳过、位置保持和撤销回归测试，以及中 / 英 / 日三语反馈文案；统一版本号到 1.342.0。

## 1.341.0 - 2026-07-10

- Layer 面板支持批量让所选仍共享源的智能对象实例独立化，每个目标会获得独立的 sourceID。
- 批量独立化会自动跳过已独立、被像素锁锁定或不适用图层，保留原多选集合，并支持一次撤销恢复。
- 补充多选智能对象实例独立化回归测试和中 / 英 / 日三语反馈文案；统一前后端版本号到 1.341.0。

## 1.340.0 - 2026-07-10

- Layer > Mask、图层面板和 Select 菜单支持从多个所选图层透明度同时载入选区，并在画布空间合成为并集。
- 载入结果继续遵循当前选区的替换、添加、减去和相交模式，并支持一次撤销恢复。
- 补充多选图层透明度载入并集选区回归测试和中 / 英 / 日三语反馈文案；统一前后端版本号到 1.340.0。

## 1.339.0 - 2026-07-10

- Layer > Mask 和图层面板支持从多个所选闭合矢量蒙版同时载入选区，并在画布空间合成为并集。
- 载入结果继续遵循当前选区的替换、添加、减去和相交模式，并支持一次撤销恢复。
- 补充多选矢量蒙版载入并集选区回归测试和中 / 英 / 日三语反馈文案；统一前后端版本号到 1.339.0。

## 1.338.0 - 2026-07-10

- Layer > Mask 和图层面板支持从多个所选栅格图层蒙版同时载入选区，并在画布空间合成为并集。
- 载入结果继续遵循当前选区的替换、添加、减去和相交模式，并支持一次撤销恢复。
- 补充多选图层蒙版载入并集选区回归测试和中 / 英 / 日三语反馈文案；统一前后端版本号到 1.338.0。

## 1.337.0 - 2026-07-10

- Layer > Mask 和图层面板支持将当前非反相几何选区批量创建为多选图层的闭合矢量蒙版。
- 批量创建会自动跳过锁定、已有矢量蒙版或无法转换当前选区的图层，保留原多选集合，并支持一次撤销恢复。
- 补充多选从选区创建矢量蒙版回归测试和中 / 英 / 日三语反馈文案；统一前后端版本号到 1.337.0。

## 1.336.0 - 2026-07-10

- Layer > Mask 和图层面板支持将当前选区批量创建为显示选区或隐藏选区的栅格蒙版。
- 批量创建会自动跳过锁定、已有栅格蒙版或无法映射当前选区的图层，保留原多选集合，并支持一次撤销恢复。
- 补充多选从选区创建显示 / 隐藏蒙版回归测试和中 / 英 / 日三语反馈文案；统一前后端版本号到 1.336.0。

## 1.335.0 - 2026-07-10

- Layer > Mask 和图层面板的添加图层蒙版、添加隐藏全部蒙版命令支持多选图层，可一次性创建白色或全黑栅格蒙版。
- 批量创建会自动跳过锁定或已有栅格蒙版图层，保留同层矢量蒙版和原多选集合，并支持一次撤销恢复。
- 补充多选创建普通与隐藏全部蒙版回归测试和中 / 英 / 日三语反馈文案；统一前后端版本号到 1.335.0。

## 1.334.0 - 2026-07-10

- Layer > Mask 和图层面板可将当前选区批量显示到、从中隐藏或与之相交到多选图层的栅格蒙版。
- 批量合成会自动跳过锁定、无蒙版或无法映射当前选区的图层，保留原多选集合，并支持一次撤销恢复。
- 补充多选蒙版显示选区回归测试和中 / 英 / 日三语反馈文案；统一前后端版本号到 1.334.0。

## 1.333.0 - 2026-07-10

- Layer > Mask 和图层面板的栅格化矢量蒙版命令支持多选图层，可一次性将多个已启用的闭合路径蒙版转换成图层蒙版。
- 批量栅格化会自动跳过锁定、未启用、非闭合或无效路径蒙版图层，保留原多选集合，并支持一次撤销恢复。
- 补充多选栅格化矢量蒙版回归测试和中 / 英 / 日三语反馈文案；统一前后端版本号到 1.333.0。

## 1.332.0 - 2026-07-10

- Layer > Mask 和图层面板的删除矢量蒙版命令支持多选图层，可一次性删除多个矢量路径蒙版。
- 批量删除会自动跳过锁定或无矢量蒙版图层，保留同层栅格蒙版和原多选集合，并支持一次撤销恢复。
- 补充多选删除矢量蒙版回归测试和中 / 英 / 日三语反馈文案；统一前后端版本号到 1.332.0。

## 1.331.0 - 2026-07-10

- Layer > Mask 和图层面板的矢量蒙版启用 / 停用命令支持多选图层；有已启用项时统一停用，全部停用后可统一启用。
- 批量开关会自动跳过锁定或无矢量蒙版图层，保留原多选集合，并支持一次撤销恢复。
- 补充多选切换矢量蒙版启停回归测试和中 / 英 / 日三语反馈文案；统一前后端版本号到 1.331.0。

## 1.330.0 - 2026-07-10

- Layer > Mask 和图层面板的链接 / 取消链接蒙版命令支持多选图层，栅格蒙版和矢量蒙版可统一链接或取消链接。
- 批量开关会自动跳过锁定或无蒙版图层，保留原多选集合，并支持一次撤销恢复。
- 补充栅格与矢量蒙版混合多选的链接状态回归测试和中 / 英 / 日三语反馈文案；统一前后端版本号到 1.330.0。

## 1.329.0 - 2026-07-10

- Layer > Mask 和图层面板的启用 / 停用图层蒙版命令支持多选图层；有已启用项时统一停用，全部停用后可统一启用。
- 批量开关会自动跳过锁定或无栅格蒙版图层，保留原多选集合，并支持一次撤销恢复。
- 补充多选切换图层蒙版启停回归测试和中 / 英 / 日三语反馈文案；统一前后端版本号到 1.329.0。

## 1.328.0 - 2026-07-10

- Layer > Mask 和图层面板的反相图层蒙版命令支持多选图层，可一次性反转多个栅格图层蒙版。
- 批量反相会自动跳过锁定、无蒙版或无法转换的图层，保留矢量蒙版和原多选集合，并支持一次撤销恢复。
- 补充多选反相图层蒙版回归测试和中 / 英 / 日三语反馈文案；统一前后端版本号到 1.328.0。

## 1.327.0 - 2026-07-10

- Layer > Mask 和图层面板的删除图层蒙版命令支持多选图层，可一次性删除多个栅格图层蒙版。
- 批量删除会自动跳过锁定或无栅格蒙版图层，保留矢量蒙版和原多选集合，并支持一次撤销恢复。
- 补充多选删除图层蒙版回归测试和中 / 英 / 日三语反馈文案；统一前后端版本号到 1.327.0。

## 1.326.0 - 2026-07-10

- Layer > Mask 和图层面板的应用图层蒙版命令支持多选图层，可一次性把多个可编辑图层的栅格 / 矢量蒙版烘焙进图层内容。
- 多选应用蒙版会自动跳过锁定、图层组、调整层、滤镜层和无蒙版图层，并保持原多选集合与主选图层。
- 补充多选应用图层蒙版回归测试和中 / 英 / 日三语文案；统一前后端版本号到 1.326.0。

## 1.325.0 - 2026-07-10

- Layer 菜单和图层面板的栅格化命令支持多选图层，可一次性烘焙文字、形状、智能对象、智能滤镜、蒙版和图层样式。
- 多选栅格化会自动跳过锁定、图层组、调整层、滤镜层、剪贴图层和不可栅格化图层，并保持原多选集合与主选图层。
- 补充多选栅格化回归测试和中 / 英 / 日三语文案；统一前后端版本号到 1.325.0。

## 1.324.0 - 2026-07-10

- 从图层透明度载入选区支持图层组，会按所选组内可见后代的合成透明度生成 raster selection。
- 图层组透明度选区复用现有替换 / 添加 / 减去 / 相交模式，并保留组不透明度、组蒙版和嵌套组的合成语义。
- 增加图层组透明度载入选区回归测试；统一前后端版本号到 1.324.0。

## 1.323.0 - 2026-07-10

- Layer > Mask 和图层面板新增从当前图层透明度载入选区，可直接把图层缩略图的可见轮廓转换为 raster selection。
- 从图层透明度载入选区复用替换 / 添加 / 减去 / 相交选区模式，并支持剪贴图层使用裁剪后的透明度结果。
- 补齐中 / 英 / 日三语文案与透明度载入选区回归测试；统一前后端版本号到 1.323.0。

## 1.322.0 - 2026-07-10

- Layer > Align 和图层面板新增对齐到当前选区六向命令，可用选区边界作为局部对齐目标定位单个图层、多选图层或图层组后代。
- 对齐到选区会裁切选区边界到画布范围内，并在无选区、锁定或不可变换图层时给出状态提示。
- 补齐中 / 英 / 日三语文案与对齐到选区回归测试；统一前后端版本号到 1.322.0。

## 1.321.0 - 2026-07-10

- Layer > Align 和图层面板新增水平 / 垂直间距均分命令，可让三个及以上选中图层在当前联合边界内获得相等空隙。
- 间距均分会保持首尾图层不动，只重新定位中间图层，并复用现有多选、链接图层和图层组后代的可变换筛选逻辑。
- 补齐中 / 英 / 日三语文案与间距均分回归测试；统一前后端版本号到 1.321.0。

## 1.320.0 - 2026-07-10

- Layer > Align 和图层面板新增“对齐到画布”六向命令，单个图层、多选图层和选中图层组后代都可按画布边缘或中心轴定位。
- 画布对齐复用现有可变换图层筛选逻辑，会跳过锁定、不可见、调整层和滤镜层，并写入 History、状态栏与撤销链路。
- 补齐中 / 英 / 日三语文案与画布对齐回归测试；统一前后端版本号到 1.320.0。

## 1.319.0 - 2026-07-10

- Select > Transform 新增水平居中、垂直居中和居中到画布命令，可把当前矩形、套索、魔棒或通道选区快速对齐到画布中心轴。
- 属性面板同步提供选区居中快捷按钮，居中操作会复用现有选区平移管线并写入 History 与撤销。
- 补齐中 / 英 / 日三语文案与选区居中回归测试；统一前后端版本号到 1.319.0。

## 1.318.0 - 2026-07-10

- 导出面板新增“所选图层”范围，可把当前多选图层或图层组后代按现有合成规则导出为一张透明资产图。
- 所选图层导出会跳过未选图层，并复用现有图层效果、剪贴蒙版、组透明度、混合模式和可见性合成规则。
- 补齐中 / 英 / 日三语文案与导出所选图层回归测试；统一前后端版本号到 1.318.0。

## 1.317.0 - 2026-07-10

- Layer 菜单和图层面板新增“盖印所选图层”，可把当前多选图层或图层组后代合成为新的普通像素层，同时保留原图层栈。
- 盖印所选图层会跳过未参与合成的隐藏内容，并把新图层插入到所选图层上方或同组上下文中，方便继续试滤镜、蒙版和混合模式。
- 补齐中 / 英 / 日三语文案与盖印所选图层回归测试；统一前后端版本号到 1.317.0。

## 1.316.0 - 2026-07-10

- 将工程本地化区域约束为简体中文、英文和日文三语，移除 Xcode 项目里的 Base 区域声明，避免继续维护额外语言入口。
- 新增本地化资源回归测试，校验 `.lproj` 目录只能包含三语，并确保 Localizable 与 InfoPlist 三套文案 key 保持一致。
- 统一前后端版本号到 1.316.0。

## 1.315.0 - 2026-07-10

- 智能滤镜的添加、更新最后一项和清空操作支持批量应用到多选可编辑图层，便于统一叠加非破坏式滤镜栈。
- 批量智能滤镜操作会跳过锁定图层、图层组、调整层和滤镜层，单项启用、排序、更新和删除仍针对主选图层的具体滤镜。
- 补充多选智能滤镜回归测试；统一前后端版本号到 1.315.0。

## 1.314.0 - 2026-07-10

- 复制多选图层时会保留副本集合内部的图层链接关系，方便复制后继续整体移动、对齐或分布。
- 单独复制一个已链接图层时，新副本会断开指向原图层集合的链接，避免新旧图层误绑在一起。
- 补充图层复制链接关系回归测试；统一前后端版本号到 1.314.0。

## 1.313.0 - 2026-07-10

- 图层样式开关与参数编辑支持批量应用到多选图层，Stroke、Shadow、Glow、Overlay、Satin 和 Bevel 等样式可统一调整。
- 批量图层样式编辑会跳过锁定、图层组、调整层和滤镜层，菜单启用状态也会识别多选集合中的可编辑图层。
- 补充多选图层样式回归测试；统一前后端版本号到 1.313.0。

## 1.312.0 - 2026-07-10

- 图层蒙版 Density 与 Feather 控制支持批量应用到多选图层，便于统一柔化或降低多个图层蒙版强度。
- 多选蒙版属性编辑会自动跳过锁定图层和无蒙版图层，面板显示与启用状态也会识别多选集合中的可编辑蒙版。
- 补充多选蒙版属性回归测试；统一前后端版本号到 1.312.0。

## 1.311.0 - 2026-07-10

- 图层面板 Blend If 当前图层与下方图层四个阈值支持批量应用到多选图层，继续补齐复杂图层的高级混合工作流。
- Blend If 批量编辑会跳过锁定、图层组和不适用图层，并按每个目标图层自身黑白端点约束进行夹取。
- 补充多选 Blend If 回归测试；统一前后端版本号到 1.311.0。

## 1.310.0 - 2026-07-10

- 图层面板的透明度、填充透明度和混合模式控制支持批量作用到当前多选图层，更贴近 Photoshop / Photopea 的多选图层编辑语义。
- 批量外观编辑会跳过锁定或不适用图层，并限制 Pass Through 只应用到图层组，避免普通图层误进入组混合模式。
- 新增独立多选图层外观回归测试；统一前后端版本号到 1.310.0。

## 1.309.0 - 2026-07-10

- Layer 菜单和图层面板支持批量显示 / 隐藏所选图层，补齐复杂图层栈中快速开关局部图层的基础工作流。
- 批量显隐会保留当前多选集合、写入 History，并支持撤销恢复上一轮可见性状态。
- 补齐中 / 英 / 日三语文案与所选图层批量显隐回归测试；统一前后端版本号到 1.309.0。

## 1.308.0 - 2026-07-10

- Alpha 通道支持直接生成普通灰阶像素图层，便于把保存通道作为素材继续混合、滤镜或导出。
- 通道面板和 Select > Alpha Channels 菜单新增从选中 Alpha 通道创建图层入口，并自动选中新图层。
- 补齐中 / 英 / 日三语文案与 Alpha 通道转图层回归测试；统一前后端版本号到 1.308.0。

## 1.307.0 - 2026-07-10

- 通道面板和 Select > Alpha Channels 菜单支持把当前图层透明度保存为 Alpha 通道。
- 图层透明度保存会按画布坐标生成 Alpha mask，自动选中并预览新通道，空透明图层会给出失败提示。
- 补齐中 / 英 / 日三语文案与图层透明度保存 Alpha 通道回归测试；统一前后端版本号到 1.307.0。

## 1.306.0 - 2026-07-10

- Alpha 通道支持一键填满白色或清空为黑色，保留通道尺寸与名称并进入撤销 / 历史记录。
- 通道面板和 Select > Alpha Channels 菜单新增填白、清空入口，便于快速重置或建立全选 mask。
- 补齐中 / 英 / 日三语文案与 Alpha 通道填白 / 清空回归测试；统一前后端版本号到 1.306.0。

## 1.305.0 - 2026-07-10

- Alpha 通道支持直接新建空白通道，生成全黑 mask 并自动进入通道预览。
- 通道面板和 Select > Alpha Channels 菜单新增空白 Alpha 通道入口，便于后续用选区合成逐步构造通道。
- 补齐中 / 英 / 日三语文案与空白 Alpha 通道回归测试；统一前后端版本号到 1.305.0。

## 1.304.0 - 2026-07-10

- Alpha 通道支持把当前选区添加到保存通道、从保存通道减去选区、以及与当前选区相交。
- 通道面板和 Select > Alpha Channels 菜单新增三种选区合成入口，并进入撤销与历史记录。
- 补齐中 / 英 / 日三语文案与 Alpha 通道选区合成回归测试；统一前后端版本号到 1.304.0。

## 1.303.0 - 2026-07-10

- Alpha 通道支持适配到画布，可将保存 mask 的有效边界缩放到整张通道画布。
- 通道面板和 Select > Alpha Channels 菜单都新增适配画布入口，并进入撤销与历史记录。
- 补齐中 / 英 / 日三语文案与 Alpha 通道适配画布回归测试；统一前后端版本号到 1.303.0。

## 1.302.0 - 2026-07-10

- Alpha 通道支持按当前选区修改数量向左 / 右 / 上 / 下平移，可从通道面板或 Select > Alpha Channels 菜单操作。
- 平移 Alpha 通道会进入撤销与历史记录，并在状态栏显示通道名称与 X / Y 位移。
- 补齐中 / 英 / 日三语文案与 Alpha 通道平移回归测试；统一前后端版本号到 1.302.0。

## 1.301.0 - 2026-07-10

- Alpha 通道支持 200% 放大与 50% 缩小，可围绕保存 mask 的自身边界缩放通道内容。
- 通道面板和 Select > Alpha Channels 菜单都新增缩放选中 Alpha 通道入口，并进入撤销与历史记录。
- 补齐中 / 英 / 日三语文案与 Alpha 通道缩放回归测试；统一前后端版本号到 1.301.0。

## 1.300.0 - 2026-07-10

- Alpha 通道支持 180° 旋转，补齐保存通道的基础旋转操作组合。
- 通道面板和 Select > Alpha Channels 菜单都新增旋转选中 Alpha 通道 180° 入口，并进入撤销与历史记录。
- 补齐中 / 英 / 日三语文案与 Alpha 通道 180° 旋转回归测试；统一前后端版本号到 1.300.0。

## 1.299.0 - 2026-07-10

- Alpha 通道支持顺 / 逆时针 90° 旋转，可在保存的 mask 边界内旋转通道形状。
- 通道面板和 Select > Alpha Channels 菜单都新增旋转选中 Alpha 通道入口，并进入撤销与历史记录。
- 补齐中 / 英 / 日三语文案与 Alpha 通道旋转回归测试；统一前后端版本号到 1.299.0。

## 1.298.0 - 2026-07-10

- Alpha 通道支持水平 / 垂直翻转，可在保存的 mask 边界内镜像通道内容。
- 通道面板和 Select > Alpha Channels 菜单都新增翻转选中 Alpha 通道入口，并进入撤销与历史记录。
- 补齐中 / 英 / 日三语文案与 Alpha 通道翻转回归测试；统一前后端版本号到 1.298.0。

## 1.297.0 - 2026-07-10

- Alpha 通道支持删除小斑点，可按当前选区修改数值清理不超过指定面积的孤立 mask 块。
- 通道面板和 Select > Alpha Channels 菜单都新增删除选中 Alpha 通道小斑点入口，并进入撤销与历史记录。
- 补齐中 / 英 / 日三语文案与 Alpha 通道去斑点回归测试；统一前后端版本号到 1.297.0。

## 1.296.0 - 2026-07-10

- Alpha 通道支持填充孔洞，可把完全包围的黑色空洞补成白色 mask。
- 通道面板和 Select > Alpha Channels 菜单都新增填充选中 Alpha 通道孔洞入口，并进入撤销与历史记录。
- 补齐中 / 英 / 日三语文案与 Alpha 通道填洞回归测试；统一前后端版本号到 1.296.0。

## 1.295.0 - 2026-07-10

- Alpha 通道支持按当前选区修改半径执行平滑，可清理通道 mask 中的孤立噪点和小毛刺。
- 通道面板和 Select > Alpha Channels 菜单都新增平滑选中 Alpha 通道入口，并进入撤销与历史记录。
- 补齐中 / 英 / 日三语文案与 Alpha 通道平滑回归测试；统一前后端版本号到 1.295.0。

## 1.294.0 - 2026-07-10

- Alpha 通道支持按当前选区修改半径执行扩展和收缩，可直接调整保存通道的硬边 mask 范围。
- 通道面板和 Select > Alpha Channels 菜单都新增扩展 / 收缩选中 Alpha 通道入口，并进入撤销与历史记录。
- 补齐中 / 英 / 日三语文案与 Alpha 通道扩展 / 收缩回归测试；统一前后端版本号到 1.294.0。

## 1.293.0 - 2026-07-10

- 通道面板可将组合、红、绿、蓝或 Alpha 预览通道直接保存为可编辑 Alpha 通道。
- Select > Alpha Channels 菜单新增保存当前预览通道入口，保存后的通道可继续反相、阈值化、羽化、载入选区或应用为图层蒙版。
- 补齐中 / 英 / 日三语文案与当前通道保存为 Alpha 通道回归测试；统一前后端版本号到 1.293.0。

## 1.292.0 - 2026-07-10

- Alpha 通道支持羽化命令，可复用当前选区修改半径把硬边 mask 柔化为半透明边缘。
- 通道面板和 Select > Alpha Channels 菜单都可对当前保存的 Alpha 通道执行羽化，并进入撤销与历史记录。
- 补齐中 / 英 / 日三语文案与 Alpha 通道羽化回归测试；统一前后端版本号到 1.292.0。

## 1.291.0 - 2026-07-10

- Alpha 通道支持阈值化命令，可把灰阶 mask 一键压成黑白硬边通道。
- 通道面板和 Select > Alpha Channels 菜单都可对当前保存的 Alpha 通道执行阈值化，并进入撤销与历史记录。
- 补齐中 / 英 / 日三语文案与 Alpha 通道阈值化回归测试；统一前后端版本号到 1.291.0。

## 1.290.0 - 2026-07-10

- Alpha 通道支持反相命令，可在通道面板或 Select > Alpha Channels 菜单中直接反转当前保存的 mask。
- 反相会进入撤销与历史记录，并保持当前 Alpha 通道选中态，便于继续载入选区、应用到图层蒙版或主画布预览。
- 补齐中 / 英 / 日三语文案与 Alpha 通道反相回归测试；统一前后端版本号到 1.290.0。

## 1.289.0 - 2026-07-10

- 已保存 Alpha 通道可作为主画布灰阶预览目标，通道面板选择 Alpha 通道时会像 Photoshop Channels 面板一样显示对应 mask。
- 切回组合 / RGB / 单色通道时会自动退出已保存 Alpha 通道预览，避免通道选中态和画布预览状态混淆。
- 补齐中 / 英 / 日三语文案与已保存 Alpha 通道主画布预览回归测试；统一前后端版本号到 1.289.0。

## 1.288.0 - 2026-07-10

- Select 菜单新增 Alpha 通道子菜单，可保存选区 / 图层蒙版为 Alpha 通道，并对当前选中 Alpha 通道执行载入、更新、应用到图层蒙版、复制、删除和前后导航。
- 通道面板新增当前 Alpha 通道选中态，保存、复制、重命名、更新、载入、应用和删除操作会同步当前通道。
- 补齐中 / 英 / 日三语文案与当前 Alpha 通道菜单命令回归测试；统一前后端版本号到 1.288.0。

## 1.287.0 - 2026-07-10

- Edit 菜单新增历史快照子菜单，可创建、恢复、复制、删除当前选中的历史快照。
- 历史快照面板新增选中态与前后快照导航，让快照可像 Photoshop History 面板一样作为明确操作对象。
- 补齐中 / 英 / 日三语文案与历史快照菜单命令回归测试；统一前后端版本号到 1.287.0。

## 1.286.0 - 2026-07-10

- Layer 菜单新增图层复合子菜单，可直接保存、应用、更新、复制、删除当前选中的图层复合。
- 图层复合支持上一个 / 下一个导航和复制命名去重，复杂视觉方案可从菜单快速切换与派生。
- 补齐中 / 英 / 日三语文案与图层复合菜单命令回归测试；统一前后端版本号到 1.286.0。

## 1.285.0 - 2026-07-10

- Layer 菜单新增选择父级图层组入口，可从组内图层快速跳回直接父组。
- 父级组选择会同步多选属性面板状态，并在状态栏显示被选中的父组名称。
- 补齐中 / 英 / 日三语文案与父组 / 组成员双向选择回归测试；统一前后端版本号到 1.285.0。

## 1.284.0 - 2026-07-10

- Layer 菜单新增选择组内图层入口，可从选中的图层组直接选中全部后代成员。
- 选择组内图层成功后会显示选中成员数量，并同步多选属性面板状态。
- 补齐中 / 英 / 日三语状态文案与图层组成员选择回归测试；统一前后端版本号到 1.284.0。

## 1.283.0 - 2026-07-10

- Layer 菜单新增按属性选择子菜单，可直接选择带蒙版、带图层样式、剪贴蒙版和带智能滤镜图层。
- 属性选择复用图层面板的属性过滤规则，确保菜单选择和面板筛选在复杂图层稿中保持一致。
- 补齐中 / 英 / 日三语文案与属性选择回归测试；统一前后端版本号到 1.283.0。

## 1.282.0 - 2026-07-10

- Layer 菜单新增选择锁定图层和选择未锁定图层命令，可按有效锁定状态快速建立批量操作目标。
- 锁定图层选择会考虑父级图层组的锁定继承，父组锁定时子图层会被视为有效锁定。
- 补齐中 / 英 / 日三语文案与有效锁定回归测试；统一前后端版本号到 1.282.0。

## 1.281.0 - 2026-07-10

- Layer 菜单新增选择可见图层和选择隐藏图层命令，按图层自身与父组共同决定的有效可见性批量建立图层选择。
- 可见 / 隐藏选择接入多选状态同步、状态提示和菜单禁用逻辑，与图层面板状态筛选保持同一可见性语义。
- 补齐中 / 英 / 日三语文案与有效可见性回归测试；统一前后端版本号到 1.281.0。

## 1.280.0 - 2026-07-10

- Layer 菜单新增选择相似图层命令，可按主选图层的图层类型、混合模式和颜色标签组合匹配相似图层。
- 相似图层选择与现有同类、同混合模式、同色标签选择共用多选状态同步，便于在复杂图层稿里快速圈定同一设计策略的图层。
- 补齐中 / 英 / 日三语文案与组合选择回归测试；统一前后端版本号到 1.280.0。

## 1.279.0 - 2026-07-10

- Layer 菜单新增选择相同混合模式图层，可基于主选图层快速选中同为 Normal、Multiply、Screen 等混合模式的图层。
- 同混合模式选择接入多选状态、状态提示和菜单禁用逻辑，便于复杂图层稿中批量定位同类合成策略图层。
- 补齐中 / 英 / 日三语文案与图层选择回归测试；统一前后端版本号到 1.279.0。

## 1.278.0 - 2026-07-10

- Layer 菜单新增选择同类图层与选择同色标签图层命令，可基于主选图层快速扩展当前图层选择。
- 同类选择复用现有图层类型分类，覆盖像素、文字、形状、调整、滤镜、填充、智能对象和图层组，便于复杂图层稿批量管理。
- 补齐中 / 英 / 日三语文案与图层选择回归测试；统一前后端版本号到 1.278.0。

## 1.277.0 - 2026-07-10

- 滤镜层与智能滤镜栈新增 Spherize / 球面化滤镜，可用正负 Amount 做圆形影响半径内的球面凸出或反向凹陷。
- Spherize 参数接入属性面板、智能滤镜摘要和项目保存恢复，继续补齐 Photoshop Distort 类滤镜能力。
- 补齐中 / 英 / 日三语文案与 Spherize 非破坏回归测试；统一前后端版本号到 1.277.0。

## 1.276.0 - 2026-07-10

- 滤镜层与智能滤镜栈新增 Pinch / 挤压滤镜，可用正负 Amount 做整张画布的中心径向挤压或反向膨胀。
- Pinch 参数接入属性面板、智能滤镜摘要和项目保存恢复，继续扩展 Photoshop Distort 类滤镜族。
- 补齐中 / 英 / 日三语文案与 Pinch 非破坏回归测试；统一前后端版本号到 1.276.0。

## 1.275.0 - 2026-07-10

- 滤镜层与智能滤镜栈新增 Ripple / 波纹滤镜，可按 Amount 与 Frequency 生成以画布中心为圆心的径向正弦波纹扭曲。
- Ripple 参数接入属性面板、智能滤镜摘要和项目保存恢复，继续补齐 Photoshop Distort 类滤镜能力。
- 补齐中 / 英 / 日三语文案与 Ripple 非破坏回归测试；统一前后端版本号到 1.275.0。

## 1.274.0 - 2026-07-10

- 滤镜层与智能滤镜栈新增 Offset / 位移滤镜，可按 X/Y 参数循环包裹移动图像内容，便于检查边缘和制作无缝纹理。
- Offset 参数接入属性面板、智能滤镜摘要和项目保存恢复，旧项目缺少新增参数时使用默认水平位移兼容载入。
- 补齐中 / 英 / 日三语文案与 Offset 非破坏回归测试；统一前后端版本号到 1.274.0。

## 1.273.0 - 2026-07-10

- 滤镜层与智能滤镜栈新增 Wave / 波浪畸变，可按行生成正弦水平位移，并提供振幅与频率参数。
- Wave 参数接入属性面板、智能滤镜摘要和项目保存恢复，旧项目缺少新增参数时使用默认波形兼容载入。
- 补齐中 / 英 / 日三语文案与 Wave 回归测试；统一前后端版本号到 1.273.0。

## 1.272.0 - 2026-07-10

- 滤镜层与智能滤镜栈新增 Liquify Pucker/Bloat / 液化收缩/膨胀，可用正负 Amount 对画面中心区域做距离衰减径向膨胀或收缩。
- Liquify Pucker/Bloat 参数接入属性面板、智能滤镜摘要和项目保存恢复，旧项目缺少新增参数时继续使用默认膨胀值兼容载入。
- 补齐中 / 英 / 日三语文案与 Liquify Pucker/Bloat 回归测试；统一前后端版本号到 1.272.0。

## 1.271.0 - 2026-07-10

- 滤镜层与智能滤镜栈新增 Liquify Twirl / 液化旋转，可按旋转方向和强度对画面中心区域做距离衰减扭转变形。
- Liquify Twirl 参数接入属性面板、智能滤镜摘要和项目保存恢复，继续扩展 Liquify 工具族。
- 补齐中 / 英 / 日三语文案与 Liquify Twirl 回归测试；统一前后端版本号到 1.271.0。

## 1.270.0 - 2026-07-10

- 滤镜层与智能滤镜栈新增 Liquify Push / 液化推移，可按水平 / 垂直方向和强度对画面中心区域做距离衰减推移变形。
- Liquify Push 参数接入属性面板、智能滤镜摘要和项目保存恢复，便于后续扩展为完整 Liquify 工作区。
- 补齐中 / 英 / 日三语文案与 Liquify Push 回归测试；统一前后端版本号到 1.270.0。

## 1.269.0 - 2026-07-10

- Gradient Map / 渐变映射新增 Dither / 抖动开关，可用稳定 Bayer 抖动减少渐变映射色带，并随调整层保存恢复。
- 修复 Vibrance / 自然饱和度双参数缺少项目编码的问题，保存 `.qpicproject` 时会写入 Vibrance 与 Saturation 字段。
- 补齐中 / 英 / 日三语文案与 Gradient Map Dither、Vibrance 编码回归测试；统一前后端版本号到 1.269.0。

## 1.268.0 - 2026-07-10

- 工具栏新增 Patch Tool / 修补工具，可拖拽当前选区到取样位置，并按选区 mask 与不透明度把同图层样本区域融合回原选区。
- Patch Tool 接入撤销、历史、状态提示和透明像素锁；锁定透明像素时不会把原本透明区域填实。
- 补齐 Patch Tool 回归测试；统一前后端版本号到 1.268.0。

## 1.267.0 - 2026-07-10

- Vibrance / 自然饱和度调整新增独立 Vibrance 与 Saturation 双滑块，像 Photoshop 面板一样可分别增强低饱和颜色和整体饱和度。
- Vibrance 双参数接入像素应用、非破坏调整层、图层摘要和项目保存恢复；旧项目缺少字段时继续按原 `adjustmentValue` 强度渲染。
- 补齐中 / 英 / 日三语文案与 Vibrance 双参数回归测试；统一前后端版本号到 1.267.0。

## 1.266.0 - 2026-07-10

- Edit 菜单和选区属性面板新增 Content-Aware Fill / 内容感知填充，可对当前选区内像素从同图层选区外邻近像素进行确定性距离加权重建。
- 内容感知填充接入撤销、历史、状态提示和透明像素锁；锁定透明像素时不会把原本透明区域填实。
- 图层样式的 Satin / 光泽新增 Color / 颜色、Invert / 反相和 Contour / 等高线控制，可更接近 Photoshop 光泽样式的色带塑形能力。
- Satin 参数接入属性面板、渲染和 `.qpicproject` 保存恢复；旧项目缺少字段时默认保持不反相与 Linear 等高线兼容。
- 补齐中 / 英 / 日三语文案与内容感知填充、Satin 高级参数回归测试；统一前后端版本号到 1.266.0。

## 1.265.0 - 2026-07-10

- 图层样式的 Bevel / 斜面浮雕新增 Soften / 柔化控制，可对斜面高光与阴影结果进行半径柔化。
- 图层样式的 Drop Shadow / 投影、Inner Shadow / 内阴影和 Outer Glow / 外发光新增 Contour / 等高线控制，支持 Linear、Soft、Steep、Cone、Ring 五种 alpha 衰减曲线。
- 斜面柔化与效果等高线接入属性面板、渲染和 `.qpicproject` 保存恢复，旧项目缺少字段时默认保持 0 px 柔化和 Linear 等高线兼容。
- 补齐中 / 英 / 日三语文案与斜面柔化、效果等高线回归测试；统一前后端版本号到 1.265.0。

## 1.264.0 - 2026-07-10

- 图层样式的 Bevel / 斜面浮雕新增 Direction / 方向控制，可在 Up / 上和 Down / 下之间切换高光与阴影方向。
- 图层样式的 Inner Shadow / 内阴影新增 Choke / 阻塞与 Noise / 噪点控制，可在模糊前扩张内阴影 alpha，并生成稳定颗粒内阴影。
- 斜面方向与内阴影阻塞、噪点接入属性面板、渲染和 `.qpicproject` 保存恢复，旧项目缺少字段时默认保持 Up、0 px 阻塞和 0% 噪点兼容。
- 补齐中 / 英 / 日三语文案与斜面方向、内阴影阻塞、噪点回归测试；统一前后端版本号到 1.264.0。

## 1.263.0 - 2026-07-10

- 图层样式的 Inner Glow / 内发光新增 Noise / 噪点控制，可在内发光模糊和阻塞合成前生成稳定颗粒 alpha。
- Inner Glow 新增 Source / 来源选择，可在 Edge / 边缘和 Center / 中心发光之间切换。
- 内发光噪点与来源接入属性面板、渲染和 `.qpicproject` 保存恢复，旧项目缺少字段时默认保持 0% 噪点与边缘来源兼容。
- 补齐中 / 英 / 日三语文案与内发光噪点、来源回归测试；统一前后端版本号到 1.263.0。

## 1.262.0 - 2026-07-10

- 图层样式的 Outer Glow / 外发光新增 Noise / 噪点控制，可在模糊与扩展前生成稳定颗粒 alpha，制作更粗糙的发光边缘。
- 外发光噪点接入属性面板、渲染和 `.qpicproject` 保存恢复，旧项目缺少字段时默认保持 0% 噪点兼容。
- 补齐中 / 英 / 日三语文案与外发光噪点回归测试；统一前后端版本号到 1.262.0。

## 1.261.0 - 2026-07-10

- 图层样式的 Gradient Overlay / 渐变叠加新增 Scale / 缩放控制，可调整 Linear、Radial、Reflected、Diamond 渐变覆盖尺度。
- Stroke / 描边样式新增 Color、Gradient、Pattern 三种填充类型，可使用渐变样式、渐变角度、图案类型和图案缩放控制描边外观。
- 渐变叠加缩放与描边填充类型接入属性面板和 `.qpicproject` 保存恢复，旧项目缺少新增字段时保持原有颜色描边和 100% 渐变叠加兼容。
- 补齐中 / 英 / 日三语文案与渐变叠加缩放、描边填充类型回归测试；统一前后端版本号到 1.261.0。

## 1.260.0 - 2026-07-10

- 图层样式的 Gradient Overlay / 渐变叠加新增 Linear、Radial、Reflected、Diamond 样式选择，复用渐变填充层的样式渲染能力。
- 渐变叠加样式接入属性面板和 `.qpicproject` 保存恢复，旧项目缺少样式字段时默认保持 Linear 兼容。
- 补齐中 / 英 / 日三语文案与渐变叠加样式回归测试；统一前后端版本号到 1.260.0。

## 1.259.0 - 2026-07-10

- 图层样式新增 Drop Shadow Noise / 投影噪点控制，可让投影 alpha 生成稳定颗粒，制作更接近 Photoshop 的粗糙投影效果。
- 投影噪点接入图层样式渲染、属性面板和 `.qpicproject` 保存恢复，旧项目缺少该字段时默认保持 0% 噪点。
- 补齐中 / 英 / 日三语文案与投影噪点回归测试；统一前后端版本号到 1.259.0。

## 1.258.0 - 2026-07-10

- Gradient Fill / 渐变填充图层新增 Linear、Radial、Reflected、Diamond 四种样式，补齐更接近 Photoshop 的渐变填充工作流。
- 渐变样式可在属性面板切换，并随 `.qpicproject` 保存恢复；旧项目缺少样式字段时默认保持 Linear 视觉兼容。
- 补齐中 / 英 / 日三语文案与渐变样式回归测试；统一前后端版本号到 1.258.0。

## 1.257.0 - 2026-07-10

- 独立图片编辑器新增 Pattern Fill / 图案填充图层，可保存棋盘、斜线、圆点图案以及颜色、不透明度和缩放参数。
- 图案填充作为非破坏式内容层参与画布渲染、蒙版、混合、智能滤镜、图层徽标、类型筛选、菜单入口和项目恢复。
- 补齐中 / 英 / 日三语文案与图案填充回归测试；统一前后端版本号到 1.257.0。

## 1.256.0 - 2026-07-10

- 独立图片编辑器新增 Solid Color Fill / 纯色填充图层，可保存 RGB 参数并作为非破坏式内容层渲染。
- 填充图层可继续叠加智能滤镜；纯色填充同步接入图层徽标、类型筛选、菜单入口、属性面板、项目恢复和图层摘要。
- 补齐中 / 英 / 日三语文案与纯色填充回归测试；统一前后端版本号到 1.256.0。

## 1.255.0 - 2026-07-09

- 独立图片编辑器新增 Gradient Fill / 渐变填充图层，可创建可保存的线性渐变内容层。
- 渐变填充支持预设、自定义起止 RGB、反向、角度和缩放，并参与图层透明度、混合、蒙版和样式渲染链路。
- 滤镜层与智能滤镜栈新增 Vignette / 暗角滤镜，可按径向距离保留中心并压暗边缘。
- 补齐中 / 英 / 日三语文案、图层筛选、项目恢复、渐变填充回归测试与暗角滤镜非破坏测试；统一前后端版本号到 1.255.0。

## 1.254.0 - 2026-07-09

- 滤镜层与智能滤镜栈新增 Oil Paint / 油画滤镜，可按邻域主亮度色彩生成块面化笔触效果。
- 油画滤镜使用确定性的像素分桶算法，强度会调整采样半径和亮度分桶，便于稳定预览、撤销和项目恢复。
- 补齐中 / 英 / 日三语文案与油画滤镜回归测试；统一前后端版本号到 1.254.0。

## 1.253.0 - 2026-07-09

- 滤镜层与智能滤镜栈新增 Minimum / Maximum，可按邻域最小值或最大值收缩、扩张亮区和暗区。
- Minimum / Maximum 复用现有像素滤镜、蒙版滤镜和智能滤镜管线，便于处理蒙版边缘、线稿和高对比素材。
- 补齐中 / 英 / 日三语文案与 Minimum / Maximum 回归测试；统一前后端版本号到 1.253.0。

## 1.252.0 - 2026-07-09

- 滤镜层与智能滤镜栈新增 Find Edges / 查找边缘滤镜，可把平坦区域转为白底并以深色线条突出边缘。
- 查找边缘滤镜采用 Sobel 逐像素边缘检测，并复用现有滤镜层、智能滤镜与蒙版滤镜合成管线。
- 补齐中 / 英 / 日三语文案与查找边缘滤镜回归测试；统一前后端版本号到 1.252.0。

## 1.251.0 - 2026-07-09

- 图层混合模式新增 Darker Color、Lighter Color、Subtract、Divide、Hard Mix，补齐更接近 Photoshop 的核心混合族。
- 新增混合模式采用逐像素合成公式，并接入现有图层渲染路径，不再只是菜单占位。
- 补齐中 / 英 / 日三语文案与混合模式回归测试；统一前后端版本号到 1.251.0。

## 1.250.0 - 2026-07-09

- 滤镜层与智能滤镜栈新增 Emboss / 浮雕滤镜，可把画面压成中灰浮雕并突出方向性边缘高光。
- 浮雕滤镜复用现有像素级滤镜、蒙版和智能滤镜管线，保留原始图层像素以便继续编辑。
- 补齐中 / 英 / 日三语文案与浮雕滤镜回归测试；统一前后端版本号到 1.250.0。

## 1.249.0 - 2026-07-09

- 滤镜层与智能滤镜栈新增 High Pass / 高反差保留滤镜，平坦区域回到中灰并保留边缘明暗反差。
- 高反差保留滤镜可作为非破坏式滤镜层或智能滤镜使用，保留原始图层像素以便后续继续编辑。
- 补齐高反差保留滤镜层与智能滤镜回归测试；统一前后端版本号到 1.249.0。

## 1.248.0 - 2026-07-09

- 图层面板和 Layer 菜单新增隔离显示所选图层，可临时隐藏其它图层并自动保持所选组的后代与必要父组可见。
- 新增显示全部图层命令，可一键恢复所有图层可见性，并纳入撤销/历史记录。
- 补齐所选图层隔离显示与恢复可见性回归测试；统一前后端版本号到 1.248.0。

## 1.247.0 - 2026-07-09

- 导航器 / 信息面板的直方图新增暗部 / 高光裁切比例读数，可快速识别死黑和过曝区域。
- 直方图统计模型会记录亮度为 0 与 255 的采样像素比例，并随平均 RGB、平均亮度一起展示。
- 补齐直方图裁切统计回归测试；统一前后端版本号到 1.247.0。

## 1.246.0 - 2026-07-09

- 导航器 / 信息面板新增合成图直方图预览，按 RGB 与亮度通道展示当前画面分布。
- 信息区新增平均 RGB 与平均亮度读数，便于判断曝光、偏色和通道状态。
- 补齐直方图统计回归测试；统一前后端版本号到 1.246.0。

## 1.245.0 - 2026-07-09

- 路径属性面板新增复制当前子轮廓，可把复合路径中的当前轮廓复制为相邻子路径并自动选中新副本。
- 子轮廓副本会优先向画布内轻微偏移，并保持主轮廓与其它子轮廓不变，便于快速制作重复路径岛屿。
- 补齐复合路径子轮廓复制回归测试；统一前后端版本号到 1.245.0。

## 1.244.0 - 2026-07-09

- Layer > Mask 和图层面板现在支持把当前非反相几何选区直接创建为图层组的闭合矢量蒙版，用画布空间非破坏地裁切整组内容。
- 组级矢量蒙版可继续载回选区或抽出为可编辑路径层，路径坐标统一按蒙版尺寸归一，避免组蒙版编辑时发生偏移。
- 补齐组级选区转矢量蒙版回归测试；统一前后端版本号到 1.244.0。

## 1.243.0 - 2026-07-09

- 路径属性面板新增上一个 / 下一个子轮廓，可在复合路径的多个轮廓之间直接切换当前编辑目标。
- 子轮廓切换会自动选中目标轮廓的首个锚点并更新状态栏，便于后续移动、删除、微调或编辑锚点。
- 补齐复合路径子轮廓切换回归测试；统一前后端版本号到 1.243.0。

## 1.242.0 - 2026-07-09

- 路径属性面板新增当前复合路径子轮廓四向微移，可按 1 px 移动所选轮廓的全部锚点与控制柄。
- 子轮廓移动会限制在画布范围内，并保留主轮廓与其它子轮廓的位置，便于细调多岛屿路径和矢量蒙版。
- 补齐复合路径子轮廓微移回归测试；统一前后端版本号到 1.242.0。

## 1.241.0 - 2026-07-09

- 新增复合路径当前子轮廓删除能力，属性面板可直接删除选中的子路径并保留其余轮廓。
- 补齐复合路径子轮廓删除回归测试；统一前后端版本号到 1.241.0。

## 1.240.0 - 2026-07-09

- 复合路径编辑支持子轮廓锚点选择、拖动、坐标微调、手柄平滑 / 对称 / 清除、插入、删除和方向反转，避免多轮廓路径只能编辑主轮廓。
- 路径图层更新会把所有子轮廓一起参与边界重算和本地坐标归一，移动任一子路径时不会裁掉其它轮廓。
- 补齐复合路径子轮廓拖动回归测试；统一前后端版本号到 1.240.0。

## 1.239.0 - 2026-07-09

- Layer 菜单和图层面板新增选择全部图层、反选图层和清除图层选择，补齐多图层批处理前的基础选择工作流。
- 图层选择命令不会改动画布像素选区，并会正确更新主图层、选中图层数量与状态栏提示。
- 补齐中 / 英 / 日三语文案与图层选择回归测试；统一前后端版本号到 1.239.0。

## 1.238.0 - 2026-07-09

- Shape path 支持复合路径子轮廓，单个路径层可承载多个闭合 subpath，并随项目文件保存恢复。
- Make Work Path 会把栅格选区中的多个轮廓写入同一个复合路径层，路径载入选区、路径转蒙版、路径填充和描边都会保留子轮廓。
- 补齐多岛栅格选区转复合路径回归测试；统一前后端版本号到 1.238.0。

## 1.237.0 - 2026-07-09

- Make Work Path 支持从栅格选区提取最大外轮廓，可把颜色范围、魔棒、通道等 mask 型选区转换为可编辑闭合路径层。
- 栅格选区转路径会沿 alpha 边界生成正交锚点并保留凹角轮廓，避免退化成简单 bounds 矩形。
- 补齐中 / 英 / 日三语提示更新与 L 形栅格选区转路径回归测试；统一前后端版本号到 1.237.0。

## 1.236.0 - 2026-07-09

- Select 菜单新增 Make Work Path，可把当前非反相几何选区转换成新的可编辑闭合路径层。
- 选区生成的路径层会保留当前图层组上下文，自动选择首个锚点，并继续支持路径编辑、路径载入选区、路径转蒙版等现有能力。
- 补齐中 / 英 / 日三语文案与选区生成路径回归测试；统一前后端版本号到 1.236.0。

## 1.235.0 - 2026-07-09

- Layer > Mask 和图层面板新增 Add Vector Mask from Selection，可把当前非反相几何选区直接转换为当前图层的闭合矢量蒙版。
- 选区转矢量蒙版会按目标图层 frame 映射到本地图层坐标，启用后可继续载回选区或抽出为可编辑路径。
- 补齐中 / 英 / 日三语文案与选区生成矢量蒙版回归测试；统一前后端版本号到 1.235.0。

## 1.234.0 - 2026-07-09

- Layer 菜单和图层面板新增 Merge Selected Layers，可把多选图层或所选图层组的真实合成结果烘焙为一个普通像素层。
- 合并所选图层会移除原始所选层，保留未选图层，并在合并后清理失去基底的无效剪贴蒙版。
- 补齐中 / 英 / 日三语文案与合并所选图层回归测试；统一前后端版本号到 1.234.0。

## 1.233.0 - 2026-07-09

- Layer > Mask 和图层面板新增 Rasterize Vector Mask，可把当前启用的闭合矢量蒙版烘焙为普通栅格图层蒙版。
- 栅格化矢量蒙版会与现有栅格蒙版的可见效果合并，并移除矢量蒙版以便继续用栅格蒙版工具细修。
- 补齐中 / 英 / 日三语文案与矢量蒙版栅格化回归测试；统一前后端版本号到 1.233.0。

## 1.232.0 - 2026-07-09

- 路径属性面板新增 Layer Mask Below，可把闭合路径直接应用为下方同组目标图层的栅格蒙版。
- 路径转栅格蒙版会保留路径图层作为可编辑源，并初始化目标蒙版的启用、链接、密度和羽化状态。
- 补齐中 / 英 / 日三语文案与路径转图层蒙版回归测试；统一前后端版本号到 1.232.0。

## 1.231.0 - 2026-07-09

- 路径属性面板新增 Fill to Pixels，可把闭合路径按当前前景色与不透明度填充到下方同组像素层。
- 填充路径会保留路径图层作为可编辑源，并尊重目标像素层的像素锁定与透明像素锁定状态。
- 补齐中 / 英 / 日三语文案与路径填充到像素层回归测试；统一前后端版本号到 1.231.0。

## 1.230.0 - 2026-07-09

- 路径属性面板新增 Stroke to Pixels，可把当前路径按前景色、画笔大小和不透明度描边到下方同组像素层。
- 描边路径会保留路径图层作为可编辑源，并尊重目标像素层的像素锁定与透明像素锁定状态。
- 补齐中 / 英 / 日三语文案与路径描边到像素层回归测试；统一前后端版本号到 1.230.0。

## 1.229.0 - 2026-07-09

- 路径属性面板新增 Reverse Path，可反转当前路径方向。
- 反转路径时会同步倒序锚点并交换每个锚点的入 / 出控制柄，保持曲线几何形状不被破坏。
- 补齐中 / 英 / 日三语文案与路径方向反转回归测试；统一前后端版本号到 1.229.0。

## 1.228.0 - 2026-07-09

- 路径属性面板新增 Symmetric Handles，可把当前锚点的入 / 出控制柄对称到同一直线上。
- 选中入柄或出柄时会以当前控制柄为主柄镜像另一侧；选中锚点且无控制柄时会按相邻路径方向生成一对对称控制柄。
- 补齐中 / 英 / 日三语文案与路径控制柄对称化回归测试；统一前后端版本号到 1.228.0。

## 1.227.0 - 2026-07-09

- 路径属性面板新增 Close Path / Open Path，可在开放路径与闭合路径之间切换。
- 闭合开放路径时会恢复可见填充并重新启用从路径建立选区；打开闭合路径时会移除填充并禁用闭合路径依赖能力。
- 补齐中 / 英 / 日三语文案与路径闭合切换回归测试；统一前后端版本号到 1.227.0。

## 1.226.0 - 2026-07-09

- 路径属性面板新增 Insert Anchor，可在当前选中锚点之后插入新路径锚点。
- 插入曲线路径锚点时使用三次贝塞尔分割保留两侧控制柄，避免曲线段被粗暴折断。
- 补齐中 / 英 / 日三语文案与路径插入锚点回归测试；统一前后端版本号到 1.226.0。

## 1.225.0 - 2026-07-09

- 路径属性面板新增 Delete Anchor，可删除当前选中的路径锚点并更新形状层路径。
- 删除闭合路径锚点时会保持路径有效；三点闭合路径删点后自动转为开放路径并移除填充，避免生成不可用的两点闭合路径。
- 补齐中 / 英 / 日三语文案与路径删除锚点回归测试；统一前后端版本号到 1.225.0。

## 1.224.0 - 2026-07-09

- Layer 菜单新增 Create Clipping Masks for Selected Layers 与 Release Selected Clipping Masks，可批量创建或释放多选图层的剪贴蒙版。
- 批量剪贴会跳过图层组、已剪贴图层、有效锁定图层和没有同组下方 base 的图层，并继续复用撤销、历史、状态提示与剪贴链归一化逻辑。
- 补齐中 / 英 / 日三语文案与多选剪贴蒙版回归测试；统一前后端版本号到 1.224.0。

## 1.223.0 - 2026-07-09

- Layer > Mask 新增 Copy Vector Mask to Selected Layers，可把主选中图层的矢量蒙版复制到其它多选图层。
- 矢量蒙版复制会按源图层与目标图层蒙版尺寸缩放路径锚点和控制柄，并继承矢量蒙版启停与蒙版链接状态。
- 补齐中 / 英 / 日三语文案与矢量蒙版复制回归测试；统一前后端版本号到 1.223.0。

## 1.222.0 - 2026-07-09

- Layer 菜单新增 Lock 子菜单，可对多选图层执行锁定 / 解锁，以及像素、位置、透明像素三类分项锁定与解锁。
- 批量解锁会同时清除全锁、像素锁、位置锁和透明像素锁；分项锁定会跳过不适用的图层类型并进入撤销、历史和状态提示。
- 补齐中 / 英 / 日三语文案与多选图层锁定回归测试；统一前后端版本号到 1.222.0。

## 1.221.0 - 2026-07-09

- Layer > Mask 新增 Reveal Current Selection、Hide Current Selection 和 Intersect with Current Selection，可把当前选区直接加到已有图层蒙版、从蒙版扣掉，或把蒙版限制到选区交集。
- 图层蒙版与选区组合会保留原有蒙版密度、羽化、链接和启停状态，并进入撤销与历史记录，便于反复修蒙版。
- 补齐中 / 英 / 日三语文案与图层蒙版选区组合回归测试；统一前后端版本号到 1.221.0。

## 1.220.0 - 2026-07-09

- Select 菜单新增 Remove Selection Speckles，可按当前选区修改数值删除孤立小选区块，保留较大的主体选区区域。
- 删除选区噪点使用连通区域扫描，不会像腐蚀操作一样持续削薄主体边缘，适合魔棒、颜色范围、通道和蒙版修边流程。
- 补齐中 / 英 / 日三语文案与选区噪点清理回归测试；统一前后端版本号到 1.220.0。

## 1.219.0 - 2026-07-09

- Select 菜单新增 Fill Selection Holes，可填充被当前选区完全包围的内部孔洞，并保留与画布边缘连通的外部未选区域。
- 填充选区孔洞会进入撤销和历史记录，适合抠图、蒙版和选区修边流程。
- 补齐中 / 英 / 日三语文案与选区填洞回归测试；统一前后端版本号到 1.219.0。

## 1.218.0 - 2026-07-09

- Select > Transform Selection 新增 Scale to 200%、Scale to 50% 和 Fit to Canvas，可围绕当前选区中心缩放选区蒙版，或将选区拉满整张画布。
- 缩放和适配选区只改变选区边界，不移动图层像素，适合在填充、描边、蒙版和拷贝前快速调整选区范围。
- 补齐中 / 英 / 日三语文案与选区缩放回归测试；统一前后端版本号到 1.218.0。

## 1.217.0 - 2026-07-09

- Select > Transform Selection 新增 Rotate 90 Clockwise、Rotate 90 Counterclockwise 和 Rotate 180，可围绕当前选区自身边界旋转选区蒙版。
- 旋转选区只改变选区边界，不移动图层像素，90 度旋转会交换选区边界宽高并裁剪到画布范围。
- 补齐中 / 英 / 日三语文案与选区旋转回归测试；统一前后端版本号到 1.217.0。

## 1.216.0 - 2026-07-09

- Select > Transform Selection 新增 Flip Horizontal / Flip Vertical，可围绕当前选区自身边界水平或垂直翻转选区蒙版。
- 翻转选区只改变选区边界，不移动图层像素，适合在填充、描边、蒙版和选区拷贝前快速镜像不对称选区。
- 补齐中 / 英 / 日三语文案与选区翻转回归测试；统一前后端版本号到 1.216.0。

## 1.215.0 - 2026-07-09

- Select 菜单新增 Transform Selection / 变换选区子菜单，可按当前选区修改步长向左、右、上、下移动选区边界。
- 移动选区会平移当前选区蒙版并裁剪到画布范围，不移动图层像素，适合微调选框后继续填充、描边、蒙版或拷贝流程。
- 补齐中 / 英 / 日三语文案与选区移动回归测试；统一前后端版本号到 1.215.0。

## 1.214.0 - 2026-07-09

- Select 菜单新增 Grow / 扩展相邻颜色，可从当前选区边缘向外吸附相邻且颜色相近的可见像素。
- Grow 选区使用当前选区内的颜色样本和当前容差，只沿连通区域扩张，避免像 Similar 一样选择画布上所有分散的相似颜色。
- 补齐中 / 英 / 日三语文案与相邻颜色扩展回归测试；统一前后端版本号到 1.214.0。

## 1.213.0 - 2026-07-09

- Select 菜单新增 Similar / 选取相似颜色，可从当前选区内抽取颜色样本，并按当前容差在整张合成图中生成相似颜色选区。
- Select Similar 复用颜色范围多样本匹配算法，继续遵循替换、添加、减去和相交选区模式，并进入历史记录与撤销链路。
- 补齐中 / 英 / 日三语文案与相似颜色选区回归测试；统一前后端版本号到 1.213.0。

## 1.212.0 - 2026-07-09

- Color Range / 颜色范围面板新增替换、添加和减去三种取样模式，可从源图预览连续吸取多个包含样本，并用排除样本扣掉不需要的相近颜色。
- 颜色范围选区算法升级为多样本匹配：像素命中任一包含样本且未命中排除样本才会进入选区，黑白预览与最终应用保持一致。
- 补齐中 / 英 / 日三语文案与多样本加减取样回归测试；统一前后端版本号到 1.212.0。

## 1.211.0 - 2026-07-09

- Color Range / 颜色范围源图预览支持点击取样，取样后会立即更新面板中的样本色与黑白选区预览。
- 预览取样复用编辑器既有合成图取色逻辑，并按预览中的实际图片区域映射坐标，避免点到留白误改颜色。
- 补齐中 / 英 / 日三语状态文案与源图取样回归测试；统一前后端版本号到 1.211.0。

## 1.210.0 - 2026-07-09

- Color Range / 颜色范围升级为独立面板，可同时查看源图与黑白选区预览。
- 面板支持取样色、Fuzziness / 容差和反相设置，应用后仍接入现有选区模式、历史记录与撤销链路。
- 补齐中 / 英 / 日三语文案与反相颜色范围选区测试；统一前后端版本号到 1.210.0。

## 1.209.0 - 2026-07-09

- Select 菜单新增 Color Range / 颜色范围命令，可按当前前景色与容差从合成图像生成栅格选区。
- 颜色范围选区接入现有替换、添加、减去和相交选区模式，并进入历史记录与撤销链路。
- 补齐中 / 英 / 日三语文案与颜色范围选区回归测试；统一前后端版本号到 1.209.0。

## 1.208.0 - 2026-07-09

- History 面板新增命名快照，可在当前编辑状态创建安全点并独立于线性撤销 / 重做保留。
- 历史快照支持重命名、恢复和删除；恢复快照会进入撤销栈，用户可撤销这次恢复回到恢复前状态。
- 补齐中 / 英 / 日三语文案与快照恢复、历史清理保留快照的回归测试；统一前后端版本号到 1.208.0。

## 1.207.0 - 2026-07-09

- 斜面浮雕新增光照角度控制，并可选择跟随项目级 Global Light / 全局光。
- 斜面渲染从固定左上高光、右下阴影升级为按光照角度生成高光与阴影，默认角度保持旧视觉结果。
- 补齐中 / 英 / 日三语文案与斜面全局光联动、项目恢复回归测试；统一前后端版本号到 1.207.0。

## 1.206.0 - 2026-07-09

- 图层样式新增项目级 Global Light / 全局光角度，投影和内阴影可选择跟随同一个光照角度。
- 全局光参与画布预览、栅格化、背景层转换、智能对象边界、复制选区透明度和导出路径，并随 `.qpicproject` v4 保存恢复。
- 补齐中 / 英 / 日三语文案与全局光联动、项目恢复回归测试；统一前后端版本号到 1.206.0。

## 1.205.0 - 2026-07-09

- 明确图层 Fill / 填充不透明度遵循 Photoshop 语义：只降低图层本体像素，不削弱描边、投影、发光和叠加等图层样式。
- 补充 Fill 0% 时投影仍保持可见的回归测试，避免后续把 Fill 和整体 Opacity 混用。
- 统一前后端版本号到 1.205.0。

## 1.204.0 - 2026-07-09

- 透明像素锁定扩展到选区填充、选区描边和渐变工具，编辑时会保留原图层 Alpha 形状。
- 父级图层组的透明像素锁定会继承到子图层，避免子图层像素编辑意外填实透明区域。
- 补充透明像素锁定回归测试；统一前后端版本号到 1.204.0。

## 1.203.0 - 2026-07-09

- 图层组新增 Pass Through / 穿透混合模式，新建组默认穿透，子图层可继续和组外底图直接混合。
- 图层组设为 Normal / 正常时改为隔离组合成，可得到 Photoshop 风格的普通组混合结果。
- 旧 `.qpicproject` 中组的 Normal 会在载入时迁移为 Pass Through 以保持既有视觉结果；统一前后端版本号到 1.203.0。

## 1.202.0 - 2026-07-09

- `.qpicproject` 项目格式升级到 v2，新增项目级智能对象源表，让同一 sourceID 的多个 Smart Object 实例共享一份源图像数据。
- 智能对象图层保存时会引用共享源数据，项目恢复时优先从源表重建实例，同时保留旧项目中图层自带 imageData 的兼容读取路径。
- 补齐智能对象共享源与旧格式恢复的自动化覆盖；统一前后端版本号到 1.202.0。

## 1.201.0 - 2026-07-09

- 独立图片编辑器的智能对象转换支持多选图层和整个图层组，可把选中的根图层集合渲染并裁切为单个嵌入式 Smart Object。
- 转换后会用一个智能对象替换原图层块，并保留当前视觉合成结果；撤销可恢复原多图层或组层级结构。
- 补齐中 / 英 / 日三语文案与自动化覆盖；统一前后端版本号到 1.201.0。

## 1.200.0 - 2026-07-09

- Color Lookup / 颜色查找调整新增外部 `.cube` LUT 导入，可读取常见 `LUT_3D_SIZE` 三维 LUT 并应用到当前像素层。
- 自定义 Cube LUT 会以名称、尺寸和表值保存进 adjustment layer 设置，项目移动后仍可恢复非破坏式 LUT 效果。
- 补齐中 / 英 / 日三语文案与自动化覆盖；统一前后端版本号到 1.200.0。

## 1.199.0 - 2026-07-09

- 独立图片编辑器新增 Color Lookup / 颜色查找调整，提供 Film Stock、Crisp Warm、Teal / Orange、Bleach Bypass 和 Moonlight 五个 LUT 风格预设。
- Color Lookup 支持直接应用当前像素层，也可作为非破坏 adjustment layer 保存预设并参与图层合成。
- 补齐中 / 英 / 日三语文案与自动化覆盖；统一前后端版本号到 1.199.0。

## 1.198.0 - 2026-07-09

- 独立图片编辑器新增 Brightness/Contrast / 亮度-对比度调整，把亮度与对比度放在同一个 Photoshop 风格调整层中。
- Brightness/Contrast 支持直接应用当前像素层，也可作为非破坏 adjustment layer 保存双参数并参与图层合成。
- 补齐中 / 英 / 日三语文案与自动化覆盖；统一前后端版本号到 1.198.0。

## 1.197.1-rc1 - 2026-07-09

- 修复调整层设置新增字段后，旧 `.qpicproject` 项目中缺少这些字段时可能无法解码的问题。
- `ImageEditorAdjustmentSettings` 改为显式兼容解码，缺失的 Exposure、Shadows/Highlights、Black & White、Channel Mixer 等参数会回退到默认值。
- 补充旧调整层设置载入回归测试；统一前后端版本号到 1.197.1-rc1。

## 1.197.0 - 2026-07-09

- 独立图片编辑器升级 Exposure / 曝光调整，从单滑杆扩展为 Exposure、Offset、Gamma Correction 三参数控制。
- Exposure 继续支持直接应用当前像素层，也可作为非破坏 adjustment layer 保存三参数并参与图层合成。
- 补齐中 / 英 / 日三语文案与自动化覆盖；统一前后端版本号到 1.197.0。

## 1.196.0 - 2026-07-09

- 独立图片编辑器新增 Shadows/Highlights / 阴影-高光调整，可分别提亮暗部与压低亮部，改善截图和照片的局部曝光。
- Shadows/Highlights 支持直接应用当前像素层，也可作为非破坏 adjustment layer 保存阴影和高光参数并参与图层合成。
- 补齐中 / 英 / 日三语文案与自动化覆盖；统一前后端版本号到 1.196.0。

## 1.195.0 - 2026-07-09

- 独立图片编辑器新增 Posterize / 色调分离调整，支持 2-32 级通道量化，便于制作平面化、海报化色彩效果。
- Posterize 可直接应用当前像素层，也可作为非破坏 adjustment layer 保存级数并参与现有图层合成。
- 补齐中 / 英 / 日三语文案与自动化覆盖；统一前后端版本号到 1.195.0。

## 1.194.0 - 2026-07-09

- 独立图片编辑器新增 Vibrance / 自然饱和度调整，可优先增强低饱和颜色并温和处理高饱和区域。
- Vibrance 支持直接应用到当前像素层，也可作为非破坏 adjustment layer 参与现有图层合成。
- 补齐中 / 英 / 日三语文案与自动化覆盖；统一前后端版本号到 1.194.0。

## 1.193.0 - 2026-07-09

- 独立图片编辑器 Image / Filter 菜单新增 Auto Contrast 和 Auto Color，与 Auto Levels 组成基础自动校正命令组。
- Auto Contrast 会按当前可见像素亮度范围拉伸对比度；Auto Color 会按 RGB 平均值做灰世界白平衡，降低整体偏色。
- 补齐中 / 英 / 日三语文案与自动化覆盖；统一前后端版本号到 1.193.0。

## 1.192.0 - 2026-07-09

- 独立图片编辑器 Layer 菜单新增 Layer Style 子菜单，集中提供复制、粘贴、清除图层样式和常用样式开关入口。
- 图层样式粘贴支持多选目标，会跳过锁定、组、调整层和滤镜层等不可编辑目标，并纳入撤销与历史记录。
- 补齐中 / 英 / 日三语文案与自动化覆盖；统一前后端版本号到 1.192.0。

## 1.191.0 - 2026-07-09

- 独立图片编辑器 Image / Filter 菜单新增 Auto Levels，可对当前可编辑像素图层按 RGB 通道自动拉伸色阶。
- Auto Levels 会扫描可见像素的通道范围并重映射到完整 0...255 区间，复用现有选区裁剪、透明像素锁、历史记录与撤销链路。
- 补齐中 / 英 / 日三语文案与自动化覆盖；统一前后端版本号到 1.191.0。

## 1.190.0 - 2026-07-09

- 独立图片编辑器 Layer > Mask 新增 Copy Mask to Selected Layers，可把主选中图层的栅格蒙版复制到其它多选图层。
- 复制蒙版会按目标图层自身尺寸重采样，并继承蒙版启用、链接、密度和羽化状态，纳入历史记录与撤销链路。
- 补齐中 / 英 / 日三语文案与自动化覆盖；统一前后端版本号到 1.190.0。

## 1.189.0 - 2026-07-09

- 独立图片编辑器 Layer 菜单新增 Layer From Background 和 Background From Layer，补齐背景层与普通图层互转工作流。
- Background From Layer 会把当前图层按画布坐标烘焙成不透明背景层，透明区域使用当前背景色填充，并移动到底部锁定。
- 补齐中 / 英 / 日三语文案与自动化覆盖；统一前后端版本号到 1.189.0。

## 1.188.0 - 2026-07-09

- 独立图片编辑器 Layer > Transform 新增 90° 逆时针、90° 顺时针和 180° 图层旋转入口，补齐菜单级直角旋转工作流。
- 直角旋转复用现有图层变换链路，支持多选、链接图层、栅格蒙版同步旋转、历史记录与撤销恢复。
- 补齐中 / 英 / 日三语文案与自动化覆盖；统一前后端版本号到 1.188.0。

## 1.187.0 - 2026-07-09

- 独立图片编辑器 Layer > Transform 新增裁切透明像素，可把当前像素图层边缘的透明区域裁掉。
- 裁切会同步更新图层位图、frame、链接栅格蒙版和矢量蒙版局部坐标，保持画布上的可见内容位置不漂移，并纳入撤销与历史记录。
- 补齐中 / 英 / 日三语文案与自动化覆盖；统一前后端版本号到 1.187.0。

## 1.186.0 - 2026-07-09

- 独立图片编辑器 Layer > Transform 新增图层级水平翻转和垂直翻转，不再只能翻转整张画布。
- 图层翻转会围绕当前选择集合的联合边界框执行，支持多选、图层组展开成员、链接图层相对位置镜像，并在蒙版链接时同步翻转栅格蒙版。
- 补齐中 / 英 / 日三语文案与自动化覆盖；统一前后端版本号到 1.186.0。

## 1.185.0 - 2026-07-09

- 独立图片编辑器 Layer 菜单新增 Transform 子菜单，支持将所选图层适配或填满画布。
- Transform 子菜单支持将所选图层适配或填满当前选区，导入、粘贴到选区后可快速完成版面铺放。
- 变换命令复用现有多选、图层组展开、链接图层、位置锁定、撤销和历史记录链路；补齐中 / 英 / 日三语文案与自动化覆盖；统一前后端版本号到 1.185.0。

## 1.184.0 - 2026-07-09

- 独立图片编辑器新增 Paste Into Selection，可把剪贴板图片粘贴为新图层并自动从当前选区生成图层蒙版。
- 粘贴到选区会按选区边界等比放置导入图像，保留新图层、历史记录、撤销和蒙版合成链路。
- 补齐中 / 英 / 日三语文案与自动化覆盖；统一前后端版本号到 1.184.0。

## 1.183.0 - 2026-07-09

- 独立图片编辑器新增通过合成拷贝新建图层，可把可见图层的最终合成结果直接留在图层栈中继续编辑。
- 存在选区时只把合成后的选区内容生成透明背景图层；没有选区时生成完整可见画布图层，补齐 Copy Merged 与图层编辑之间的闭环。
- 补齐中 / 英 / 日三语文案与自动化覆盖；统一前后端版本号到 1.183.0。

## 1.182.0 - 2026-07-09

- 独立图片编辑器新增 Copy Merged，可把所有可见图层的合成结果复制到系统剪贴板。
- Copy Merged 在存在选区时会只复制合成后的选区内容，没有选区时复制完整可见画布，更贴近 Photoshop / Photopea 的剪贴板工作流。
- 补齐中 / 英 / 日三语文案；统一前后端版本号到 1.182.0。

## 1.181.0 - 2026-07-09

- 独立图片编辑器新增从选区复制图片到系统剪贴板，可把当前图层的选区内容输出为透明 PNG/TIFF 剪贴板图像。
- Edit 菜单新增粘贴为图层，可读取系统剪贴板图片并复用导入图层流程生成新的可编辑图层。
- 补齐中 / 英 / 日三语文案；统一前后端版本号到 1.181.0。

## 1.180.0 - 2026-07-09

- 独立图片编辑器顶部 Edit 菜单补齐通过拷贝新建图层与通过剪切新建图层入口，选区内容可从菜单直接进入 Layer via Copy / Cut 工作流。
- 菜单禁用状态复用现有图层、选区、锁定和蒙版编辑判定，避免不可编辑目标误触发像素改写。
- 继续保持中 / 英 / 日三语文案与现有自动化覆盖；统一前后端版本号到 1.180.0。

## 1.179.0 - 2026-07-09

- 独立图片编辑器新增从图层蒙版和矢量蒙版载入选区，可直接把蒙版轮廓回流到选区工作流。
- 载入蒙版选区会遵循当前选区模式，支持替换、添加、减去和相交，并在 Layer 菜单与图层面板提供入口。
- 补齐中 / 英 / 日三语文案与自动化覆盖；统一前后端版本号到 1.179.0。

## 1.178.0 - 2026-07-09

- 独立图片编辑器的图层面板新增按属性过滤图层，可快速查看带蒙版、带图层样式、剪贴蒙版、已链接和带智能滤镜图层。
- 属性过滤会继续与名称搜索、图层类型、颜色标签和有效状态过滤组合生效。
- 补齐中 / 英 / 日三语文案与自动化覆盖；统一前后端版本号到 1.178.0。

## 1.177.0 - 2026-07-09

- 独立图片编辑器的图层面板新增按状态过滤图层，可快速查看全部、可见、隐藏、锁定和未锁定图层。
- 状态过滤会使用父组影响后的有效显隐与有效锁定状态，并可与名称搜索、图层类型和颜色标签过滤组合生效。
- 补齐中 / 英 / 日三语文案与自动化覆盖；统一前后端版本号到 1.177.0。

## 1.176.0 - 2026-07-09

- 独立图片编辑器的图层面板新增按颜色标签过滤图层，可快速查看红、橙、黄、绿、蓝、紫、灰标签图层。
- 颜色标签过滤会与名称搜索和图层类型过滤组合生效，便于在复杂图层稿中精确定位目标图层。
- 补齐中 / 英 / 日三语文案与自动化覆盖；统一前后端版本号到 1.176.0。

## 1.175.0 - 2026-07-09

- 独立图片编辑器的图层面板新增图层类型过滤，可按全部、像素、文字、形状、调整、滤镜、智能对象和图层组快速筛选当前可见图层行。
- 类型过滤会与现有图层名称搜索组合生效，便于在复杂 PSD 风格图层稿中定位目标图层。
- 补齐中 / 英 / 日三语文案与自动化覆盖；统一前后端版本号到 1.175.0。

## 1.174.0 - 2026-07-09

- 独立图片编辑器的图层面板新增颜色标签，可为单个或多个所选图层设置红、橙、黄、绿、蓝、紫、灰标签或清除标签。
- 图层颜色标签会显示在图层行内，并随 `.qpicproject` 项目文件与 Layer Comps 一起保存、恢复和应用。
- 补齐中 / 英 / 日三语文案与自动化覆盖；统一前后端版本号到 1.174.0。

## 1.173.0 - 2026-07-09

- 独立图片编辑器的图层面板新增图层搜索框，可按名称过滤当前可见图层行，折叠组内隐藏成员不会被误展开。
- 图层面板支持直接编辑图层名称，提交后复用现有重命名历史和撤销链路。
- 补齐中 / 英 / 日三语文案与自动化覆盖；统一前后端版本号到 1.173.0。

## 1.172.0 - 2026-07-09

- 独立图片编辑器的图层面板新增拖拽重排，可把图层放到目标图层上方、下方，或直接拖入图层组。
- 拖拽移动会把图层组及其后代作为同一个块处理，并阻止把组拖进自己的后代，避免图层树形成循环。
- 补齐中 / 英 / 日三语文案与自动化覆盖；统一前后端版本号到 1.172.0。

## 1.171.0 - 2026-07-09

- 独立图片编辑器的新建图层和新建图层组会继承当前选择的图层组上下文，选中组时直接创建到组内，选中组内图层时创建为同组兄弟。
- 新建子图层会自动展开父组并保持撤销恢复，复杂图层树整理时不再把新内容误放到顶层。
- 补齐自动化覆盖；统一前后端版本号到 1.171.0。

## 1.170.0 - 2026-07-09

- 独立图片编辑器新增图层移入上方组、移出当前组命令，让图层组结构可像图层树一样继续整理。
- 图层面板和 Layer 菜单新增对应入口，并保留多选图层的选择状态与撤销恢复。
- 补齐中 / 英 / 日三语文案与自动化覆盖；统一前后端版本号到 1.170.0。

## 1.169.0 - 2026-07-09

- 独立图片编辑器新增选择已链接图层命令，可从当前选中图层出发选中完整的传递链接图层集合。
- 图层面板和 Layer 菜单新增选择已链接图层入口，链接图层的选择、移动、解除链接工作流更完整。
- 补齐中 / 英 / 日三语文案与自动化覆盖；统一前后端版本号到 1.169.0。

## 1.168.0 - 2026-07-09

- 独立图片编辑器新增解除全部图层链接命令，可一次清空当前项目中的所有图层链接关系并支持撤销恢复。
- Layer 菜单补齐链接所选图层、解除所选图层链接和解除全部图层链接入口，和图层面板工具栏保持一致。
- 补齐中 / 英 / 日三语文案与自动化覆盖；统一前后端版本号到 1.168.0。

## 1.167.0 - 2026-07-09

- 独立图片编辑器扩展图层分布命令，从水平 / 垂直中心分布补齐为左、水平中心、右、顶端、垂直中心、底端六向分布。
- 图层面板和 Layer 菜单新增六向分布入口，分布算法按所选锚点排序并保留首尾锚点位置。
- 补齐中 / 英 / 日三语文案与自动化覆盖；统一前后端版本号到 1.167.0。

## 1.166.0 - 2026-07-09

- 独立图片编辑器补齐图层分布能力，新增按水平中心和垂直中心分布多选图层。
- 图层面板和 Layer 菜单新增分布入口，分布命令复用现有多选、链接图层、组后代和锁定过滤逻辑。
- 补齐中 / 英 / 日三语文案与自动化覆盖；统一前后端版本号到 1.166.0。

## 1.165.0 - 2026-07-09

- 独立图片编辑器补齐剪贴蒙版状态规范化，图层移动、置底、成组、解组、删除和合并后会自动清理失去基底的剪贴标记。
- 新增自动化覆盖单独成组剪贴层、把剪贴层移动到基底下方等边界场景，避免图层面板残留无效剪贴状态。
- 统一前后端版本号到 1.165.0，并继续只保留中 / 英 / 日三语资源。

## 1.164.0 - 2026-07-09

- 独立图片编辑器新增“让智能对象实例独立”命令，可把当前实例从同源智能对象组中拆出。
- 独立化后当前实例保留原图像、frame、蒙版、样式、混合和智能滤镜，但后续替换内容不再影响原同源实例。
- 图层面板新增独立化入口，补齐中 / 英 / 日三语文案；统一前后端版本号到 1.164.0。

## 1.163.0 - 2026-07-09

- 独立图片编辑器扩展智能对象源身份，复制智能对象会保留同一个嵌入源 ID。
- 替换智能对象内容时会同步更新所有同源实例，并保留每个实例自己的 frame、蒙版、样式、混合和智能滤镜。
- `.qpicproject` 项目文件会保存和恢复智能对象源 ID，并兼容缺少该字段的旧项目；补齐中 / 英 / 日三语文案，统一前后端版本号到 1.163.0。

## 1.162.0 - 2026-07-09

- 独立图片编辑器扩展智能对象，新增重置智能对象变换命令，可把缩放后的智能对象恢复到源内容原始尺寸。
- 重置变换会保持当前中心点，并保留智能对象源图像、蒙版、样式、混合和智能滤镜栈，不进行栅格化烘焙。
- 图层面板新增重置变换入口，补齐中 / 英 / 日三语文案；统一前后端版本号到 1.162.0。

## 1.161.0 - 2026-07-09

- 独立图片编辑器扩展智能对象，新增替换智能对象内容命令，可从本地图片更新嵌入源内容。
- 替换内容时会保留当前智能对象层的 frame、蒙版、样式、混合和智能滤镜，只更新源图像与原始尺寸元数据。
- 图层面板新增替换内容入口，补齐中 / 英 / 日三语文案；统一前后端版本号到 1.161.0。

## 1.160.0 - 2026-07-09

- 独立图片编辑器新增嵌入式智能对象图层类型，可把当前普通、文字、形状或样式图层转换为智能对象容器。
- 智能对象层会保留源图像尺寸元数据，继续支持图层变换、智能滤镜、项目保存恢复和需要时栅格化。
- 图层面板新增转换智能对象入口和徽标，补齐中 / 英 / 日三语文案；统一前后端版本号到 1.160.0。

## 1.159.0 - 2026-07-09

- 独立图片编辑器扩展 Layer Comps 的栅格蒙版快照，新增图层蒙版本身像素内容保存。
- 应用新版 Layer Comp 时会恢复或清空保存时的栅格蒙版内容；旧 Layer Comp 缺少蒙版快照时保持当前蒙版内容不变。
- 扩展自动化覆盖栅格蒙版恢复、无蒙版复合清空、项目保存恢复和旧状态解码；统一前后端版本号到 1.159.0。

## 1.158.0 - 2026-07-09

- 独立图片编辑器扩展 Layer Comps 的非破坏式内容快照，新增文字 / 形状层内容、调整层与滤镜层参数、智能滤镜栈和矢量蒙版内容保存。
- 应用新版 Layer Comp 时会恢复上述非破坏式状态；旧 Layer Comp 缺少内容快照时会保持当前图层类型和内容不变，避免旧方案误把文字或形状层还原成普通像素层。
- 扩展自动化覆盖文字层、智能滤镜、矢量蒙版、调整层、滤镜层恢复和旧状态解码；统一前后端版本号到 1.158.0。

## 1.157.0 - 2026-07-09

- 独立图片编辑器扩展 Layer Comps 的图层结构快照，新增图层栈顺序、父组关系、图层链接、蒙版链接和锁定状态保存。
- 应用 Layer Comp 时会恢复已保存图层的相对栈顺序，并过滤已不存在的图层、组和链接目标，避免复杂图层稿切换方案后层级关系错乱。
- 扩展自动化覆盖 Layer Comp 图层顺序恢复、组归属、链接/锁定状态、项目保存恢复和旧状态解码；统一前后端版本号到 1.157.0。

## 1.156.0 - 2026-07-09

- 独立图片编辑器扩展 Layer Comps 的外观保存范围，新增图层样式快照，可保存并恢复描边、投影、发光、叠加、光泽和斜面浮雕等非破坏式样式状态。
- 应用 Layer Comp 时会恢复图层样式外观，避免复杂图层稿切换方案时丢失样式效果。
- 扩展自动化覆盖 Layer Comp 样式应用、项目保存恢复和旧状态解码；统一前后端版本号到 1.156.0。

## 1.155.0 - 2026-07-09

- 独立图片编辑器扩展 Layer Comps 的外观保存范围，新增 Blend If 四个阈值、栅格蒙版启停、蒙版密度、蒙版羽化和矢量蒙版启停状态。
- 应用 Layer Comp 时会恢复上述图层外观状态，并按编辑器控件范围裁剪异常数值，避免复杂图层稿切换方案时丢失蒙版与混合外观。
- 扩展自动化覆盖 Layer Comp 应用、项目保存恢复和旧状态解码；统一前后端版本号到 1.155.0。

## 1.154.0 - 2026-07-09

- 独立图片编辑器扩展 Layer Comps，图层复合现在会保存并恢复图层是否作为裁剪蒙版剪贴到下方图层。
- Layer Comp 状态解码兼容旧 `.qpicproject` 文件，旧项目缺少裁剪蒙版字段时会按未裁剪处理。
- 扩展自动化覆盖 Layer Comp 应用、项目保存恢复和旧状态解码；统一前后端版本号到 1.154.0。

## 1.153.0 - 2026-07-09

- 独立图片编辑器完善裁剪工具，拖拽裁剪不再只调整画布和图层 frame，而是作为完整画布空间变换处理。
- 裁剪会同步偏移并裁切图层、画布尺寸、图层蒙版、当前选区、已保存选区、Alpha 通道和参考线。
- 扩展自动化覆盖裁剪后的图层、选区、Alpha 通道和参考线坐标一致性；统一前后端版本号到 1.153.0。

## 1.152.0 - 2026-07-09

- 独立图片编辑器扩展图层组混合语义，组图层现在可设置非 Normal 混合模式。
- 非 Normal 图层组会先把组内可见后代隔离合成为组画布，再按组自身混合模式、不透明度和组蒙版合成到外部画布。
- Normal 图层组保持既有穿透式行为，避免影响已有普通组工作流。
- 扩展自动化覆盖组级 Multiply 隔离合成像素效果与 `.qpicproject` 项目保存恢复；统一前后端版本号到 1.152.0。

## 1.151.0 - 2026-07-09

- 独立图片编辑器扩展图层描边样式，新增 Stroke Color 控制，可把当前前景色应用为描边颜色。
- 描边颜色接入真实图层样式渲染，支持与描边位置、宽度、不透明度和 Fill Opacity 组合使用。
- 属性面板新增描边颜色预览与“使用前景色”命令，三语文案保持中文、英文、日文覆盖。
- 扩展自动化覆盖彩色描边像素效果与 `.qpicproject` 项目保存恢复；统一前后端版本号到 1.151.0。

## 1.150.0 - 2026-07-09

- 独立图片编辑器扩展图层投影样式，新增 Shadow Color 控制，可把当前前景色应用为投影颜色。
- 投影颜色接入真实图层样式渲染，支持与投影不透明度、距离、角度、扩展和模糊组合使用。
- 属性面板新增投影颜色预览与“使用前景色”命令，三语文案保持中文、英文、日文覆盖。
- 扩展自动化覆盖彩色投影像素效果与 `.qpicproject` 项目保存恢复；统一前后端版本号到 1.150.0。

## 1.149.0 - 2026-07-09

- 独立图片编辑器扩展图层投影样式，新增 Shadow Distance 与 Shadow Angle，支持按角度和距离控制投影方向。
- 投影渲染改为使用同步后的光照偏移参与真实图层样式合成，Spread、Blur 与半透明投影继续沿用同一渲染路径。
- 属性面板新增投影距离与角度控制，旧的 X/Y 偏移入口会反算距离和角度；`.qpicproject` 项目文件保存恢复新字段，并可从旧偏移字段兼容推导。
- 扩展自动化覆盖投影方向像素效果与项目保存恢复；统一前后端版本号到 1.149.0。

## 1.148.0 - 2026-07-09

- 独立图片编辑器扩展图层描边样式，新增 Stroke Opacity，可独立控制描边不透明度而不影响图层填充不透明度。
- 描边渲染在外侧、居中、内侧三种位置中统一使用描边颜色与不透明度生成 alpha，半透明描边会与底图正确混合。
- 属性面板新增描边不透明度控制，`.qpicproject` 项目文件保存恢复该字段，并保持旧项目默认 100% 兼容。
- 扩展自动化覆盖半透明描边像素混合与项目保存恢复；统一前后端版本号到 1.148.0。

## 1.147.0 - 2026-07-09

- 独立图片编辑器扩展图层描边样式，新增外侧、居中、内侧三种 Stroke Position。
- 描边渲染改为基于图层 alpha 的内外侧合成：外侧描边不会覆盖原内容，内侧描边不会溢出透明区域，居中描边同时生成内外两侧边缘。
- 属性面板新增描边位置菜单，`.qpicproject` 项目文件保存恢复该字段，并保持旧项目默认外侧兼容。
- 扩展自动化覆盖内侧描边像素约束与项目保存恢复；统一前后端版本号到 1.147.0。

## 1.146.0 - 2026-07-09

- 独立图片编辑器扩展图层投影样式，新增 Shadow Spread 控制，可在模糊前扩张投影 alpha，生成更接近 Photoshop 的实边投影。
- 投影 Spread 接入真实图层样式渲染和画布 padding 计算，避免扩张后的阴影在合成时被裁切。
- 属性面板新增投影扩展参数，`.qpicproject` 项目文件保存恢复该字段，并保持旧项目缺省兼容。
- 扩展自动化覆盖投影扩展像素效果与项目保存恢复；统一前后端版本号到 1.146.0。

## 1.145.0 - 2026-07-09

- 独立图片编辑器扩展 Blend If，新增下方图层亮度范围控制，可按底图黑场 / 白场阈值隐藏当前图层。
- 下方图层 Blend If 接入真实逐层合成流程，在当前层完成蒙版、样式、填充不透明度和组蒙版后，再依据已合成底图亮度裁切当前层 alpha。
- `.qpicproject` 项目文件新增下方图层 Blend If 字段，并保持旧项目缺省兼容；自动化覆盖底图亮度裁切效果与项目保存恢复。
- 统一前后端版本号：`AppVersion.current` 与 `MARKETING_VERSION` 对齐到 1.145.0。

## 1.144.0 - 2026-07-09

- 独立图片编辑器新增图层 Blend If 当前图层亮度范围控制，可在图层面板按黑场 / 白场阈值隐藏当前图层的暗部或亮部。
- Blend If 参数接入真实图层合成管线，会在蒙版、智能滤镜、文字 / 形状渲染之后影响图层 alpha，并参与后续混合、导出、合并和项目保存。
- `.qpicproject` 项目文件新增 Blend If 字段，并保持旧项目缺省兼容；自动化覆盖亮度裁切效果与项目保存恢复。
- 统一前后端版本号：`AppVersion.current` 与 `MARKETING_VERSION` 对齐到 1.144.0。

## 1.143.0 - 2026-07-09

- 独立图片编辑器新增 Photoshop 风格的溶解混合模式，可在图层混合模式下拉中选择。
- 图层合成管线新增确定性像素级溶解算法，半透明图层会按不透明度生成稳定颗粒，而不是整体半透明混合，便于导出、合并和撤销后复现同一视觉结果。
- 扩展自动化覆盖 50% 不透明度溶解图层的红 / 蓝硬像素分布、重复渲染稳定性和图层混合历史记录。
- 统一前后端版本号：`AppVersion.current` 与 `MARKETING_VERSION` 对齐到 1.143.0。

## 1.142.0 - 2026-07-09

- 独立图片编辑器新增平滑选区命令，可在 Select 菜单和属性面板中按当前像素参数去除选区毛刺并填平小孔。
- 平滑选区复用栅格选区管线，通过形态学开闭运算改善魔棒、套索和通道选区的锯齿边缘，后续填充、剪切和蒙版可直接使用平滑后的 mask。
- 扩展自动化覆盖平滑选区移除孤立凸点、填补内部小孔、历史记录与状态提示。
- 统一前后端版本号：`AppVersion.current` 与 `MARKETING_VERSION` 对齐到 1.142.0。

## 1.141.0 - 2026-07-09

- 独立图片编辑器新增边界选区命令，可在 Select 菜单和属性面板中把当前选区转换为指定像素宽度的环形边界选区。
- 边界选区复用现有栅格选区管线，通过外扩选区减去内缩选区生成真实 mask，后续填充、描边、剪切和蒙版操作都可直接使用。
- 扩展自动化覆盖边界选区的内外边缘、中心挖空、历史记录与状态提示。
- 统一前后端版本号：`AppVersion.current` 与 `MARKETING_VERSION` 对齐到 1.141.0。

## 1.140.0 - 2026-07-09

- 独立图片编辑器新增羽化选区命令，可在 Select 菜单和属性面板中按当前像素参数柔化选区边缘。
- 羽化会把当前几何或栅格选区转换为带半透明边缘的 raster mask，后续填充、清除、剪切、蒙版和局部编辑可复用柔边 alpha。
- 羽化算法使用横向 / 纵向滑动窗口盒式模糊，避免大画布高半径处理时随半径线性放大成本，并新增自动化覆盖柔边 alpha。
- 统一前后端版本号：`AppVersion.current` 与 `MARKETING_VERSION` 对齐到 1.140.0。

## 1.139.0 - 2026-07-09

- 独立图片编辑器新增网格显示与吸附到网格，可在 View 菜单中切换，并在画布上显示主 / 次网格线。
- 移动和自由缩放图层时，网格线会作为吸附候选参与边缘与中心对齐；关闭参考线吸附后仍可单独使用网格吸附。
- `.qpicproject` 项目文件会保存 / 恢复网格显示、网格吸附和网格间距，并扩展自动化覆盖移动、缩放和项目 round-trip。
- 统一前后端版本号：`AppVersion.current` 与 `MARKETING_VERSION` 对齐到 1.139.0。

## 1.138.0 - 2026-07-09

- 独立图片编辑器顶部 File / Edit / Image / Layer / Select / Filter / View / Window 从占位提示升级为真实菜单，接入项目、导出、撤销重做、图像变换、图层、蒙版、选区、滤镜、标尺和参考线等现有命令。
- 新增 `ImageEditorMenuBar.swift` 承载菜单 UI，避免继续扩大主 `ImageEditorView.swift`，为后续补齐更多 Photoshop 式菜单命令留出结构空间。
- 补齐新增菜单文案的简体中文、英文、日文国际化，并继续仅保留中英日三语目录。
- 统一前后端版本号：`AppVersion.current` 与 `MARKETING_VERSION` 对齐到 1.138.0。

## 1.137.0 - 2026-07-09

- 独立图片编辑器参考线吸附升级为智能候选，移动或缩放图层时会同时吸附到其它可见图层的左 / 中 / 右和下 / 中 / 上位置。
- 智能吸附会排除当前正在移动或缩放的图层，避免自身 frame 参与候选；手动参考线与图层候选会共用同一套阈值和修正逻辑。
- 扩展自动化覆盖无手动参考线时移动图层贴齐其它图层边缘、缩放图层贴齐其它图层边缘。
- 统一前后端版本号：`AppVersion.current` 与 `MARKETING_VERSION` 对齐到 1.137.0。

## 1.136.0 - 2026-07-09

- 独立图片编辑器自由缩放变换接入参考线吸附，拖动缩放句柄时可让变换框边缘或中心对齐到临近参考线。
- 缩放吸附复用现有参考线阈值与多选统一变换框流程，不改变图层像素重采样和多图层比例映射逻辑。
- 扩展自动化覆盖缩放右边缘吸附和缩放中心点吸附，为后续智能参考线和对象对齐继续打底。
- 统一前后端版本号：`AppVersion.current` 与 `MARKETING_VERSION` 对齐到 1.136.0。

## 1.135.0 - 2026-07-09

- 独立图片编辑器画布新增顶部与左侧标尺，可从标尺拖拽创建垂直或水平参考线，并在拖拽中显示临时参考线预览。
- 已有参考线新增透明命中区，可直接拖动调整位置；拖动过程只写入一次撤销记录，结束后记录“移动参考线”历史。
- 参考线面板新增标尺显示开关，`.qpicproject` 项目文件会保存 / 恢复标尺显示状态，并扩展自动化覆盖参考线移动与项目 round-trip。
- 统一前后端版本号：`AppVersion.current` 与 `MARKETING_VERSION` 对齐到 1.135.0。

## 1.134.0 - 2026-07-09

- 独立图片编辑器新增参考线能力，可在属性面板添加垂直 / 水平中心参考线、显示或隐藏参考线、开启或关闭参考线吸附，并清理全部参考线。
- 移动图层时会将选中图层集合的边缘或中心吸附到临近参考线；图像尺寸与画布尺寸命令会同步缩放或偏移参考线。
- `.qpicproject` 项目文件会保存 / 恢复参考线、显示状态和吸附状态，并新增自动化覆盖移动吸附、项目 round-trip 和尺寸联动。
- 统一前后端版本号：`AppVersion.current` 与 `MARKETING_VERSION` 对齐到 1.134.0。

## 1.133.0 - 2026-07-09

- 独立图片编辑器图层面板新增 Layer Comps 页签，可保存、应用、更新、重命名和删除图层复合状态。
- Layer Comp 会记录图层显隐、frame、不透明度、填充不透明度、混合模式、组展开状态和当前选中图层集合，并随 `.qpicproject` 项目文件保存 / 恢复。
- 补齐中 / 英 / 日三语图层复合文案，并新增自动化覆盖复合应用和项目文件 round-trip。
- 统一前后端版本号：`AppVersion.current` 与 `MARKETING_VERSION` 对齐到 1.133.0。

## 1.132.0 - 2026-07-09

- 独立图片编辑器属性面板新增文档尺寸区，支持调整图像尺寸与画布尺寸，并提供九宫格画布锚点。
- 图像尺寸命令会同步缩放图层 frame、图层像素、图层蒙版、矢量蒙版、选区和 Alpha 通道；画布尺寸命令会按锚点平移内容并保留图层像素尺寸。
- 补齐中 / 英 / 日三语尺寸命令文案，并新增自动化覆盖图像尺寸与画布尺寸对图层、选区和通道状态的影响。
- 统一前后端版本号：`AppVersion.current` 与 `MARKETING_VERSION` 对齐到 1.132.0。

## 1.131.0 - 2026-07-09

- 历史记录面板新增状态摘要，展示历史状态数、可撤销数和可重做数。
- 历史记录面板新增清理历史按钮，可保留当前画面并将其设为新的历史起点，同时释放旧撤销、重做和历史快照。
- 补齐中 / 英 / 日三语历史管理文案，并新增自动化覆盖清理历史后当前画面不丢失、撤销重做归零。
- 统一前后端版本号：`AppVersion.current` 与 `MARKETING_VERSION` 对齐到 1.131.0。

## 1.130.0 - 2026-07-09

- 独立图片编辑器新增 `.qpicproject` 项目文件保存 / 打开能力，可恢复画布、图层栈、选区、Alpha 通道、文字、形状、蒙版、图层样式、调整层、滤镜层和智能滤镜参数。
- 顶部工具栏新增打开项目与保存项目入口，项目文件使用 JSON + PNG 数据保存编辑状态，并将 macOS 用户选择文件权限调整为读写，便于后续扩展 PSD 类工程工作流。
- 补齐中 / 英 / 日三语项目文件文案，并新增项目 round-trip 自动化测试覆盖复杂编辑状态恢复。
- 统一前后端版本号：`AppVersion.current` 与 `MARKETING_VERSION` 对齐到 1.130.0。

## 1.129.0 - 2026-07-09

- USM 锐化升级为专业参数模型，支持独立设置数量、半径和阈值。
- 滤镜层和智能滤镜会保存并恢复 USM 半径 / 阈值参数，图层摘要和智能滤镜列表同步展示关键参数。
- 补齐中 / 英 / 日三语 USM 参数文案，并扩展自动化覆盖参数保存与高阈值抑制低对比边缘锐化。
- 统一前后端版本号：`AppVersion.current` 与 `MARKETING_VERSION` 对齐到 1.129.0。

## 1.128.0 - 2026-07-09

- 滤镜系统新增“USM 锐化”滤镜，可作为滤镜层或智能滤镜提升边缘局部对比。
- USM 锐化使用独立像素反遮罩算法，按强度混合边缘增强结果并保留图层 alpha。
- 补齐中 / 英 / 日三语 USM 锐化文案，并扩展自动化覆盖滤镜层与智能滤镜的非破坏式锐化行为。
- 统一前后端版本号：`AppVersion.current` 与 `MARKETING_VERSION` 对齐到 1.128.0。

## 1.127.0 - 2026-07-09

- 滤镜系统新增“中值”滤镜，可作为滤镜层或智能滤镜对椒盐噪点进行非破坏式降噪。
- 中值滤镜使用独立像素中值核实现，按强度混合结果并保留图层 alpha。
- 补齐中 / 英 / 日三语中值滤镜文案，并扩展自动化覆盖滤镜层与智能滤镜的非破坏式降噪行为。
- 统一前后端版本号：`AppVersion.current` 与 `MARKETING_VERSION` 对齐到 1.127.0。

## 1.126.0 - 2026-07-09

- 滤镜系统新增“添加杂色”滤镜，可作为滤镜层或智能滤镜生成确定性单色噪声并保留图层 alpha。
- 添加杂色滤镜复用独立滤镜模块，便于继续扩展 Photoshop 常见滤镜效果。
- 补齐中 / 英 / 日三语添加杂色文案，并扩展自动化覆盖滤镜层与智能滤镜的非破坏式杂色行为。
- 统一前后端版本号：`AppVersion.current` 与 `MARKETING_VERSION` 对齐到 1.126.0。

## 1.125.0 - 2026-07-09

- 滤镜系统新增“动感模糊”滤镜，可作为滤镜层或智能滤镜沿固定运动方向软化边缘。
- 新增 `ImageEditorFilters.swift`，将通用滤镜渲染与滤镜蒙版合成从主 ViewModel 拆出，降低后续扩展滤镜时的耦合。
- 补齐中 / 英 / 日三语动感模糊文案，并扩展自动化覆盖滤镜层与智能滤镜的非破坏式动感模糊行为。
- 统一前后端版本号：`AppVersion.current` 与 `MARKETING_VERSION` 对齐到 1.125.0。

## 1.124.0 - 2026-07-09

- 滤镜系统新增“像素化”滤镜，可作为滤镜层参与非破坏式合成。
- 智能滤镜栈支持像素化效果，保留原始图层像素并可逐项启用或关闭。
- 补齐中 / 英 / 日三语像素化滤镜文案，并新增自动化覆盖滤镜层与智能滤镜的非破坏式行为。
- 统一前后端版本号：`AppVersion.current` 与 `MARKETING_VERSION` 对齐到 1.124.0。

## 1.123.0 - 2026-07-09

- 图层蒙版新增“隐藏全部”创建模式，可直接创建全透明蒙版并进入蒙版编辑状态。
- 图层蒙版新增“隐藏选区”创建模式，与已有“从选区添加蒙版”形成显示 / 隐藏选区的对称工作流。
- 补齐中 / 英 / 日三语蒙版创建模式文案，并新增自动化覆盖隐藏全部与隐藏选区的合成结果和历史记录。
- 统一前后端版本号：`AppVersion.current` 与 `MARKETING_VERSION` 对齐到 1.123.0。

## 1.122.0 - 2026-07-09

- Alpha 通道可直接应用为当前图层的栅格蒙版，并自动启用蒙版编辑状态、重置蒙版密度与羽化。
- 通道面板支持从当前图层蒙版保存新的 Alpha 通道，完成图层蒙版与通道之间的双向转换。
- 补齐中 / 英 / 日三语通道蒙版互转文案，并新增自动化覆盖 Alpha 通道与图层蒙版往返流程。
- 统一前后端版本号：`AppVersion.current` 与 `MARKETING_VERSION` 对齐到 1.122.0。

## 1.121.0 - 2026-07-09

- Alpha 通道行支持直接重命名，并将有效名称变更纳入历史与撤销链路。
- Alpha 通道支持复制，复制项会保留原 mask 并生成不冲突的通道名称。
- Alpha 通道支持用当前选区覆盖更新，便于反复打磨保存的通道 mask。
- 补齐中 / 英 / 日三语通道维护文案，并新增自动化覆盖重命名、复制和更新流程。
- 统一前后端版本号：`AppVersion.current` 与 `MARKETING_VERSION` 对齐到 1.121.0。

## 1.120.0 - 2026-07-09

- 通道面板支持将当前选区保存为独立 Alpha 通道，并在文档模型中保存多个 Alpha mask。
- 已保存 Alpha 通道可重新载入为选区，继续复用替换、添加、减去和相交选区模式。
- 通道面板可删除已保存 Alpha 通道，并将保存、载入和删除纳入历史与撤销链路。
- 补齐中 / 英 / 日三语 Alpha 通道文案，并新增自动化覆盖保存、载入和删除流程。
- 统一前后端版本号：`AppVersion.current` 与 `MARKETING_VERSION` 对齐到 1.120.0。

## 1.119.0 - 2026-07-09

- 通道面板新增“载入为选区”按钮，可将 RGB 亮度、红、绿、蓝或 Alpha 通道转换为栅格选区。
- 通道载入选区复用现有选区模式，支持替换、添加、减去和相交，并进入历史与撤销链路。
- 扩展自动化覆盖红 / 绿通道选区布尔合成，以及 Alpha 通道按透明度生成选区。
- 补齐中 / 英 / 日三语通道载入选区文案。
- 统一前后端版本号：`AppVersion.current` 与 `MARKETING_VERSION` 对齐到 1.119.0。

## 1.118.0 - 2026-07-09

- 图层面板升级为“图层 / 通道”分段面板，新增 RGB、红、绿、蓝和 Alpha 通道预览入口。
- 画布与导航缩略图支持非破坏式通道灰阶预览，切换通道只影响编辑器显示，不改变图层栈、导出或应用到预览的合成结果。
- 新增 `ImageEditorChannels.swift`，集中管理通道类型、图层面板页签和通道预览渲染。
- 补齐中 / 英 / 日三语通道面板文案，并新增自动化覆盖 RGB 与 Alpha 通道预览。
- 统一前后端版本号：`AppVersion.current` 与 `MARKETING_VERSION` 对齐到 1.118.0。

## 1.117.0 - 2026-07-09

- 将图层面板从主编辑器视图拆入 `ImageEditorLayerPanel.swift`，为继续扩展图层 / 蒙版 / 剪贴能力腾出结构空间。
- 未链接图层蒙版移动时，矢量蒙版现在会像栅格蒙版一样反向偏移，保持蒙版在画布上的位置不变。
- 矢量蒙版渲染支持越界路径坐标，避免未链接移动时路径被夹回图层边界导致形状变形。
- 只有矢量蒙版的图层也可以切换蒙版链接状态，并复用图层面板里的链接按钮语义。
- 扩展自动化覆盖栅格蒙版与矢量蒙版在链接 / 未链接移动时的一致行为。
- 统一前后端版本号：`AppVersion.current` 与 `MARKETING_VERSION` 对齐到 1.117.0。

## 1.116.0 - 2026-07-09

- 矢量蒙版新增“编辑矢量蒙版路径”入口，可将当前图层矢量蒙版抽出为同组上方的可编辑闭合路径层。
- 抽出的路径层会保留路径锚点并清理原图层矢量蒙版，编辑后可复用“蒙版下方图层”重新应用回目标图层。
- 图层面板矢量蒙版缩略图现在可直接进入编辑路径流程，工具栏也提供独立编辑按钮。
- 补齐中 / 英 / 日三语矢量蒙版编辑文案，并扩展自动化覆盖矢量蒙版到路径层再应用回图层的往返流程。
- 统一前后端版本号：`AppVersion.current` 与 `MARKETING_VERSION` 对齐到 1.116.0。

## 1.115.0 - 2026-07-09

- 将栅格蒙版与矢量蒙版的启用状态拆分，图层合成时分别尊重两类蒙版开关。
- 图层面板新增独立矢量蒙版缩略图、状态提示，并支持单独停用 / 启用和删除矢量蒙版。
- 栅格化、合并、应用蒙版与路径转矢量蒙版流程会同步重置矢量蒙版启用状态，避免残留无效状态。
- 补齐中 / 英 / 日三语矢量蒙版操作文案，并扩展自动化覆盖矢量蒙版启用、恢复与删除后的合成效果。
- 统一前后端版本号：`AppVersion.current` 与 `MARKETING_VERSION` 对齐到 1.115.0。

## 1.114.0 - 2026-07-09

- 图层模型新增矢量蒙版字段，可保存闭合路径内容并在图层合成时与现有栅格蒙版取交集。
- 路径形状层新增“蒙版下方图层 / Vector Mask Below / 下のレイヤーをマスク”，可把当前闭合路径应用为同组下方目标图层的矢量蒙版，并移除源路径形状层。
- 栅格化、应用蒙版、合并可见与扁平化会正确烘焙或清理矢量蒙版状态。
- 补齐中 / 英 / 日三语矢量蒙版文案，并扩展自动化覆盖路径转矢量蒙版和合成效果。
- 统一前后端版本号：`AppVersion.current` 与 `MARKETING_VERSION` 对齐到 1.114.0。

## 1.113.0 - 2026-07-09

- 路径形状层新增从闭合路径建立选区，可将贝塞尔路径栅格化为现有选区 mask。
- 路径转选区会尊重当前选区布尔模式，支持替换、添加、减去和相交，并进入 History / 撤销链路。
- 属性面板路径编辑区新增 Make Selection / 建立选区 / 選択範囲に変換 动作。
- 补齐中 / 英 / 日三语路径转选区文案，并扩展自动化覆盖路径选区生成。
- 统一前后端版本号：`AppVersion.current` 与 `MARKETING_VERSION` 对齐到 1.113.0。

## 1.112.0 - 2026-07-09

- 路径形状层新增贝塞尔控制柄数据结构，保留旧 `pathPoints` 兼容的同时优先用 `pathAnchors` 渲染曲线路径。
- 钢笔路径编辑支持平滑当前锚点、清除当前锚点控制柄，并可在画布中命中和拖动入柄 / 出柄来调整曲线。
- 画布路径叠加层新增控制柄连线与手柄点，高亮区分当前选中的锚点或控制柄。
- 补齐中 / 英 / 日三语路径控制柄文案，并扩展自动化覆盖贝塞尔控制柄创建与拖动。
- 统一前后端版本号：`AppVersion.current` 与 `MARKETING_VERSION` 对齐到 1.112.0。

## 1.111.0 - 2026-07-09

- 图片编辑器路径形状层新增第一阶段锚点编辑：选中路径层后可用钢笔工具命中并拖动已有锚点。
- 属性面板新增路径锚点编辑区，可切换上一个 / 下一个锚点并微调当前锚点 X/Y 坐标，锚点移动进入 History / 撤销链路。
- 画布会显示当前路径层的锚点，选中锚点使用更明显的高亮样式，便于继续扩展贝塞尔手柄。
- 将路径命令拆入 `ImageEditorPathCommands.swift`，并将文字、形状和路径相关测试拆入 `ImageEditorVectorLayerTests.swift`，避免主文件接近 3000 行硬线。
- 补齐中 / 英 / 日三语路径锚点编辑文案，并扩展自动化覆盖路径锚点拖动。
- 统一前后端版本号：`AppVersion.current` 与 `MARKETING_VERSION` 对齐到 1.111.0。

## 1.110.0 - 2026-07-09

- 图片编辑器新增第一阶段 Pen / 钢笔工具，可在画布上逐点添加路径锚点，并生成开放或闭合的非破坏式路径形状图层。
- 形状层模型新增 Path / 路径类型，路径图层支持填充、描边、属性面板更新、图层合成、样式、蒙版、栅格化和 History / 撤销链路。
- 画布新增钢笔路径预览锚点和虚线连线，属性面板新增开放路径、闭合路径和取消路径命令。
- 补齐中 / 英 / 日三语钢笔和路径文案，并新增自动化覆盖路径形状层创建与更新。
- 统一前后端版本号：`AppVersion.current` 与 `MARKETING_VERSION` 对齐到 1.110.0。

## 1.109.0 - 2026-07-09

- 图片编辑器文字图层新增 Photoshop 式基础排版属性，支持左 / 中 / 右对齐、粗体、斜体、字距、行距和固定文本框宽度。
- 创建和更新文字图层时会保存完整排版参数，选中文字层后属性面板会同步当前文字样式，仍保持非破坏式文字层并参与合成、蒙版、样式和向下合并。
- 补齐中 / 英 / 日三语文字排版文案，并扩展自动化覆盖文字排版参数保存、更新和渲染变化。
- 统一前后端版本号：`AppVersion.current` 与 `MARKETING_VERSION` 对齐到 1.109.0。

## 1.108.0 - 2026-07-09

- 图片编辑器调整层新增 Photoshop 式 Gradient Map / 渐变映射，可按像素亮度映射黑白、棕褐、蓝橙、紫青或自定义双色渐变。
- 渐变映射支持反向映射和自定义阴影 / 高光 RGB 端点，可直接应用到像素层，也可作为非破坏式调整层参与蒙版、剪贴、History、撤销和向下合并链路。
- 将图层属性摘要从主 `ImageEditorViewModel.swift` 拆入 `ImageEditorLayerSummary.swift`，为继续扩展路径、文字和调整层能力降低主文件行数压力。
- 补齐中 / 英 / 日三语渐变映射文案，并新增自动化覆盖自定义渐变、反向映射、调整层参数保存和原像素不破坏。
- 统一前后端版本号：`AppVersion.current` 与 `MARKETING_VERSION` 对齐到 1.108.0。

## 1.107.0 - 2026-07-09

- 图片编辑器调整层新增 Photoshop 式 Selective Color / 可选颜色，支持红、黄、绿、青、蓝、洋红、白、中性色和黑色九个范围的 CMYK 调整。
- 可选颜色支持相对 / 绝对两种方法，可直接应用到像素层，也可作为非破坏式调整层参与蒙版、剪贴、History、撤销和向下合并链路。
- 补齐中 / 英 / 日三语可选颜色文案，并新增自动化覆盖色域选择、调整层参数保存和原像素不破坏。
- 统一前后端版本号：`AppVersion.current` 与 `MARKETING_VERSION` 对齐到 1.107.0。

## 1.106.0 - 2026-07-09

- 图片编辑器调整层新增 Photoshop 式 Photo Filter / 照片滤镜，支持暖色、冷色、棕褐色和自定义 RGB 滤镜。
- 照片滤镜支持密度和保留明度控制，可直接应用到像素层，也可作为非破坏式调整层参与蒙版、剪贴、History、撤销和向下合并链路。
- 补齐中 / 英 / 日三语照片滤镜文案，并新增自动化覆盖预设滤镜、自定义滤镜、调整层参数保存和原像素不破坏。
- 统一前后端版本号：`AppVersion.current` 与 `MARKETING_VERSION` 对齐到 1.106.0。

## 1.105.0 - 2026-07-09

- 图片编辑器调整层新增 Photoshop 式 Channel Mixer / 通道混合器，可分别配置红、绿、蓝输出通道的 RGB 混合矩阵与常数项。
- 通道混合器支持单色模式，可用红、绿、蓝权重生成灰阶，并继续作为非破坏式调整层参与蒙版、剪贴、History、撤销和向下合并链路。
- 补齐中 / 英 / 日三语通道混合器文案，并新增自动化覆盖 RGB 通道矩阵、单色模式、调整层参数保存和原像素不破坏。
- 统一前后端版本号：`AppVersion.current` 与 `MARKETING_VERSION` 对齐到 1.105.0。

## 1.104.0 - 2026-07-09

- 图片编辑器调整层新增 Photoshop 式 Hue/Saturation / 色相饱和度调整，支持色相、饱和度、明度和着色模式。
- 色相饱和度调整同时支持直接应用到像素图层与创建非破坏式调整层，并继续复用蒙版、剪贴、History、撤销和向下合并链路。
- 补齐中 / 英 / 日三语色相饱和度文案，并新增自动化覆盖色相偏移、着色模式、调整层参数保存和原像素不破坏。
- 统一前后端版本号：`AppVersion.current` 与 `MARKETING_VERSION` 对齐到 1.104.0。

## 1.103.0 - 2026-07-09

- 图片编辑器调整层新增 Black & White / 黑白调整，支持红、黄、绿、青、蓝、洋红六通道混合权重。
- 黑白调整同时支持直接应用到像素图层与创建非破坏式调整层，并继续复用蒙版、剪贴、History、撤销和向下合并链路。
- 补齐中 / 英 / 日三语黑白调整文案，并新增自动化覆盖六通道黑白转换、调整层参数保存和原像素不破坏。
- 统一前后端版本号：`AppVersion.current` 与 `MARKETING_VERSION` 对齐到 1.103.0。

## 1.102.0 - 2026-07-09

- 图片编辑器图层样式新增非破坏式 Inner Shadow / 内阴影效果，可按当前图层 alpha 在内部生成偏移柔化阴影。
- 内阴影支持属性面板不透明度、模糊、距离和角度控制，并继续参与 History、撤销、向下合并和栅格化链路。
- 补齐中 / 英 / 日三语内阴影样式文案，并新增自动化覆盖内阴影样式不破坏原像素与参数写入。
- 统一前后端版本号：`AppVersion.current` 与 `MARKETING_VERSION` 对齐到 1.102.0。

## 1.101.0 - 2026-07-09

- 图片编辑器图层样式新增非破坏式 Satin / 光泽效果，可在图层内部生成偏移柔化色带。
- 光泽效果支持属性面板不透明度、距离、大小和角度控制，并继续参与 History、撤销、向下合并和栅格化链路。
- 补齐中 / 英 / 日三语光泽样式文案，并新增自动化覆盖光泽样式不破坏原像素与参数写入。
- 统一前后端版本号：`AppVersion.current` 与 `MARKETING_VERSION` 对齐到 1.101.0。

## 1.100.0 - 2026-07-09

- 图片编辑器图层样式新增非破坏式图案叠加，首批支持棋盘、斜线和圆点三种内置图案。
- 图案叠加支持属性面板图案类型、不透明度和缩放控制，并继续参与 History、撤销、向下合并和栅格化链路。
- 补齐中 / 英 / 日三语图案叠加文案，并新增自动化覆盖图案叠加不破坏原像素与 Fill Opacity 为 0 时仍可见。
- 统一前后端版本号：`AppVersion.current` 与 `MARKETING_VERSION` 对齐到 1.100.0。

## 1.99.0 - 2026-07-09

- 图片编辑器图层样式新增非破坏式渐变叠加，可用当前前景色到背景色按图层 alpha 覆盖内容。
- 渐变叠加支持属性面板不透明度和角度控制，并继续参与 History、撤销、向下合并和栅格化链路。
- 补齐中 / 英 / 日三语图层样式文案，并新增自动化覆盖渐变叠加不破坏原像素与参数写入。
- 统一前后端版本号：`AppVersion.current` 与 `MARKETING_VERSION` 对齐到 1.99.0。

## 1.98.0 - 2026-07-09

- 图片编辑器图层样式新增非破坏式斜面浮雕，可按图层 alpha 生成高光和阴影边缘，增强按钮、文字和贴纸的立体效果。
- 图层样式命令从主 `ImageEditorViewModel.swift` 拆入 `ImageEditorLayerStyleCommands.swift`，降低主 ViewModel 行数，为继续扩展样式、通道和路径功能留出空间。
- 斜面浮雕支持属性面板尺寸和不透明度控制，并继续参与 History、撤销、向下合并和栅格化链路。
- 补齐中 / 英 / 日三语图层样式文案，并新增自动化覆盖斜面浮雕不破坏原像素与参数写入。
- 统一前后端版本号：`AppVersion.current` 与 `MARKETING_VERSION` 对齐到 1.98.0。

## 1.97.0 - 2026-07-09

- 图片编辑器图层样式新增非破坏式颜色叠加，可用当前前景色按图层 alpha 覆盖内容而不改写原始像素。
- 颜色叠加参与画布合成、History、撤销、向下合并和栅格化链路，并新增属性面板不透明度控制。
- 补齐中 / 英 / 日三语图层样式文案，并扩展自动化覆盖颜色叠加不破坏图层原像素与合并烘焙结果。
- 统一前后端版本号：`AppVersion.current` 与 `MARKETING_VERSION` 对齐到 1.97.0。

## 1.96.0 - 2026-07-09

- 图片编辑器新增修复画笔工具，可沿笔刷路径从周围未覆盖区域采样并混合回当前像素层，用于去除小瑕疵。
- 修复画笔复用选区裁切、透明像素锁、像素锁、History 和撤销链路，避免越过受保护区域。
- 新增独立 `ImageEditorHealingBrush.swift` 承载像素采样与混合算法，避免继续膨胀主 ViewModel。
- 补齐中 / 英 / 日三语工具、状态和历史文案，并新增自动化覆盖瑕疵修复与选区裁切。
- 统一前后端版本号：`AppVersion.current` 与 `MARKETING_VERSION` 对齐到 1.96.0。

## 1.95.0 - 2026-07-09

- 图片编辑器新增油漆桶工具，可按点击位置的种子颜色和容差填充当前像素层中的连续同色区域。
- 油漆桶填充复用像素替换保护链路，继续支持选区裁切、透明像素锁、像素锁、History 和撤销。
- 顶部参数栏为魔棒和油漆桶新增容差控制，并补齐中 / 英 / 日三语工具、状态和历史文案。
- 新增自动化覆盖油漆桶只填充连通区域，以及在存在选区时只改写选区内像素。
- 统一前后端版本号：`AppVersion.current` 与 `MARKETING_VERSION` 对齐到 1.95.0。

## 1.94.0 - 2026-07-09

- 图片编辑器选区命令新增全选、扩展选区和收缩选区，扩缩半径可在属性面板按像素调整。
- 扩展 / 收缩选区使用栅格 mask 形态学处理，并继续写入 History、状态栏和撤销链路。
- 补齐中 / 英 / 日三语选区命令文案，并新增自动化覆盖全选范围与扩缩选区 mask 变化。
- 统一前后端版本号：`AppVersion.current` 与 `MARKETING_VERSION` 对齐到 1.94.0。

## 1.93.0 - 2026-07-09

- 图片编辑器新增涂抹工具，可沿拖拽方向把上一位置附近的当前像素拖向下一位置，形成类似 Photoshop Smudge Tool 的局部颜色推移效果。
- 涂抹工具复用当前像素图层编辑保护链路，继续支持选区裁切、透明像素锁、像素锁、History 和撤销。
- 补齐中 / 英 / 日三语工具、状态和历史文案，并新增自动化覆盖颜色沿拖拽方向被带入相邻区域。
- 统一前后端版本号：`AppVersion.current` 与 `MARKETING_VERSION` 对齐到 1.93.0。

## 1.92.0 - 2026-07-09

- 图片编辑器新增锐化工具，可沿画笔路径局部增强当前像素图层的细节与边缘对比。
- 锐化工具与模糊工具共享笔刷 mask 混合管线，继续复用选区裁切、透明像素锁、像素锁、History 和撤销链路。
- 补齐中 / 英 / 日三语工具、状态和历史文案，并新增自动化覆盖局部锐化增强边缘对比且远处像素保持稳定。
- 统一前后端版本号：`AppVersion.current` 与 `MARKETING_VERSION` 对齐到 1.92.0。

## 1.91.0 - 2026-07-09

- 图片编辑器新增模糊工具，可沿画笔路径把当前像素图层局部混入高斯模糊结果。
- 模糊工具复用选区裁切、透明像素锁、像素锁、History 和撤销链路，避免破坏受保护区域。
- 局部模糊算法继续放在 `ImageEditorToneBrush.swift`，与减淡 / 加深共享笔刷 mask 思路，减少主 ViewModel 体积增长。
- 补齐中 / 英 / 日三语工具、状态和历史文案，并新增自动化覆盖局部模糊和未命中区域保持不变。
- 统一前后端版本号：`AppVersion.current` 与 `MARKETING_VERSION` 对齐到 1.91.0。

## 1.90.0 - 2026-07-09

- 图片编辑器新增减淡和加深工具，可沿画笔路径对当前像素图层局部提亮或压暗。
- 减淡 / 加深使用真实像素级笔触 mask，并保持 alpha 不变，继续复用选区裁切、透明像素锁、像素锁、History 和撤销链路。
- 新增独立 `ImageEditorToneBrush.swift` 承载底层色调笔刷算法，避免继续膨胀主 ViewModel。
- 补齐中 / 英 / 日三语工具、状态和历史文案，并新增自动化覆盖减淡、加深和未命中区域保持不变。
- 统一前后端版本号：`AppVersion.current` 与 `MARKETING_VERSION` 对齐到 1.90.0。

## 1.89.0 - 2026-07-08

- 品牌英文名升级为 QPic，应用产物名、脚本卷标和关于页展示统一到 `QPic.app` / 轻图。
- 关于页和推荐体系继续把图片编辑、截图、图片上传分享能力收口到轻图，不再引导到 MuseSnip / 简图。
- 图片编辑器新增仿制图章工具，可在当前像素图层内设置取样点并沿拖拽路径克隆像素。
- 仿制图章写入 History，并复用选区裁切、透明像素锁和图层像素锁保护，避免破坏受保护区域。
- 仿制图章编辑会保留当前图层 frame，不会把已移动图层重置回画布原点。
- 补齐中 / 英 / 日三语工具、状态和历史文案，并新增自动化覆盖像素取样克隆行为。
- 统一前后端版本号：`AppVersion.current` 与 `MARKETING_VERSION` 对齐到 1.89.0。

## 1.88.0 - 2026-07-08

- 图片编辑器图层蒙版新增链接 / 取消链接状态，可控制蒙版是否跟随图层内容一起移动。
- 图层移动时，取消链接的蒙版会按反方向偏移，保持蒙版在画布中的可见位置更稳定，便于单独调整内容与遮罩关系。
- 图层行在内容缩略图和蒙版缩略图之间显示链接 / 断链状态，图层操作栏新增蒙版链接切换按钮。
- 添加、删除或应用图层蒙版时会重置蒙版链接状态，避免残留状态污染下一次蒙版编辑。
- 补齐中 / 英 / 日三语蒙版链接文案，并新增自动化覆盖链接状态切换和取消链接后移动图层的视觉行为。
- 统一前后端版本号：`AppVersion.current` 与 `MARKETING_VERSION` 对齐到 1.88.0。

## 1.87.0 - 2026-07-08

- 图片编辑器图层蒙版新增启用 / 停用开关，可临时忽略 mask 查看完整图层内容。
- 停用蒙版会影响普通图层、图层组、调整层和滤镜层的统一合成路径；重新启用后会恢复原始蒙版、密度和羽化参数。
- 图层行的蒙版缩略图在停用时显示红色斜线提示，操作栏新增蒙版启停按钮。
- 应用停用状态下的蒙版时会按当前可见结果烘焙，移除 mask 并保留未蒙版内容。
- 补齐中 / 英 / 日三语蒙版启停文案，并新增自动化覆盖蒙版停用、恢复和停用后应用行为。
- 统一前后端版本号：`AppVersion.current` 与 `MARKETING_VERSION` 对齐到 1.87.0。

## 1.86.0 - 2026-07-08

- 图片编辑器图层蒙版新增非破坏式 Density（密度）和 Feather（羽化）控制。
- 图层、图层组、调整层、滤镜层和剪贴效果都会使用同一套有效蒙版结果，保证预览、导出和合并逻辑一致。
- 应用图层蒙版时会烘焙密度与羽化后的有效 mask，删除或重建蒙版会重置蒙版属性。
- 补齐中 / 英 / 日三语蒙版属性文案，并新增自动化覆盖蒙版密度、羽化和应用蒙版烘焙。
- 统一前后端版本号：`AppVersion.current` 与 `MARKETING_VERSION` 对齐到 1.86.0。

## 1.85.0 - 2026-07-08

- 图片编辑器图层新增 Fill（填充不透明度），可独立于 Opacity 调整图层本体内容透明度。
- 图层样式合成会保留描边、投影、外发光和内发光效果，Fill 降低到 0 时仍可保留图层样式可见性，更接近 Photoshop 的图层行为。
- 图层复制、选区复制 / 剪切新建图层、合并、栅格化和扁平化流程会正确保留或烘焙 Fill 状态。
- 补齐中 / 英 / 日三语 Fill 文案，并新增自动化覆盖 Fill 与 Opacity 的差异。
- 统一前后端版本号：`AppVersion.current` 与 `MARKETING_VERSION` 对齐到 1.85.0。

## 1.84.0 - 2026-07-08

- 图片编辑器图层面板新增分项锁定：像素锁和位置锁，可与原有总锁、透明像素锁并行使用。
- 像素锁会阻止画笔、渐变、选区填充 / 清除 / 剪切、像素调整、滤镜更新、智能滤镜管理、栅格化和应用蒙版等内容改写操作。
- 位置锁会阻止移动、缩放、旋转和对齐，图层组上的分项锁会递归影响组内后代图层。
- 补齐中 / 英 / 日三语图层分项锁文案，并新增自动化覆盖锁定后的编辑保护。
- 统一前后端版本号：`AppVersion.current` 与 `MARKETING_VERSION` 对齐到 1.84.0。

## 1.83.0 - 2026-07-08

- 图片编辑器智能滤镜栈支持逐项管理，可对每个智能滤镜单独启用 / 关闭、更新参数、上移、下移或删除。
- 属性面板会展开显示当前图层的智能滤镜列表，停用滤镜会在列表摘要和行内状态中明确标注。
- 智能滤镜逐项操作全部写入 History 和撤销链路，继续保持对原图层内容的非破坏式编辑。
- 补齐中 / 英 / 日三语智能滤镜栈管理文案，并新增自动化覆盖逐项开关、排序和删除。
- 统一前后端版本号：`AppVersion.current` 与 `MARKETING_VERSION` 对齐到 1.83.0。

## 1.82.0 - 2026-07-08

- 图片编辑器新增图层级智能滤镜栈，普通像素 / 文字 / 形状图层可挂载高斯模糊或锐化并保持原始内容不变。
- 属性面板新增智能滤镜状态、添加、更新最后一个滤镜和清空滤镜操作，滤镜参数继续复用现有滤镜选择与强度控件。
- 栅格化、向下合并、合并可见图层和扁平化图像会把智能滤镜烘焙成普通像素并清空非破坏式滤镜状态，避免重复应用。
- 补齐中 / 英 / 日三语智能滤镜文案，并新增自动化覆盖非破坏预览、清空恢复、栅格化烘焙和合并不重复滤镜。
- 统一前后端版本号：`AppVersion.current` 与 `MARKETING_VERSION` 对齐到 1.82.0。

## 1.81.0 - 2026-07-08

- 图片编辑器矩形和椭圆工具改为创建非破坏式形状图层，保留形状类型、填充、描边宽度和不透明度参数。
- 形状图层接入图层缩略图、属性面板描述、图层徽标、更新形状、蒙版、混合、样式、合并和栅格化流程。
- 补齐中 / 英 / 日三语形状图层文案，并新增自动化覆盖形状层创建、更新、非破坏像素保持和栅格化视觉一致性。
- 统一前后端版本号：`AppVersion.current` 与 `MARKETING_VERSION` 对齐到 1.81.0。

## 1.80.0 - 2026-07-08

- 图片编辑器调整层和滤镜层支持剪贴到下方图层，可像普通像素层一样使用图层剪贴蒙版限制作用范围。
- 调整层 / 滤镜层合成时会把自身蒙版、组蒙版和下方基底 alpha 合并成画布级 effect mask，避免效果污染基底外区域。
- 剪贴调整层 / 滤镜层向下合并时会复用同一套本地 effect mask，确保预览结果与烘焙后的像素结果一致。
- 新增自动化覆盖剪贴调整层的非破坏预览、向下合并一致性，以及剪贴滤镜层的基底 alpha 限制。
- 统一前后端版本号：`AppVersion.current` 与 `MARKETING_VERSION` 对齐到 1.80.0。

## 1.79.0 - 2026-07-08

- 图片编辑器图层合成切换为像素级 RGBA 混合后端，不再受 AppKit 有限 `NSCompositingOperation` 支持范围约束。
- 图层混合模式新增线性减淡、线性加深、亮光、线性光、点光、排除、色相、饱和度、颜色和明度等 Photoshop 常用模式。
- 新混合后端会处理图层不透明度、底图 alpha、上层 alpha、组不透明度、组蒙版和剪贴蒙版后的画布级合成。
- 补齐中 / 英 / 日三语混合模式名称，并新增自动化覆盖线性减淡、线性加深和颜色模式的像素结果。
- 统一前后端版本号：`AppVersion.current` 与 `MARKETING_VERSION` 对齐到 1.79.0。

## 1.78.0 - 2026-07-08

- 图片编辑器图层样式新增非破坏式内发光，可在图层工具栏作为 `fx` 能力开关并叠加到图层内部可见像素。
- 内发光支持不透明度、模糊和阻塞参数，属性面板可直接调整并写入 History。
- 内发光与描边、投影、外发光共用图层样式管线，合并图层时会烘焙到像素层，合并前保持原始图层像素不变。
- 自动化覆盖内发光开关、参数更新、锁定保护、非破坏合成和合并烘焙流程。
- 统一前后端版本号：`AppVersion.current` 与 `MARKETING_VERSION` 对齐到 1.78.0。

## 1.77.0 - 2026-07-08

- 图片编辑器图层样式新增非破坏式外发光，可在图层工具栏通过 `fx` 能力开关并参与合成预览。
- 外发光支持不透明度、模糊和扩展参数，属性面板可直接调整并写入 History。
- 外发光与现有描边、投影共用图层样式管线，合并图层时会烘焙到像素层，原始图层像素在合并前保持不变。
- 新增自动化覆盖外发光开关、参数更新、锁定保护、非破坏合成和合并烘焙流程。
- 统一前后端版本号：`AppVersion.current` 与 `MARKETING_VERSION` 对齐到 1.77.0。

## 1.76.0 - 2026-07-08

- 图片编辑器图层组支持非破坏式组蒙版，可直接给组添加蒙版、从当前选区创建组蒙版、编辑、反相和删除。
- 组合成时会把祖先组蒙版递归叠加到后代像素层、剪贴层、调整层和滤镜层，父组蒙版会裁切整个组的可见结果。
- 组选中添加蒙版时使用画布尺寸，确保组内不同位置的子图层按同一个画布空间蒙版被裁切。
- 新增自动化覆盖组蒙版从选区创建、合成裁切、反相和删除流程。
- 统一前后端版本号：`AppVersion.current` 与 `MARKETING_VERSION` 对齐到 1.76.0。

## 1.75.0 - 2026-07-08

- 图片编辑器图层组支持嵌套：同一父组下的图层或子组可再次编组，图层面板按组深度缩进显示。
- 父组的可见性、锁定状态、不透明度和折叠状态会递归影响所有子组与后代图层。
- 图层组复制、删除、解组、组选中移动 / 缩放 / 旋转会递归处理后代图层，并在复制时重建父子组 ID 关系。
- 新增单元测试覆盖父组折叠、层级复制、深层成员变换和解组保留子组关系。
- 统一前后端版本号：`AppVersion.current` 与 `MARKETING_VERSION` 对齐到 1.75.0。

## 1.74.0 - 2026-07-08

- 图片编辑器图层组继续补齐：复制选中图层组时会连同组内成员一起复制，并为副本重建新的组关系。
- 选中图层组进行移动、缩放或旋转时，会自动把组内可变换成员纳入统一变换集合。
- 组复制会清理副本的旧链接关系，避免副本意外牵连原图层链接组。
- 新增单元测试覆盖图层组复制、成员归属保持、组级移动和组级缩放。
- 统一前后端版本号：`AppVersion.current` 与 `MARKETING_VERSION` 对齐到 1.74.0。

## 1.73.0 - 2026-07-08

- 图片编辑器图层组继续补齐：图层面板支持展开 / 折叠组，并在折叠时隐藏组内成员行。
- 新增“选择组内图层”和“解散所选图层组”命令，解组后会保留成员图层并恢复成员多选状态。
- 折叠组时若当前选中组内成员，会自动回到组选中状态，避免隐藏行仍处于主选中状态。
- 补齐中 / 英 / 日三语图层组文案，并新增单元测试覆盖折叠、选择组成员、解组与撤销恢复。
- 统一前后端版本号：`AppVersion.current` 与 `MARKETING_VERSION` 对齐到 1.73.0。

## 1.72.0 - 2026-07-08

- 图片编辑器图层面板新增六向对齐能力：左对齐、水平居中、右对齐、顶端对齐、垂直居中和底端对齐。
- 对齐操作复用当前可变换图层集合，支持多选图层，也支持仅选中链接组中一个图层时带入同组链接图层。
- 对齐操作会跳过锁定、不可见、组、调整层和滤镜层，并纳入 History 与撤销链路。
- 补齐中 / 英 / 日三语对齐文案，并新增单元测试覆盖多选对齐与链接图层对齐。
- 统一前后端版本号：`AppVersion.current` 与 `MARKETING_VERSION` 对齐到 1.72.0。

## 1.71.0 - 2026-07-08

- 图片编辑器图层链接继续补齐：属性面板的缩放操作会基于链接组统一边界框缩放同组可变换图层。
- 复制图层时会清空复制品的旧链接关系，避免副本意外带动原链接组。
- 删除图层后会规范化剩余图层链接，自动清理指向已删除图层的引用。
- 新增单元测试覆盖链接组缩放、复制不继承链接、删除清理链接关系。
- 统一前后端版本号：`AppVersion.current` 与 `MARKETING_VERSION` 对齐到 1.71.0。

## 1.70.0 - 2026-07-08

- 图片编辑器图层面板新增“链接所选图层”和“解除链接”，图层行会显示已链接状态。
- 图层链接关系写入 `ImageEditorLayer` 模型并保持对称，移动当前图层时会带动同一链接组内的可变换图层一起移动。
- 链接图层参与画布变换框计算，为后续补齐更完整的链接缩放、旋转和复杂图层编排能力铺路。
- 补齐中 / 英 / 日三语图层链接文案，并新增单元测试覆盖链接移动与解除链接后的独立移动。
- 统一前后端版本号：`AppVersion.current` 与 `MARKETING_VERSION` 对齐到 1.70.0。

## 1.69.0 - 2026-07-08

- 图片编辑器调整能力新增“色彩平衡”，支持暗部、中间调和高光三段分别调节青色 / 红色、洋红 / 绿色、黄色 / 蓝色。
- 色彩平衡可直接应用到当前像素图层，也可作为非破坏式调整层参与图层合成、蒙版和向下合并。
- 色彩平衡参数纳入 `ImageEditorAdjustmentSettings`，与色阶、曲线共享扩展调整层参数模型。
- 补齐中 / 英 / 日三语色彩平衡文案，并新增单元测试覆盖直接应用、非破坏式图层参数保存和底层像素不变。
- 统一前后端版本号：`AppVersion.current` 与 `MARKETING_VERSION` 对齐到 1.69.0。

## 1.68.0 - 2026-07-08

- 图片编辑器图层面板新增“锁定透明像素”，普通像素层可在图层行直接切换。
- 锁定透明像素后，画笔、橡皮、形状、渐变和直接调整等破坏式像素编辑会保留原图层 alpha，避免把透明区域涂出新内容或把已有不透明区域擦成透明。
- 新增像素级 `preservingAlpha` 合成路径，确保透明像素锁不是只停留在 UI 状态。
- 补齐中 / 英 / 日三语透明像素锁文案，并新增单元测试覆盖画笔和橡皮对图层 alpha 的约束。
- 统一前后端版本号：`AppVersion.current` 与 `MARKETING_VERSION` 对齐到 1.68.0。

## 1.67.0 - 2026-07-08

- 图片编辑器调整能力新增“曲线”，支持暗部、中间调和高光三段平滑色调曲线控制。
- 曲线可直接应用到当前像素图层，也可作为非破坏式调整层参与图层合成、蒙版和向下合并。
- 曲线参数纳入 `ImageEditorAdjustmentSettings`，与色阶共享扩展调整层参数模型，为后续更完整曲线点编辑继续铺路。
- 补齐中 / 英 / 日三语曲线文案，并新增单元测试覆盖曲线直接应用、非破坏式图层参数保存和底层像素不变。
- 统一前后端版本号：`AppVersion.current` 与 `MARKETING_VERSION` 对齐到 1.67.0。

## 1.66.0 - 2026-07-08

- 图片编辑器调整能力新增“色阶”，支持黑场、中间调 Gamma 和白场三参数控制。
- 色阶可直接应用到当前像素图层，也可作为非破坏式调整层参与图层合成、蒙版和向下合并。
- 新增 `ImageEditorAdjustmentSettings` 保存调整层扩展参数，并将调整像素算法拆入独立模块，为后续曲线、色彩平衡等 Photoshop 式调整继续扩展。
- 补齐中 / 英 / 日三语色阶文案，并新增单元测试覆盖色阶直接应用、非破坏式图层参数保存和底层像素不变。
- 统一前后端版本号：`AppVersion.current` 与 `MARKETING_VERSION` 对齐到 1.66.0。

## 1.65.0 - 2026-07-08

- 图片编辑器调整能力新增曝光、色相、反相和阈值四种 Photoshop 常用调整。
- 新增调整既可直接应用到当前像素图层，也可作为非破坏式调整图层参与合成、蒙版和向下合并。
- 阈值调整使用像素级实现，避免依赖系统 Core Image 阈值滤镜可用性。
- 补齐中 / 英 / 日三语调整名称，并新增单元测试覆盖反相、阈值和曝光调整层结果。
- 统一前后端版本号：`AppVersion.current` 与 `MARKETING_VERSION` 对齐到 1.65.0。

## 1.64.0 - 2026-07-08

- 图片编辑器选区工具新增“新建 / 添加 / 减去 / 相交”四种选区组合模式，矩形选区、套索和魔棒共用同一套布尔逻辑。
- 组合后的选区会输出真实栅格 mask，后续填充、描边、清除像素、复制 / 剪切新建图层和图层蒙版都会沿用组合结果。
- 工具选项栏新增选区模式分段控制，并补齐中 / 英 / 日三语文案。
- 新增选区布尔运算单元测试，覆盖加选、减选、相交后的 mask 像素和 History 记录。
- 统一前后端版本号：`AppVersion.current` 与 `MARKETING_VERSION` 对齐到 1.64.0。

## 1.63.0 - 2026-07-08

- 图片编辑器魔棒工具升级为连续区域选区，从点击像素开始按颜色容差做 4 邻域 flood fill。
- 魔棒选区现在输出真实栅格 mask，可区分同色但不相连的区域，避免把画面中所有相似颜色粗暴框到一起。
- 新增魔棒连续区域单元测试，覆盖相同颜色分离区域、mask 像素结果和 History 记录。
- 统一前后端版本号：`AppVersion.current` 与 `MARKETING_VERSION` 对齐到 1.63.0。

## 1.62.0 - 2026-07-08

- 图片编辑器渐变工具改为真实拖拽渐变，可按画布拖拽起点和终点决定渐变方向。
- 渐变编辑会写入当前像素图层，并继续尊重当前选区、选区羽化和背景色透明度。
- 编辑图层蒙版时，渐变工具会写入真实 alpha 渐变，可用于渐隐遮罩而不是只画黑白像素。
- 新增渐变工具单元测试，覆盖拖拽方向、选区限制、撤销恢复和蒙版 alpha 结果。
- 统一前后端版本号：`AppVersion.current` 与 `MARKETING_VERSION` 对齐到 1.62.0。

## 1.61.0 - 2026-07-08

- 图片编辑器选区操作新增“清除选区像素”，可直接把当前像素图层选区内内容擦为透明。
- 新增“选区剪切为层”，会把当前选区内容生成上方新图层，并从原图层中清除对应像素。
- 选区剪切、清除像素继续纳入 History 与撤销链路，并复用选区羽化 / 栅格选区 mask。
- 新增选区清除与剪切单元测试，覆盖源图层透明化、新图层像素结果和撤销恢复。
- 统一前后端版本号：`AppVersion.current` 与 `MARKETING_VERSION` 对齐到 1.61.0。

## 1.60.0 - 2026-07-08

- 新增“关于轻图”独立窗口，系统 App 菜单可直接打开，展示 App 图标、版本号、作者主页和轻图产品页。
- 补齐关于窗口中 / 英 / 日三语本地化文案，避免窗口标题、按钮和说明直接写死在 Swift 里。
- 统一前后端版本号：`AppVersion.current` 与 `MARKETING_VERSION` 对齐到 1.60.0。

## 1.59.0 - 2026-07-08

- 图片编辑器“导出”升级为导出设置面板，可选择 PNG、JPEG 或 WebP 格式。
- 导出支持选择合成图像或当前图层，并可设置 0.25x 到 4x 输出倍率；当前图层导出保留透明画布与图层位置。
- JPEG 导出会自动铺白透明背景，WebP 在系统不支持写入时给出明确状态提示。
- 补齐“选区复制为层”的三语图层命名文案，避免新图层名称落回本地化 key。
- 新增导出单元测试，覆盖当前图层 PNG 透明导出、倍率输出和合成 JPEG 编码。
- 统一前后端版本号：`AppVersion.current` 与 `MARKETING_VERSION` 对齐到 1.59.0。

## 1.58.0 - 2026-07-08

- 图片编辑器属性面板新增选区填充，可用当前前景色和不透明度直接填充当前选区。
- 新增选区描边，复用当前画笔大小、前景色和不透明度沿选区边界绘制。
- 新增“选区复制为层”，可将当前图层的选区内容复制成上方的新普通像素图层，保留原图层不变。
- 新增选区编辑单元测试，覆盖填充、描边、复制为新图层、像素范围和撤销恢复。
- 统一前后端版本号：`AppVersion.current` 与 `MARKETING_VERSION` 对齐到 1.58.0。

## 1.57.0 - 2026-07-08

- 图片编辑器图层面板新增“从选区添加蒙版”，可把当前矩形、套索、魔棒或栅格选区转换为当前图层的真实 alpha 蒙版。
- 新增图层蒙版反相和应用操作：反相会翻转可见 / 隐藏区域，应用会把蒙版破坏式烘焙进图层像素并移除蒙版。
- 栅格选区蒙版改为真实 alpha mask，非连续透明度选区在图层蒙版和局部编辑中不再依赖灰度图合成假设。
- 新增图层蒙版单元测试，覆盖选区生成蒙版、蒙版反相、应用蒙版和撤销恢复。
- 统一前后端版本号：`AppVersion.current` 与 `MARKETING_VERSION` 对齐到 1.57.0。

## 1.56.0 - 2026-07-08

- 图片编辑器新增“载入图层透明度”，可从当前像素 / 文字图层的 alpha 生成栅格选区，用于后续画笔、擦除和局部处理。
- 选区模型新增栅格蒙版能力，载入透明度选区不再退化成外接矩形，能按真实 alpha 像素限制编辑范围。
- 属性面板新增保存选区与恢复选区，可在清除或切换操作后取回最近保存的选区，并纳入撤销与 History。
- 新增选区单元测试，覆盖从图层透明度生成栅格选区、选区保存恢复和撤销恢复。
- 统一前后端版本号：`AppVersion.current` 与 `MARKETING_VERSION` 对齐到 1.56.0。

## 1.55.0 - 2026-07-08

- 图片编辑器图层面板新增“合并可见图层”，可将当前所有可见图层破坏式合成为一个普通像素层，并保留隐藏图层。
- 新增“扁平化图像”，可把当前视觉结果收成单一像素图层，并丢弃隐藏图层、组、调整层、滤镜层等结构状态。
- 新增图层合并单元测试，覆盖可见合并、隐藏图层保留、扁平化丢弃隐藏图层、视觉结果保持和撤销恢复。
- 统一前后端版本号：`AppVersion.current` 与 `MARKETING_VERSION` 对齐到 1.55.0。

## 1.54.0 - 2026-07-08

- 图片编辑器图层面板新增“栅格化当前图层”，可将文字层、图层蒙版和图层样式烘焙成普通像素图层。
- 栅格化会保留图层 id、选中状态、透明度、混合模式和可见性，并把文字对象、蒙版、描边与投影转为像素内容。
- 新增栅格化单元测试，覆盖文字层样式烘焙、视觉合成保持和撤销恢复可编辑文字层。
- 统一前后端版本号：`AppVersion.current` 与 `MARKETING_VERSION` 对齐到 1.54.0。

## 1.53.0 - 2026-07-08

- 图片编辑器图层面板新增“导入图片为图层”，可从本地选择图片并作为新的像素图层加入当前画布。
- 导入图片会保留原始像素尺寸，并在画布内自动等比适配居中，导入后立即选中新图层并进入撤销与 History。
- 新增导入图片图层单元测试，覆盖图层名称、适配 frame、选中状态、历史记录和撤销恢复。
- 统一前后端版本号：`AppVersion.current` 与 `MARKETING_VERSION` 对齐到 1.53.0。

## 1.52.0 - 2026-07-08

- 图片编辑器图层面板新增置顶与置底操作，多选图层可保持相对顺序移动到图层栈边界。
- 图层操作按钮行改为横向滚动，避免图层、蒙版、效果和栈顺序按钮继续增加后挤出面板。
- 新增多选图层置顶/置底单元测试，覆盖顺序保持、选中状态和撤销恢复。
- 统一前后端版本号：`AppVersion.current` 与 `MARKETING_VERSION` 对齐到 1.52.0。

## 1.51.0 - 2026-07-08

- 图片编辑器图层面板新增“盖印可见图层”，可把当前所有可见图层的合成结果烘焙成一个新的普通像素层。
- 盖印操作会保留原有图层栈和隐藏图层，方便继续做非破坏式编辑，同时写入 History 与撤销栈。
- 新增盖印可见图层单元测试，覆盖隐藏层不参与盖印、新盖印层像素结果和撤销恢复。
- 统一前后端版本号：`AppVersion.current` 与 `MARKETING_VERSION` 对齐到 1.51.0。

## 1.50.0 - 2026-07-08

- 图片编辑器属性面板新增图层重命名能力，选中图层、图层组、文字层、调整层和滤镜层后可直接修改名称。
- 图层重命名会自动去除首尾空白、拒绝空名称，并写入 History 与撤销栈。
- 新增图层重命名单元测试，覆盖 trim、空名称拒绝和撤销恢复。
- 统一前后端版本号：`AppVersion.current` 与 `MARKETING_VERSION` 对齐到 1.50.0。

## 1.49.0 - 2026-07-08

- 图片编辑器将图层移动、缩放、旋转和多选统一变换逻辑拆分到独立的 `ImageEditorTransform` 模块，降低 `ImageEditorViewModel` 继续承载图层能力时的维护压力。
- `ImageEditorViewModel` 行数降至 2000 行以内，后续图层混合、蒙版、选区、历史等复杂能力可以按模块继续拆分。
- 统一前后端版本号：`AppVersion.current` 与 `MARKETING_VERSION` 对齐到 1.49.0。

## 1.48.0 - 2026-07-08

- 图片编辑器多选图层现在会在画布上显示统一变换边界框，边界取所有可见、可变换选中图层的 frame 并集。
- 移动工具、八方向缩放句柄和旋转手柄支持同时变换多个选中图层；缩放会按多选边界比例调整每个图层 frame，旋转会围绕多选边界中心处理每个图层。
- 属性面板旋转按钮支持多选图层，并复用画布旋转的批量变换实现。
- 新增多选图层移动、缩放、旋转和撤销恢复单元测试。
- 统一前后端版本号：`AppVersion.current` 与 `MARKETING_VERSION` 对齐到 1.48.0。

## 1.47.0 - 2026-07-08

- 图片编辑器图层变换框新增画布旋转手柄，可直接拖拽围绕图层中心旋转当前图层。
- 拖拽旋转时支持按住 Shift 按 15° 步进吸附，并从原始图层快照实时重算，减少连续拖动带来的重复重采样损耗。
- 新增画布旋转手柄、Shift 吸附和撤销恢复单元测试。
- 统一前后端版本号：`AppVersion.current` 与 `MARKETING_VERSION` 对齐到 1.47.0。

## 1.46.0 - 2026-07-08

- 图片编辑器图层变换框从四角缩放扩展为八方向缩放，新增上、下、左、右边线中点句柄。
- 拖拽缩放句柄时支持按住 Shift 保持原始宽高比；边线句柄会以中心线为锚点补齐另一方向尺寸。
- 新增边线句柄缩放和 Shift 等比缩放单元测试。
- 统一前后端版本号：`AppVersion.current` 与 `MARKETING_VERSION` 对齐到 1.46.0。

## 1.45.0 - 2026-07-08

- 图片编辑器画布新增当前图层变换边界框，可在选中普通像素层或文字层时直接看到图层 frame。
- 未锁定图层的边界框新增四角缩放句柄，拖拽句柄会实时调整图层 frame，结束后写入撤销历史。
- 文字图层改为按文字内容测量尺寸生成对象层，边界框不再覆盖整张画布，后续移动和缩放更贴近真实编辑器对象逻辑。
- 新增拖拽缩放图层单元测试，覆盖 frame 更新、历史记录和撤销恢复。
- 统一前后端版本号：`AppVersion.current` 与 `MARKETING_VERSION` 对齐到 1.45.0。

## 1.44.0 - 2026-07-08

- 图片编辑器文字工具改为创建可编辑文字图层，文字内容、颜色、字号和点击落点会以图层对象保存，而不是一次性写入像素。
- 文字图层参与画布合成、显隐、不透明度、混合模式、图层蒙版、图层样式、移动和向下合并；合并后会烘焙为普通像素层。
- 属性面板新增文字字号控制和更新当前文字图层按钮，图层列表新增文字图层徽标。
- 新增文字图层创建、更新和向下合并单元测试。
- 统一前后端版本号：`AppVersion.current` 与 `MARKETING_VERSION` 对齐到 1.44.0。

## 1.43.0 - 2026-07-08

- 图片编辑器选区羽化参数开始参与实际像素编辑，画笔、文字、形状、渐变和直接调整在有选区时会通过羽化蒙版柔和过渡。
- 属性面板新增反选操作，可将当前矩形、套索或魔棒选区切换为外部区域，并写入历史快照与撤销链路。
- 新增选区反选和羽化编辑单元测试，覆盖选区内部、边缘过渡与外部区域的像素变化。
- 统一前后端版本号：`AppVersion.current` 与 `MARKETING_VERSION` 对齐到 1.43.0。

## 1.42.0 - 2026-07-08

- 图片编辑器新增非破坏式滤镜图层第一批能力，支持高斯模糊和锐化作为独立图层影响其下方已合成画布。
- 滤镜图层支持显示 / 隐藏、透明度、重排、复制、删除、蒙版和参数更新，并可向下合并烘焙为普通像素层。
- 图层合成、剪贴蒙版基底判断和图层编辑约束已识别滤镜层，避免把滤镜层误当普通像素层编辑或剪贴。
- 新增滤镜图层非破坏合成、参数更新和向下合并单元测试。
- 统一前后端版本号：`AppVersion.current` 与 `MARKETING_VERSION` 对齐到 1.42.0。

## 1.41.0 - 2026-07-08

- 调整图层支持图层蒙版，可通过已有蒙版缩略图进入蒙版编辑，使用画笔隐藏调整效果、橡皮恢复调整效果。
- 调整图层蒙版参与画布合成、导出预览和向下合并；合并时会按蒙版约束后的当前视觉结果烘焙到下方像素层。
- 新增调整图层蒙版约束效果和合并烘焙单元测试。
- 统一前后端版本号：`AppVersion.current` 与 `MARKETING_VERSION` 对齐到 1.41.0。

## 1.40.0 - 2026-07-08

- 图片编辑器新增非破坏式调整图层第一批能力，可基于当前属性面板的亮度、对比度、饱和度、模糊和锐化参数创建调整图层。
- 调整图层按图层顺序影响其下方已合成画布，可显示 / 隐藏、调整不透明度、重排、复制、删除、成组，并可更新参数。
- 调整图层向下合并时会把当前调整效果烘焙到下方像素层，底层像素在合并前保持不变。
- 新增调整图层非破坏合成、参数更新和合并烘焙单元测试。
- 统一前后端版本号：`AppVersion.current` 与 `MARKETING_VERSION` 对齐到 1.40.0。

## 1.39.0 - 2026-07-08

- 图片编辑器图层面板新增多选状态，支持通过扩展选择同时选中多个图层。
- 多选图层可批量成组、复制、删除和上下移动，主选中图层继续用于画笔、蒙版、样式和属性编辑。
- 历史快照会保存并恢复多选集合，撤销 / 历史回跳不会丢失图层选择状态。
- 新增图层多选成组、删除和撤销恢复单元测试。
- 统一前后端版本号：`AppVersion.current` 与 `MARKETING_VERSION` 对齐到 1.39.0。

## 1.38.0 - 2026-07-08

- 图片编辑器剪贴蒙版支持连续剪贴链，多个剪贴图层会共享下方最近的非剪贴像素基底。
- 向下合并会按当前剪贴后的视觉结果烘焙像素，避免剪贴图层合并后整层外溢或视觉变化。
- 新增剪贴蒙版链式基底和合并烘焙单元测试。
- 统一前后端版本号：`AppVersion.current` 与 `MARKETING_VERSION` 对齐到 1.38.0。

## 1.37.0 - 2026-07-08

- 图片编辑器新增剪贴蒙版第一批能力，当前像素图层可剪贴到下方同组或同级的最近像素图层透明度。
- 剪贴蒙版参与画布合成、导出预览和图层组显隐 / 透明度链路，并在图层行显示剪贴标记。
- 图层面板新增剪贴蒙版 icon 操作，锁定图层或无可用基底层时不可开启。
- 新增剪贴蒙版相关简体中文、英语、日语本地化文案和单元测试。
- 统一前后端版本号：`AppVersion.current` 与 `MARKETING_VERSION` 对齐到 1.37.0。

## 1.36.0 - 2026-07-08

- 图片编辑器图层面板新增图层组第一批能力，支持新建空组和将当前图层放入新组。
- 图层组可控制子图层显隐、透明度和锁定状态；锁定组后子图层不可继续绘制或调整。
- 删除图层组会同步删除组内子图层，避免留下无归属的隐藏结构。
- 新增图层组相关简体中文、英语、日语本地化文案和单元测试。
- 统一前后端版本号：`AppVersion.current` 与 `MARKETING_VERSION` 对齐到 1.36.0。

## 1.35.0 - 2026-07-08

- 图片编辑器图层样式新增参数控制，可在属性面板调整描边宽度、投影不透明度、投影模糊和 X/Y 偏移。
- 调整图层样式参数会自动启用对应描边或投影效果，并写入撤销历史；锁定图层继续拒绝样式修改。
- 新增图层样式参数相关简体中文、英语、日语本地化文案和单元测试。
- 统一前后端版本号：`AppVersion.current` 与 `MARKETING_VERSION` 对齐到 1.35.0。

## 1.34.0 - 2026-07-08

- 图片编辑器图层新增非破坏式图层样式第一批能力，支持描边和投影开关。
- 图层样式参与画布合成、导出预览和向下合并；向下合并会把样式烘焙进像素并清空合并层的非破坏式样式状态。
- 图层面板新增描边、投影 icon 按钮，并在带样式的图层行显示 `fx` 标记。
- 新增图层样式相关简体中文、英语、日语本地化文案和单元测试。
- 统一前后端版本号：`AppVersion.current` 与 `MARKETING_VERSION` 对齐到 1.34.0。

## 1.33.0 - 2026-07-08

- 图片编辑器选中图层新增基础自由变换能力，可围绕图层中心缩放，并可按 15° 步进旋转当前图层。
- 图层旋转会同步旋转像素内容与图层蒙版，并将新的外接框保持在原图层中心。
- 属性面板新增图层缩放、图层左右旋转和当前图层几何信息显示。
- 新增图层变换相关简体中文、英语、日语本地化文案和单元测试。
- 统一前后端版本号：`AppVersion.current` 与 `MARKETING_VERSION` 对齐到 1.33.0。

## 1.32.0 - 2026-07-08

- 图片编辑器 History 面板新增真实历史状态快照，点击任意历史项可恢复到当时的完整图层文档状态。
- 历史状态回跳会作为新的可撤销操作写入历史，当前状态在面板中以选中样式标记。
- 新增历史状态恢复相关简体中文、英语、日语本地化文案和单元测试。
- 统一前后端版本号：`AppVersion.current` 与 `MARKETING_VERSION` 对齐到 1.32.0。

## 1.31.0 - 2026-07-08

- 图片编辑器移动工具改为移动当前选中图层内容，手形工具继续负责平移画布。
- 移动图层会写入撤销历史，锁定图层不会被移动。
- 新增移动图层相关简体中文、英语、日语本地化文案和单元测试。
- 统一前后端版本号：`AppVersion.current` 与 `MARKETING_VERSION` 对齐到 1.31.0。

## 1.30.0 - 2026-07-08

- 图片编辑器图层新增像素图层蒙版，支持添加、删除、选择蒙版缩略图进入蒙版编辑。
- 蒙版会参与画布合成、导出和向下合并；画笔在蒙版上隐藏区域，橡皮在蒙版上恢复区域，并支持选区约束。
- 图层旋转、翻转时会同步变换蒙版，避免内容与蒙版错位。
- 新增图层蒙版相关简体中文、英语、日语本地化文案。
- 统一前后端版本号：`AppVersion.current` 与 `MARKETING_VERSION` 对齐到 1.30.0。

## 1.29.0 - 2026-07-08

- 图片编辑器图层新增真实混合模式，支持正常、正片叠底、滤色、叠加、变暗、变亮、颜色减淡、颜色加深、柔光、强光和差值，并在画布合成与向下合并时生效。
- 图层面板混合模式选择器改为可编辑控件，选择当前图层后可直接调整混合模式。
- 图层面板新增图层锁定 / 解锁操作，锁定图层不可被绘制、调整或删除，历史记录会记录锁定状态变化。
- 新增混合模式与图层锁定相关简体中文、英语、日语本地化文案。
- 统一前后端版本号：`AppVersion.current` 与 `MARKETING_VERSION` 对齐到 1.29.0。

## 1.28.0 - 2026-07-08

- 图片编辑器升级为真实图层文档模型：初始化包含背景层和编辑层，画笔、橡皮、文字、形状、渐变和基础调整会作用于当前选中图层，再通过合成图回写预览。
- 矩形选区、套索和魔棒工具从占位状态升级为可用选区工具；有选区时绘制、擦除、文字、形状、渐变和调整只替换选区内像素，并支持清除选区。
- 图层面板新增选中、显隐、新建、复制、删除、上移、下移、透明度调整和向下合并操作，撤销 / 重做保存完整文档快照。
- 图片编辑器“导出”按钮支持直接保存当前图层合成结果为 PNG。
- 旋转和翻转改为整份图层文档变换，保留图层结构和画布尺寸关系，不再把编辑结果提前压平成单张图。
- 国际化范围收敛为简体中文、英语、日语三种语言，并移除西班牙语资源。
- 新增图片编辑器图层模型单元测试，覆盖初始化、选中图层绘制、图层复制合并和撤销行为。
- 统一前后端版本号：`AppVersion.current` 与 `MARKETING_VERSION` 对齐到 1.28.0。

## 1.27.0 - 2026-07-08

- 后处理预览右上角新增图片编辑入口，可从当前预览直接打开独立深色图片编辑窗口。
- 新增原生图片编辑工作台，提供类 Photopea / 旧版 Photoshop 的顶部菜单、工具参数栏、左侧工具栏、中央画布、历史 / 图层 / 属性面板和底部状态栏。
- 编辑器第一版支持缩放、平移、裁剪、旋转、翻转、画笔、橡皮擦、矩形、椭圆、文字、渐变叠加，以及亮度、对比度、饱和度、模糊和锐化调整。
- 编辑结果可应用回工作台预览，并作为新的原图进入后续保存、复制图片和上传链路；取消编辑不会修改当前预览。
- 新增图片编辑器相关简体中文、英语、日语、西班牙语本地化文案。
- 统一前后端版本号：`AppVersion.current` 与 `MARKETING_VERSION` 对齐到 1.27.0。

## 1.26.0 - 2026-07-06

- 整理输出面板新增“无损压缩”开关，保存、复制图片和上传前可对 PNG 输出做本地无损优化。
- 新增 `LosslessImageOptimizer`，通过多候选 PNG 重编码和元数据瘦身选择更小结果；如果优化后没有变小，会自动保留原始 PNG 数据。
- 上传版本生成支持在开关开启时优化原图 PNG 版本；JPEG、缩略图和 WebP 不伪装成无损压缩。
- 新增无损压缩相关简体中文、英语、日语、西班牙语本地化文案，并补充优化器单元测试。
- 统一前后端版本号：`AppVersion.current` 与 `MARKETING_VERSION` 对齐到 1.26.0。

## 1.25.1-rc1 - 2026-07-06

- 修复区域截图全局快捷键会在截图路径里主动打开主功能窗口的问题；现在触发区域截图快捷键会直接进入蒙板选区。
- 区域截图完成后仍会更新工作台数据并按设置复制截图到剪贴板，但不再由快捷键路径强制唤起主窗口。
- 统一前后端版本号：`AppVersion.current` 与 `MARKETING_VERSION` 对齐到 1.25.1-rc1。

## 1.25.0 - 2026-07-06

- 工作台四个图片入口改为单行 icon 按钮：区域截图、全屏、读剪贴板和选取文件保留图标并横向排列。
- 后处理模板从大卡片网格改为 6 个小图标工具条，并紧贴“后处理预览”区域下方。
- 插画输出面板移除模板网格，只保留保存、上传、复制图片和存储状态。
- 统一前后端版本号：`AppVersion.current` 与 `MARKETING_VERSION` 对齐到 1.25.0。

## 1.24.0 - 2026-07-06

- 区域截图蒙板支持双击完成：选区进入标注状态后，双击蒙板即可将截图送入工作台，等价于点击工具条“完成”。
- 更新截图标注状态提示文案，明确可以双击蒙板或点击“完成”进入工作台。
- 统一前后端版本号：`AppVersion.current` 与 `MARKETING_VERSION` 对齐到 1.24.0。

## 1.23.0 - 2026-07-06

- 将中日之外的应用展示名和打包产物名称统一调整为 `musepic`，中文系统显示名继续保持“轻图”，日语显示名继续保持“軽図”。
- 新增工作台下半区插画背景资产 `WorkbenchBackdrop`，让后处理模板、保存 / 上传 / 复制动作和配置状态共享统一的插画式界面。
- 将默认对象前缀和剪贴板兼容缓存目录改为 `musepic` 命名，减少旧英文名残留。
- 新增工作台插画面板相关简体中文、英语、日语、西班牙语本地化文案。
- 统一前后端版本号：`AppVersion.current` 与 `MARKETING_VERSION` 对齐到 1.23.0。

## 1.22.0 - 2026-07-06

- 区域截图迁移简图标准内联标注工具条：选区创建后可直接使用指针、矩形、椭圆、画笔和文字工具，并支持描边色、填充色、线宽、字号、撤销和重做。
- 区域截图工具条新增复制、保存和完成动作；复制会输出带标注截图到剪贴板，完成会将带标注截图送入工作台继续后处理、上传或复制链接。
- 移除旧的工作台独立图片标注编辑器和“标注”动作，避免截图标注存在两套入口。
- 新增截图内联标注工具条相关简体中文、英语、日语、西班牙语本地化文案。
- 统一前后端版本号：`AppVersion.current` 与 `MARKETING_VERSION` 对齐到 1.22.0。

## 1.21.0-rc2 - 2026-07-02

- 新增截图后自动复制到系统剪贴板设置，默认开启；全屏截图和区域截图完成后会立即写入剪贴板，同时继续进入后处理工作台。
- 该设置独立于上传成功后复制 URL 的设置，并写入 UserDefaults，旧配置升级后默认保持开启。
- 设置页新增“截图行为”卡片，可随时关闭截图自动复制。
- 统一前后端版本号：`AppVersion.current` 与 `MARKETING_VERSION` 对齐到 1.21.0-rc2。

## 1.21.0-rc1 - 2026-07-02

- 修复工作台“复制图片”与部分客户端粘贴不兼容的风险：剪贴板现在写入独立的 PNG/TIFF 像素数据 item，并额外写入独立文件 URL item。
- 复制图片时会在 Downloads 的 `.QingtuClipboard` 隐藏目录写入临时 PNG，兼容微信、QQ、Finder 等偏好文件引用的客户端。
- 沙盒权限新增 Downloads 读写访问，仅用于剪贴板兼容缓存。
- 统一前后端版本号：`AppVersion.current` 与 `MARKETING_VERSION` 对齐到 1.21.0-rc1。

## 1.21.0 - 2026-06-30

- 多显示器环境下触发全屏截图时新增截图范围选择，可截取所选屏幕或全部屏幕。
- 新增单屏 ScreenCaptureKit 捕获入口，复用原有工作台、后处理、上传、保存和复制输出管线。
- 新增全屏截图范围选择相关简体中文、英语、日语、西班牙语本地化文案。
- 统一前后端版本号：`AppVersion.current` 与 `MARKETING_VERSION` 对齐到 1.21.0。

## 1.20.0 - 2026-06-30

- 工作台新增“保存图片”动作，可将当前后处理后的 PNG 直接保存到本地。
- 工作台操作区改为两列布局，承载标注、保存、上传和复制图片四个主动作。
- 明确本次合并范围不包含 Chrome 长截图和窗口/文档/App 长截图能力。
- 统一前后端版本号：`AppVersion.current` 与 `MARKETING_VERSION` 对齐到 1.20.0。

## 1.19.0 - 2026-06-30

- 增强区域截图蒙层：创建选区后可拖拽选区内部整体移动。
- 增强区域截图蒙层：新增八向调整手柄，可在捕获前继续精调截图范围。
- 更新区域截图操作提示文案，说明选区可移动和调整。
- 统一前后端版本号：`AppVersion.current` 与 `MARKETING_VERSION` 对齐到 1.19.0。

## 1.18.0 - 2026-06-30

- 新增可编辑全局截图快捷键设置，支持分别配置全屏截图和区域截图的修饰键与主键。
- 快捷键设置会写入 UserDefaults，并在修改后立即重新注册 Carbon 全局热键。
- 设置页新增快捷键编辑控件和恢复默认动作，替代原先只读展示默认快捷键。
- 统一前后端版本号：`AppVersion.current` 与 `MARKETING_VERSION` 对齐到 1.18.0。

## 1.17.0 - 2026-06-30

- 新增工作台图片标注编辑器，支持画笔、矩形、椭圆、箭头和文字标注。
- 工作台新增“标注”动作，截图、粘贴、拖拽或单张选图进入工作台后都可先标注，再继续套用原图、圆角、渐变、iPhone、iPad 或 MacBook 后处理模板。
- 标注渲染改用 AppKit/CoreGraphics 直接输出真实位图，避免依赖 SwiftUI 视图截图。
- 新增标注编辑器相关简体中文、英语、日语、西班牙语本地化文案。
- 统一前后端版本号：`AppVersion.current` 与 `MARKETING_VERSION` 对齐到 1.17.0。

## 1.16.0 - 2026-06-30

- 新增 `SCREENSHOT_POSTPROCESS_PLAN.md`，明确从 `~/Sites/简图` 合并截图能力的迁移边界、托盘 UI 改造方案、后处理管线、输出策略和验收标准。
- 新增后处理工作台基础模型与渲染器，支持原图、圆角背景、浅色渐变、iPhone、iPad 和 MacBook 六种模板。
- 托盘面板首段从“上传”调整为“工作台”，新增区域截图、全屏截图、剪贴板和选图入口，并加入后处理预览、模板选择、上传与复制图片动作。
- 粘贴图片、拖拽图片和单张选图现在先进入工作台预览；上传时会使用当前后处理结果进入原有多版本生成和对象存储上传链路。
- 新增全屏截图基础入口，可捕获当前屏幕内容并送入后处理工作台。
- 新增轻量区域截图蒙层：覆盖多屏、拖拽选择区域、显示尺寸、支持取消/确认，并用 ScreenCaptureKit 捕获选区后送入后处理工作台；标注工具和可编辑快捷键后续继续从简图迁移。
- 新增默认全局截图快捷键：`Control+Shift+Command+3` 截取全屏，`Shift+Command+9` 截取区域，截图完成后进入后处理工作台并打开主窗口；设置页同步展示默认快捷键说明。
- 新增工作台与后处理相关简体中文、英语、日语、西班牙语本地化文案。
- 统一前后端版本号：`AppVersion.current` 与 `MARKETING_VERSION` 对齐到 1.16.0。

## 1.15.0 - 2026-06-29

- 主窗口上传页整体重排为「插画式」布局：新增海面 Hero 拖拽区（底部双层海浪装饰、圆形图标、文案「把图片拖到这片海里」），整块可拖拽可点击。
- 用三张自定义可点击插画卡片取代原先的标准按钮组：「读剪贴板」（海盐蓝实心渐变主入口）/「选图片」（暖沙描边）/「选目录」（海盐蓝描边），均带 ↗ 角标与按压缩放反馈。
- 分段导航由系统 segmented Picker 换成浮在白瓷胶囊里的药丸式导航（上传 / 链接 / 历史）。
- 底部状态胶囊（后端 / 路径 / 配置）图标改为彩色：海盐蓝 / 暖沙 / 翠绿。
- 新增 `UploadHeroComponents.swift` 承载 Hero、插画卡片与药丸导航；新增上传页相关文案的简中 / 英 / 日 / 西四语本地化。
- 主窗口、菜单栏面板与设置窗口整体改用「海盐晨蓝」皮肤（参照 musemail 同名配色）：浅蓝海盐渐变背景、暖沙点缀、海盐蓝主强调色、白瓷半透明卡片与发丝描边，整体更干净轻盈。
- 标题栏改为透明并锁定浅色外观，与窗口渐变融为一体；头部图标改为海盐蓝渐变方块。
- 新增 `Theme.swift` 集中托管全部配色与卡片/窗口样式，消除散落各处的硬编码色值。
- 全局启用 `focusEffectDisabled`：任何窗口内的图标与控件都不再出现焦点环 / focus 状态。
- 统一前后端版本号：`AppVersion.current` 与 `MARKETING_VERSION` 对齐到 1.15.0。

## 1.14.0 - 2026-06-22

- 新增设置“隐藏 Dock 图标”开关，默认开启；隐藏后轻图以菜单栏托盘形态运行，关闭后可在 Dock 显示图标并从 Dock 调出主窗口。
- 启动时根据该设置应用 `NSApplication.ActivationPolicy`，无需重启即可在 `.accessory` 与 `.regular` 之间切换。
- 新增简体中文、英语、日语、西班牙语对应文案。

## 1.12.0-rc1 - 2026-05-21

- 修复 macOS 启动后系统层应用名称仍显示为 VeilPic/veilpic 的问题；中文环境现在通过 Bundle 本地化显示为“轻图”。
- 将应用打包产物名称调整为 `Qingtu`，并补齐英语、日语、西班牙语的 Bundle 显示名本地化。

## 1.12.0 - 2026-05-21

- 上传页“本次生成”列表在上传完成后展示每个图片版本的 URL，并支持逐项复制。
- 上传成功后默认自动复制压缩图 URL；设置页新增自动复制开关和复制版本选择。
- 将提示反馈改为底部 toast，带入场动画并在 3 秒后自动消失，确保用户更容易看到操作结果。

## 1.11.0-rc5 - 2026-05-21

- 修复阿里云 OSS 使用区域 Endpoint 时上传被服务端误判 Bucket 不存在的问题；现在会自动将 `oss-cn-*.aliyuncs.com` 转换为 bucket 子域名形式发起上传。
- 更新阿里云 OSS 配置说明，明确 Endpoint 可填写区域域名或 bucket 绑定域名。

## 1.11.0-rc4 - 2026-05-21

- 修复上传进度按图片变体数展示导致任务数膨胀的问题，进度改为按图片任务统计。
- 新增图片任务级有限并发上传，最多同时上传 3 张图片，当前任务完成后自动补位。
- 优化上传进度面板，新增图形化任务条、完成数、并发数、失败数、队列数和上传速度展示。

## 1.11.0-rc3 - 2026-05-21

- 修复上传过程中不能继续选择新图片或目录的问题；新选择的图片会加入队列，并在当前上传完成后自动继续。
- 优化历史记录交互，点击历史预览或历史行即可复制主图 URL。

## 1.11.0-rc2 - 2026-05-21

- 修复 App Sandbox 下缺少出站网络权限导致 OSS / S3 主机名无法解析、上传失败的问题。
- 优化 WebP 生成检测，系统不支持 WebP 写出时安静跳过，避免产生误导性错误日志。

## 1.11.0-rc1 - 2026-05-21

- 修复托盘面板右上角设置图标出现选中底色或边框的问题，改为纯图标按钮。
- 修复批量上传失败时只显示失败数量的问题，现在会展示首个失败文件及具体错误原因。

## 1.11.0 - 2026-05-21

- 新增点击选择图片上传入口，支持从系统文件面板一次选择多张图片。
- 新增选择目录上传入口，会递归扫描目录中的图片并批量上传。
- 批量上传完成后复制所有成功图片的主链接，并在历史记录中保留原文件名来源。

## 1.10.0 - 2026-05-20

- 新增设置窗口“开机自动启动”开关，使用 macOS 登录项能力控制轻图是否随登录启动。
- 新增简体中文、英语、日语、西班牙语本地化资源；系统语言不在支持范围时回退到英语。
- 将设置、托盘面板、上传反馈、错误提示、历史和版本展示等可见文案接入统一本地化入口。

## 1.9.0-rc2 - 2026-05-20

- 修复点击 macOS Dock 图标时没有可见窗体的问题；无可见窗口时会打开轻图主窗体。
- 新增普通主窗体承载上传、链接和历史面板，菜单栏托盘继续保留为快速入口。

## 1.9.0-rc1 - 2026-05-20

- 修复从托盘面板打开设置窗口后，原托盘弹窗仍停留在屏幕上的交互问题。

## 1.9.0 - 2026-05-20

- 将已选定的“轻图”云端上传方向 logo 裁切并接入 macOS AppIcon 资产。
- 新增 16px 到 1024px 的完整 AppIcon PNG 尺寸，并更新 Xcode 资产目录映射。
- 新增单色 template 菜单栏图标资产，并让系统托盘入口使用轻图图标轮廓。

## 1.8.0 - 2026-05-20

- 按不同存储后端动态展示凭据字段名称，例如腾讯云 COS 使用 `SecretId / SecretKey`，Cloudflare R2 使用 `Access Key ID / Secret Access Key`。
- 新增 Cloudflare R2 临时凭据模式，支持填写 `Session Token` 并在 S3 V4 签名中发送安全令牌。
- 新增 Wasabi、Backblaze B2、DigitalOcean Spaces 和 MinIO 存储后端入口，复用 S3 兼容上传链路。

## 1.7.0 - 2026-05-20

- 强化首次启动引导，在设置窗口顶部新增“准备存储 / 填写配置 / 回到菜单栏”的三步流程。
- 新增每一步完成状态与缺失字段提示，让用户能按步骤确认初始化信息。
- 优化引导窗口信息层级，保留普通设置模式的简洁表单体验。

## 1.6.0 - 2026-05-20

- 新增首次启动设置引导窗口，未完成 OSS / S3 等存储配置时会主动打开普通设置窗体。
- 将存储配置从托盘弹窗移入独立设置窗口，托盘面板专注上传、链接和历史等高频操作。
- 精简托盘面板高度和顶部操作，新增设置入口与未配置状态提示。
- 品牌名称从 VeilPic 调整为“轻图”，菜单栏与设置引导使用新的中文名称。

## 1.5.0 - 2026-05-20

- 新增上传历史页，支持查看最近上传记录、选择历史项和删除本地历史。
- 新增本地图片预览卡片，上传页展示本次生成预览，历史页展示本地缩略图封面。
- 新增历史记录持久化，保存上传时间、来源、存储后端、bucket、各版本链接和缩略图数据。
- 新增历史链接快捷操作，支持复制主链接、复制全部链接和复制 Markdown 图片引用。
- 新增 `PrivacyInfo.xcprivacy`，声明本地 UserDefaults 用途，不采集数据、不做追踪。
- 优化托盘面板尺寸和信息层级，让上传、结果和历史浏览更接近正式 macOS 产品体验。

## 1.4.0 - 2026-05-20

- 拆分 UI、模型、图片处理、剪贴板读取和 ViewModel，降低单文件复杂度。
- 新增上传阶段进度反馈，包括读取、生成多版本、上传、复制链接、完成和失败状态。
- 新增成功、警告、错误、处理中四类反馈横幅，支持关闭提示。
- 新增配置缺失引导，上传前自动提示缺少的字段并跳转到配置页。
- 新增生成图片版本的尺寸摘要展示，方便用户确认本次会上传哪些版本。
- 新增存储配置持久化，普通配置写入 UserDefaults，Access Key Secret 写入 macOS Keychain。
- 优化上传按钮禁用态、拖拽高亮态、空状态和复制成功反馈。

## 1.3.0 - 2026-05-19

- 优化托盘面板结构，新增“上传 / 配置 / 链接”三段式导航。
- 新增存储后端配置完成度、后端徽标和上传快速状态。
- 新增各存储后端的 Endpoint / Region 输入提示和配置说明。
- 优化上传结果展示，支持复制单个链接和一键复制全部链接。
- 优化空状态、最新原图链接预览和按钮文案。

## 1.2.0 - 2026-05-19

- 新增真实对象存储上传实现，不再只生成预览链接。
- 新增 Amazon S3、兼容 S3、Cloudflare R2 的 AWS Signature V4 PUT 上传。
- 新增阿里云 OSS 原生 HMAC-SHA1 PUT 上传签名。
- 新增腾讯云 COS 原生 HMAC-SHA1 PUT 上传签名。
- 新增七牛云 Kodo 上传凭证和 multipart 表单上传。
- 新增对象前缀配置，上传路径按前缀和日期自动归档。
- 新增真实 WebP 编码尝试；系统编码器不可用时会跳过 WebP 版本。

## 1.1.0 - 2026-05-19

- 新增 macOS 系统托盘式图片上传入口。
- 新增拖拽图片、读取剪贴板图片、自动复制原图链接的基础流程。
- 新增阿里云 OSS、Amazon S3、腾讯云 COS、七牛云 Kodo、兼容 S3 的配置模型入口。
- 新增原图、压缩图、缩略图、WebP 引用链接的多版本生成设计。
- 新增产品设计说明，明确不依赖自建服务器、以用户自带存储凭据直传为核心方向。
