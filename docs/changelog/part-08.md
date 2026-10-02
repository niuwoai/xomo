
## 2.12.0-rc560 - 2026-07-29

### Added
- `xomo.layer.selection_bounds` 在移动、缩放或旋转事务期间新增 `originalBounds`，自动化可直接比较按下时与当前预览的几何，不必在外部抢先缓存状态。
- 缩放事务新增 `scalePercent.width / scalePercent.height`，与 `sizeDelta` 和实时 `bounds` 使用同一原始变换框计算。

### Changed
- 原始边界与缩放百分比只在适用的活动事务中出现；完成或取消变换后立即省略，移动与旋转不会夹带缩放字段。
- Release 配置明确关闭测试覆盖率插桩和调试 entitlement 注入，并使用独立最小权限清单保留沙盒、用户文件、下载目录与网络能力；Developer ID 安装包不再携带 `get-task-allow`。

### Verification
- 变换上下文定向 Xcode 测试 2/2、工具冒烟 35/35、CLI 2/2、发布契约 5/5（13 个断言，包含正式权限防回归）、三语资源 3364 × 3 与差异检查通过。
- 周期性隔离全量回归实际执行 1548 项、93 个套件：68 个套件通过，25 个既有跨域回归债务仍失败；JSON 与 Markdown 报告保存在 `/tmp/veilpic-rc560-test-reports/`，未将其虚报为全绿。
- Xomo 与 CLI 的 macOS 13 Release 均完成 `arm64 + x86_64` 通用构建；应用通过 Developer ID 深度严格验签，正式权限清单不含 `get-task-allow`，构建产物与 `/Applications/Xomo.app` 均真实启动成功，安装版本复验为 `2.12.0-rc560 (560)`。

## 2.12.0-rc559 - 2026-07-29

### Added
- 对象缩放期间的信息面板几何行新增实时 `ΔW / ΔH`，当前 X/Y/W/H 与相对按下时尺寸变化使用同一变换框口径。
- `xomo.layer.selection_bounds` 在 `operation=resize` 时新增结构化 `sizeDelta.width / sizeDelta.height`。

### Changed
- 移动、缩放、旋转三类预览分别只返回各自适用的位移、尺寸或角度增量；取消缩放后尺寸增量立即清除，原始几何和 History 保持不变。

### Verification
- Xcode 定向测试 1/1 通过，覆盖缩放实时尺寸增量、信息面板 `ΔW / ΔH`、MCP `sizeDelta`、取消恢复与零额外 History；CLI 测试 2/2、发布契约 4/4（10 个断言）、三语资源 3364 × 3 与差异检查通过。
- `/Applications/Xomo.app` 已按用户要求安装并严格验签为 rc558；rc560 仍执行周期性完整构建、冒烟与覆盖安装。

## 2.12.0-rc558 - 2026-07-29

### Added
- 旋转对象期间的信息面板几何行新增 `Δθ`，显示相对按下位置的实时旋转增量；Shift 15° 吸附后的实际角度直接反映在读数中。
- `xomo.layer.selection_bounds` 新增活动变换 `operation`，可区分 `move`、`resize` 和 `rotate`；旋转期间另返回 `rotationDeltaDegrees`。

### Changed
- MCP 的 `preview` 从仅代表对象移动扩展为三类画布变换事务；缩放期间返回实时边界，移动继续返回 `delta`，旋转继续返回实时边界和角度。
- 没有活动变换时省略 `operation`、移动增量和旋转增量；取消缩放或旋转会恢复原始几何，清除预览字段且不写 History。

### Verification
- Xcode 定向测试 2/2 通过，覆盖移动累计位移、吸附后的缩放边界、旋转 15° 吸附、三种 `operation`、取消恢复及零额外 History；CLI 测试 2/2、发布契约 4/4（10 个断言）、三语资源 3362 × 3 与差异检查通过。
- `/Applications/Xomo.app` 保持已严格验签的 rc552；下一次周期性全量构建、冒烟与覆盖安装门禁仍为 rc560。

## 2.12.0-rc557 - 2026-07-29

### Added
- 对象拖动期间的信息面板读数新增 `ΔX / ΔY`，直接显示相对按下位置的累计画布位移；吸附、轴向约束和子像素移动都以最终虚线预览位置为准。
- `xomo.layer.selection_bounds` 在实时拖动预览期间新增结构化 `delta.x / delta.y`；没有活动拖动时省略该字段，不用伪造的零位移混淆调用方。

### Changed
- 单选和多选对象继续在同一行显示 X/Y/W/H，只在活动拖动时追加位移，避免进一步挤占导航器 / 信息面板高度。
- 位移读数复用 rc556 的原始变换框与轻量预览框，不增加逐鼠标事件的像素合成、图层提交或 History 写入。

### Verification
- Xcode 定向测试 1/1 通过，覆盖多选对象累计位移、子像素读数、MCP `delta`、取消恢复及零额外 History；CLI 测试 2/2、发布契约 4/4（10 个断言）、三语资源 3360 × 3 与差异检查通过。
- `/Applications/Xomo.app` 保持已严格验签的 rc552；下一次周期性全量构建、冒烟与覆盖安装门禁仍为 rc560。

## 2.12.0-rc556 - 2026-07-29

### Added
- “导航器 / 信息”新增对象几何读数：普通图层、多个图层和组件对象统一显示画布 X、Y、W、H；多选明确显示对象数量，未选到可变换内容时清空旧值。
- MCP/CLI 新增只读 `xomo.layer.selection_bounds`，返回稳定排序的选中图层 ID、对象数、共享包围盒以及是否正在显示拖拽预览。

### Changed
- 对象读数直接复用变换框的统一包围盒；组件使用子层可见内容范围，多选使用整体 union，普通图层遵循既有可变换内容边界，不另造坐标口径。
- 拖动组件或图层时，信息面板和 MCP 读取轻量 `movingObjectPreviewFrame`，实时显示虚线预览所在位置；松手后自然切回提交后的图层框，取消拖动恢复原值且不写 History。
- 对象坐标保留一位子像素精度，整数不显示多余小数；信息面板同步增加一行高度，F8 信息状态也包含对象几何。

### Verification
- Xcode 定向测试 3/3 通过，覆盖多选对象包围盒、实时拖拽预览、取消恢复、信息面板来源契约和 MCP 工具目录；CLI 测试 2/2、发布契约 4/4（10 个断言）、三语资源 3358 × 3 与差异检查通过。
- `/Applications/Xomo.app` 保持已严格验签的 rc552；下一次周期性全量构建、冒烟与覆盖安装门禁仍为 rc560。

## 2.12.0-rc555 - 2026-07-29

### Added
- “导航器 / 信息”新增选区几何读数，完成选区后直接显示像素覆盖范围的 X、Y、W、H；没有选区时使用明确空值，不沿用上一次结果。

### Changed
- 小数坐标选区按实际覆盖像素向外取整，越出画布的部分先裁回画布；反选按真实选中范围显示整张画布，而不是显示中间被排除区域的边界。
- 信息面板同步增加一行高度，避免选区读数挤压颜色取样与直方图内容；现有 `xomo.selection.get` 已暴露同一几何信息，不新增重复 MCP 工具。

### Verification
- 选区小数坐标/反选/清空几何语义和 F8 信息入口接线两个定向 Xcode 回归 2/2 通过；CLI 2/2、发布契约 4/4（10 个断言）、三语资源语法及 3355×3 键集合一致性、版本一致性与差异检查通过。
- `/Applications/Xomo.app` 保持已在系统权限下严格验签通过的 rc552；下一次周期性全量构建、冒烟与覆盖安装门禁仍为 rc560。

## 2.12.0-rc554 - 2026-07-29

### Added
- “导航器 / 信息”的颜色取样新增 CMYK 百分比读数；实时指针与最多四个固定取样点可在 RGB、HSB、CMYK、HEX 四档间即时切换，按钮继续保持不可键盘聚焦。
- MCP/CLI 颜色取样结果新增结构化 `cmyk` 字段，提供 C/M/Y/K/Alpha 标准化值，并明确标记为 `deviceRGB` 推导。

### Changed
- `.xomoproject` v10 可原样保存并恢复 CMYK 读数模式；旧项目默认值仍为 RGB，项目格式版本无需再次提升。
- 当前 CMYK 是从 8 位 Device RGB 确定性推导的快速工程读数，不宣称具备 ICC 配置文件转换、油墨总量控制或印刷软打样能力。

### Verification
- CMYK 固定点、实时指针、项目保存恢复与 MCP 输出四个定向 Xcode 回归 4/4 通过；CLI 2/2、发布契约 4/4（10 个断言）、三语资源语法及 3353×3 键集合一致性、版本一致性与差异检查通过。
- `/Applications/Xomo.app` 保持已验签并真实启动的 rc552；下一次周期性全量构建、冒烟与覆盖安装门禁仍为 rc560。

## 2.12.0-rc553 - 2026-07-29

### Added
- 原生 `.xomoproject` 项目格式升级到 v10，开始保存颜色取样点的稳定 UUID、画布坐标、RGB/HSB/HEX 读数模式、1×1/3×3/5×5 取样尺寸，以及合成图/当前图层来源。

### Changed
- 重新打开项目时不复用文件里的陈旧颜色值，而是按当前画布内容、尺寸与来源重新取色；越界点会被丢弃，重复 UUID 自动修复，恢复结果仍严格限制为四点。
- v9 及更早项目没有取样器字段时安全回退为 RGB、3×3、合成图且无固定点，不继承打开前文档的临时取样状态。

### Verification
- 项目文档测试组 12/12、颜色取样器邻接回归 4/4 通过，覆盖持久化、旧格式默认值、越界过滤、重复 UUID 修复、四点上限，以及既有取样、来源切换、移动/删除、Undo/Redo 刷新；原有动态系统绿色夹具改为确定性纯绿色，避免系统外观改变通道阈值。
- CLI 2/2、发布契约 4/4（10 个断言）、版本一致性、三语资源语法与 3349×3 行数一致性、差异检查通过。
- 开始本版前已将 rc552 Release 双架构包用 Developer ID 深度签名，覆盖安装到 `/Applications/Xomo.app` 并真实启动；下一次周期性完整构建、全量测试、冒烟与覆盖安装门禁仍为 rc560。

## 2.12.0-rc552 - 2026-07-29

### Added
- 颜色取样器支持拖住已有编号点实时预览新位置，松开后才重新取样并提交；按住 Option 点击命中的取样点可只删除该点，不再需要清空全部四点。
- MCP/CLI 新增 `xomo.color_sampler.move` 与 `xomo.color_sampler.remove`；列表和新增结果补充稳定 UUID，客户端可精确移动或删除目标而不依赖会变化的显示序号。

### Changed
- 颜色取样器在空白画布保持精确十字光标，命中已有点时切换为通用四向移动光标，Option 命中时显示带减号的取样光标；组件库模式仍强制使用系统箭头。
- 移动和单点删除不写 History；Option 按下后拖离原点会取消删除，未知 UUID、画布外目标和重复删除均在改变点位前原子失败。

### Verification
- 取样点移动/删除、稳定 ID、原子失败、原有取样管理与三态光标定向 Xcode 测试 5/5 通过；CLI 2/2、发布契约 4/4（10 个断言）、版本一致性、三语资源语法和差异检查通过。
- `/Applications/Xomo.app` 保持用户要求先安装并真实启动的 rc549；下一次周期性完整构建、全量测试、冒烟与覆盖安装门禁为 rc560。

## 2.12.0-rc551 - 2026-07-29

### Added
- “导航器 / 信息”的颜色取样新增不可键盘聚焦的“合成 / 图层”来源切换；实时指针和最多四个固定取样点使用同一来源，切换后现有点立即重算。
- MCP/CLI 的 `xomo.color_sampler.add` 新增可选 `sampleSource`，支持 `composite` 与 `selectedLayer`，新增与列表结果同步返回实际来源。

### Changed
- 当前图层取样复用与直方图一致的隔离渲染语义：普通图层保留位置、不透明度、蒙版与样式，组使用隔离组画布；调整层和滤镜层不会被误当成独立像素来源。
- 请求不可取样的当前图层、未知来源或画布外坐标时，在切换全局取样来源、刷新现有点和写入 History 之前原子失败。

### Verification
- 合成/当前图层来源、实时指针、固定点刷新、MCP schema 与原子失败定向 Xcode 测试 4/4 通过；CLI 2/2、发布契约 4/4（10 个断言）、版本一致性、三语资源语法和差异检查通过。
- `/Applications/Xomo.app` 保持用户要求先安装并真实启动的 rc549；下一次周期性完整构建、全量测试、冒烟与覆盖安装门禁为 rc560。

## 2.12.0-rc550 - 2026-07-29

### Added
- “导航器 / 信息”新增不可键盘聚焦的 `1×1`、`3×3`、`5×5` 取样尺寸；实时指针与已放置颜色取样点共用当前尺寸，切换后现有点位立即重算。
- MCP/CLI 的 `xomo.color_sampler.add` 新增可选 `sampleSize`，并在新增与列表结果中返回实际尺寸；非法尺寸或画布外坐标保持原子失败。

### Changed
- 原本分别实现的单像素指针读取与固定 `3×3` 取样点合并为同一份 8 位 Device RGB 缓存路径；缓存固定使用画布原始像素尺寸，不会在 Retina 屏幕上把 backing pixel 错当画布像素。边缘样本采用夹取像素，频繁移动或切换尺寸不重复展开整张图，也不写 History。

### Verification
- 取样尺寸、实时指针、现有点刷新、Retina 像素归一化、MCP schema/原子错误定向 Xcode 测试 3/3 通过；CLI 2/2、发布契约 4/4（10 个断言）、版本一致性、三语资源语法和差异检查通过。
- `/Applications/Xomo.app` 已按用户要求先覆盖安装并真实启动 rc549；下一次周期性完整构建、全量测试、冒烟与覆盖安装门禁仍为 rc560。

## 2.12.0-rc549 - 2026-07-29

### Added
- “导航器 / 信息”新增画布指针实时读数：鼠标位于画布时显示当前像素坐标和合成图颜色，并与取样点共用 `RGB / HSB / HEX` 模式；离开画布后坐标与颜色明确恢复为破折号。

### Changed
- 指针坐标按实际像素格向下取整，使显示的 X/Y 与被读取的像素严格一致；高频 hover 不写 History，也不改变前景色或已放置取样点。
- 指针颜色使用按当前合成图缓存的 8 位 Device RGB 像素缓冲，同一画布版本只转换一次；绘制、Undo/Redo 或图层变化使渲染缓存失效时同步重建，既避免每次鼠标移动都展开整张 RGBA 缓冲，也避免显示色彩空间二次转换污染通道读数。

### Verification
- 指针坐标、RGB/HSB/HEX、画布更新、离开清理、信息菜单与三语资源定向 Xcode 测试 4/4 通过；CLI 2/2、发布契约 4/4（10 个断言）、版本一致性、资源语法与差异检查均通过。
- 本版按用户要求额外完成 `arm64 + x86_64` Release、Developer ID 严格验签、macOS 13 下限核对、`/Applications/Xomo.app` 覆盖安装与真实启动；下一次周期性完整测试与冒烟门禁仍为 rc560。

## 2.12.0-rc548 - 2026-07-29

### Added
- “导航器 / 信息”的颜色取样点新增不可键盘聚焦的 `RGB`、`HSB`、`HEX` 三档读数切换；坐标始终保留，HSB 使用角度与百分比，十六进制使用完整 `#RRGGBBAA`。
- MCP/CLI 的颜色取样结果在原有标准化 `color` 之外，新增 8 位 `rgb8`、标准化 `hsb` 与 `hexRGBA`，自动化客户端无需重复实现颜色换算。

### Changed
- 界面与 MCP 共用同一个颜色读数模型，所有 8 位通道、HSB 百分比和十六进制值采用相同的舍入与边界规则。

### Verification
- 颜色读数、MCP 输出与三语资源定向 Xcode 测试 3/3 通过；CLI 2/2、发布契约 4/4（10 个断言）、版本一致性、资源语法和差异检查均通过。
- 下一次周期性完整构建、冒烟和 `/Applications` 覆盖安装门禁仍为 rc560；当前安装版保持已真实启动的 rc546。

## 2.12.0-rc547 - 2026-07-29

### Added
- 已放置的颜色取样点会在像素操作写入 History、Undo/Redo、历史回退或 MCP 列出时重新读取当前合成画布；坐标与稳定 ID 保持不变，信息面板不再展示操作前的旧颜色。

### Changed
- 单个取样点的 3 × 3 平均色由“每个像素重新合成一次画布”改为复用同一张合成图，九次合成收敛为一次；最多四点刷新也共用同一采样源。
- 新建画布或从剪贴板创建画布时清空旧文档取样点；画布尺寸变化后，落在新边界之外的点会安全移除。

### Verification
- 颜色刷新、稳定 ID、Undo/Redo 与 MCP 无历史副作用定向 Xcode 测试 2/2 通过；CLI 测试 2/2、发布契约 4/4（10 个断言）、版本一致性与差异检查均通过。
- 开始本版前已按用户要求将 rc546 Release 覆盖安装到 `/Applications/Xomo.app`，核对版本、Bundle ID、双架构二进制一致性并真实启动；下一次周期性完整门禁仍为 rc560。

## 2.12.0-rc546 - 2026-07-29

### Added
- “导航器 / 信息”面板补齐颜色取样点信息区：最多四个取样点会以色块、画布 X/Y 坐标和 8 位 RGBA 数值紧凑显示，无需盯着画布浮标猜颜色。
- 信息区新增不可键盘聚焦的清除按钮；MCP/CLI 同步新增 `xomo.color_sampler.list`、`add`、`clear`，可读取坐标与标准化 RGBA、添加取样点并返回实际清除数量。

### Fixed
- 颜色取样先验证点位位于画布内，再进入 3 × 3 平均采样；避免 AppKit 把画布外像素返回为透明黑时误创建合法取样点。
- 取样点的界面与自动化入口共用最多保留最新四点的规则，添加、列出和清除均不写入 History/Undo。

### Verification
- 信息文本、RGBA/坐标、清除数量、画布边界、MCP schema 与无历史副作用定向 Xcode 3/3 通过；CLI 2/2、三语资源、发布契约 4/4（10 个断言）与差异检查通过。
- `/Applications/Xomo.app` 保持此前已构建并真实启动的 rc544；下一次周期性完整构建、冒烟和覆盖安装门禁仍为 rc560。

## 2.12.0-rc545 - 2026-07-29

### Added
- 导航器直方图支持直接按下并拖拽选择连续色阶区间；拖动期间以低干扰高亮实时显示实际色阶边界、像素计数和区间占比，反向拖动与超出绘图区都会稳定夹取。
- MCP/CLI 的 `xomo.document.get` 新增成对的 `histogramRangeLowerLevel`、`histogramRangeUpperLevel`，返回按当前通道和 32 档量化后的 `range` 统计。

### Fixed
- 色阶区间的鼠标坐标统一扣除绘图区水平留白后再映射到柱索引，避免靠近左右边缘时选中偏移一档。
- 自动化区间参数必须同时提供、使用 0–255 整数且保持起点不大于终点；非法请求在不改变文档、选择和 History/Undo 的前提下原子拒绝。

### Verification
- 直方图区间统计、反向选择、边缘坐标、导航器读数和 MCP 返回/错误原子性定向 Xcode 3/3 通过；CLI 2/2、三语资源、发布契约 4/4（10 个断言）与差异检查通过。
- 开始本版前已按用户要求将 rc544 Release 覆盖安装到 `/Applications/Xomo.app`，核对版本、Bundle ID、可执行文件一致性并真实启动；下一次周期性完整门禁仍为 rc560。

## 2.12.0-rc544 - 2026-07-29

### Added
- 导航器直方图新增经典色阶探查：悬停任意柱会高亮当前档，并显示 0–255 色阶范围、该档真实像素计数和截至该档的累计百分位。
- MCP/CLI 的 `xomo.document.get` 新增当前通道 32 档 `binCounts`、`binPercentiles` 与 `binLevelRanges`，自动化客户端可取得与界面探查完全一致的原始分布。

### Changed
- 直方图每档在保留归一化显示高度的同时保存红、绿、蓝、亮度四组真实计数；RGB 探查沿用亮度统计语义，避免彩色叠加视图产生含糊的三倍计数。
- 探查文本与高亮只响应鼠标悬停，不获取键盘焦点，也不改变通道、分析范围、图层选择或 History/Undo。

### Verification
- 色阶边界、分通道计数、累计百分位、全透明零计数、导航器读数与 MCP 返回值定向 Xcode 5/5 通过；三语本地化、CLI 2/2、发布契约 4/4（10 个断言）与差异检查通过。
- 下一次完整构建、完整冒烟和 `/Applications` 覆盖安装门禁仍为 rc560；当前安装版保持已验证的 rc541。

## 2.12.0-rc543 - 2026-07-29

### Added
- 直方图为 RGB、亮度、红、绿、蓝通道新增真实 0–255 中位数、总体标准差和有效采样像素覆盖读数，便于判断曝光集中度、反差与噪声分布。
- MCP/CLI 的 `xomo.document.get` 同步返回当前通道及四个基础通道的 `median`、`standardDeviation` 统计，继续沿用合成图、当前图层和当前选区范围。

### Fixed
- 中位数不再从 32 档显示柱近似，而是从完整 256 值频数计算；偶数样本取两个中间值平均。
- 新统计继续排除完全透明像素，并在计算前恢复半透明像素的非预乘 RGB；全透明范围安全返回零中位数和零标准差。

### Verification
- 中位数、总体标准差、透明/半透明语义、通道映射、范围回归、导航器读数与 MCP 返回值定向 Xcode 7/7 通过；三语本地化、CLI 2/2、发布契约 4/4（10 个断言）与差异检查通过。
- 下一次完整构建、完整冒烟和 `/Applications` 覆盖安装门禁仍为 rc560；当前安装版保持已验证并正在运行的 rc541。

## 2.12.0-rc542 - 2026-07-29

### Added
- 导航器直方图新增“合成图像 / 当前图层 / 当前选区”分析范围；当前图层复用图层导出渲染，当前选区复用完整 Alpha 蒙版语义。
- MCP/CLI 的 `xomo.document.get` 新增可选 `histogramSource`，并在直方图结果中返回实际 `source`，界面与自动化使用同一业务入口。

### Fixed
- 切换图层或选区时，范围直方图缓存会核对图层 ID 或选区值，避免继续显示上一个目标的数据；不可独立分析的调整/滤镜层和不存在的选区会明确禁用或无副作用失败。
- `histogramSource` 与 `histogramChannel` 的错误类型或未知枚举在读取像素前原子拒绝，不改变文档、选择和 History。

### Verification
- 三种分析范围、图层切换缓存、选区 Alpha、MCP schema/读取/不可用与错误类型原子性定向 Xcode 测试 4/4 通过；三语本地化校验、CLI 2/2、发布契约 4/4（10 个断言）与差异检查通过。
- 开始本版前已将 rc541 Release 严格验签并覆盖安装到 `/Applications/Xomo.app`，真实启动成功；下一次完整构建、完整冒烟和覆盖安装门禁仍为 rc560。

## 2.12.0-rc541 - 2026-07-29

### Changed
- 导航器直方图的平均值读数跟随当前查看通道：RGB 显示三通道平均值，亮度显示平均亮度，红、绿、蓝分别显示对应通道名称与平均值。
- 固定的 RGB、亮度两行读数合并为一行上下文读数，面板同步收紧高度，在保留尺寸、颜色与裁切信息的同时减少冗余。

### Verification
- 当前通道切换、RGB/亮度/单色三类平均值格式与既有裁切读数定向 Xcode 测试 1/1 通过；三语本地化校验通过，CLI 2/2、发布契约 4/4（10 个断言）与差异检查通过。
- 下一次完整构建、完整冒烟和 `/Applications` 覆盖门禁仍为 rc560；rc541 后续已按用户要求完成 Release 构建、严格验签、覆盖安装与真实启动。

## 2.12.0-rc540 - 2026-07-29

### Fixed
- 直方图不再把完全透明像素误算成黑色，透明画布不会凭空出现暗部峰值或虚假的死黑裁切。
- 半透明像素在统计前恢复非预乘 RGB，避免红、绿、蓝与亮度平均值被 Alpha 预乘错误压暗；全透明图仍安全返回零统计。

### Changed
- MCP/CLI 的 `xomo.document.get` 直方图结果新增 `sampledPixelCount` 与 `transparentPixelCount`，`pixelCount` 明确表示实际参与颜色统计的可见采样像素数。

### Verification
- 透明像素过滤、半透明颜色恢复、全透明零统计、既有通道统计与 MCP 读数定向 Xcode 测试 4/4 通过；CLI 2/2、发布契约 4/4（10 个断言）与差异检查通过。
- 下一次完整构建、完整冒烟和 `/Applications` 覆盖门禁仍为 rc560；`/Applications/Xomo.app` 当前保留已验证的稳定 rc538。

## 2.12.0-rc539 - 2026-07-27

### Added
- 导航器直方图新增 RGB、亮度、红、绿、蓝五种查看通道；短标签使用不可键盘聚焦的深色面板按钮，单色模式只绘制对应数据。
- MCP/CLI 现有 `xomo.document.get` 新增可选 `histogramChannel`，返回采样像素数、所选通道平均值、各 RGB/亮度平均值、暗部/亮部裁切比例与 32 档通道数据。

### Fixed
- MCP 请求未知直方图通道会在不改变文档、选择与 History 的前提下明确失败；未指定通道时跟随界面当前查看通道。
- 自动化能力总数断言同步到 rc538 已加入的滤镜层设置工具，避免能力目录和测试期望漂移。

### Verification
- 直方图通道映射、导航器状态、MCP schema/读取/错误原子性定向 Xcode 测试 4/4 通过；CLI 2/2、发布契约 4/4（10 个断言）通过。
- 下一次完整构建、完整冒烟和 `/Applications` 覆盖门禁仍为 rc560；本轮开始前已将稳定 rc538 严格签名并覆盖安装到 `/Applications/Xomo.app`，完成真实启动验证。

## 2.12.0-rc538 - 2026-07-27

### Added
- MCP/CLI 新增 `xomo.layer.filter_settings`，可读取选中普通滤镜层的类型、强度、锁定状态与完整归一化参数。
- `set` 动作可将 `get` 返回的完整设置对象和可选强度批量写回可编辑滤镜层，并保持每层原有滤镜类型。

### Fixed
- 锁定层和非滤镜层安全跳过，强度与详细参数使用界面同一边界；重复值不写空 History，缺字段、未知字段或错误类型在文档变化前原子失败。
- 自动化写回后立即同步当前滤镜层的属性控件，避免参数已变而面板仍显示旧值。

### Verification
- 完整设置读取、批量锁定跳过、归一化、面板同步、重复空操作和原子失败定向 Xcode 测试 1/1 通过；CLI 2/2、发布契约 4/4（10 个断言）通过。
- 下一次完整门禁仍为 rc560。

## 2.12.0-rc537 - 2026-07-27

### Added
- “滤镜 > 扭曲”新增镜头校正，可用 `-100...100` 畸变参数纠正桶形或枕形径向变形；属性面板提供实时强度与畸变控制。
- 镜头校正同时支持普通滤镜层、智能滤镜、项目保存恢复和三语界面，底层原始像素在非破坏路径中保持不变。
- MCP/CLI 的 `xomo.filter.configure` 新增 `lensCorrection` 与 `lensDistortion`，沿用界面同一归一化模型。

### Fixed
- 智能滤镜列表会明确显示镜头校正的强度与畸变值，自动化越界参数统一收敛到 `-1...1`。

### Verification
- 径向像素采样、普通/智能滤镜非破坏性、设置归一化、项目往返、MCP 配置与三语资源定向 Xcode 测试 4/4 通过；CLI 2/2、发布契约 4/4（10 个断言）通过。
- 下一次常规完整构建、完整冒烟和 `/Applications` 覆盖门禁仍为 rc560。

## 2.12.0-rc536 - 2026-07-27

### Added
- `xomo.layer.adjustment_settings` 新增 `set` 动作，可将 `get` 返回的完整归一化设置对象写回选中的非破坏调整图层，并可同时更新主强度。
- 调整图层批量事务返回真实 `updatedLayerCount`，锁定层和非调整层安全跳过；主强度按普通调整 `-1...1`、色调分离 `2...32` 的既有模型范围归一化。

### Fixed
- 完整设置缺字段、出现未知字段或类型错误时会在写入任何图层与 Undo/History 前原子失败；重复值不再制造空历史。
- 写回后立即同步主选择层的属性控件，避免自动化修改已生效但面板仍显示旧值。

### Verification
- 完整设置替换、多选锁定跳过、真实修改计数、重复空操作和原子失败定向 Xcode 测试 1/1 通过；CLI 2/2、发布契约 4/4（10 个断言）通过。
- 下一次常规完整构建、完整冒烟和 `/Applications` 覆盖门禁仍为 rc560。

## 2.12.0-rc535 - 2026-07-27

### Added
- MCP/CLI 新增只读 `xomo.layer.adjustment_settings`，可检查当前选中的非破坏调整图层、调整类型、主强度、锁定状态与完整归一化设置。
- 调整图层设置通过现有 Codable 持久化模型编码，覆盖色阶、曲线、色彩平衡、黑白、通道混合器、照片滤镜、颜色查找、选择颜色与渐变映射等完整字段，不维护第二份易漂移的字段表。

### Fixed
- 自动化客户端现在可以先读取调整图层真实参数再决定后续修改，不再只能依赖图层名称或界面残留状态猜测。

### Verification
- 工具 schema、多选读取、完整设置编码、锁定状态和只读无历史副作用定向 Xcode 测试 1/1 通过；CLI 2/2、发布契约 4/4（10 个断言）通过。
- 已将严格验签并剥离 XCTest 专用内容的 rc535 应用覆盖安装到 `/Applications/Xomo.app`，并完成真实启动验证。
- 下一次常规完整构建、完整冒烟和 `/Applications` 覆盖门禁仍为 rc560。

## 2.12.0-rc534 - 2026-07-27

### Added
- `xomo.layer.create` 创建纯色填充层时可一次指定 `solidRed`、`solidGreen`、`solidBlue`，颜色与界面/渲染模型共用 0–1 归一化边界。
- 新增带完整 `ImageEditorSolidColorFillContent` 的视图模型创建入口，使界面与 MCP 共用图层插入、选中和历史记录语义。

### Fixed
- 参数化创建不再继承属性面板上一次残留的纯色填充颜色；缺少任一颜色通道时会在插入图层和写入 Undo/History 前失败。

### Verification
- 创建 schema、颜色归一化、界面状态隔离与缺参原子失败定向 Xcode 测试 1/1 通过；CLI 2/2、发布契约 4/4（10 个断言）通过。
- 下一次常规完整构建、完整冒烟和 `/Applications` 覆盖门禁仍为 rc560。

## 2.12.0-rc533 - 2026-07-27

### Added
- `xomo.layer.create` 创建渐变填充层时可一次指定预设、样式、反向、角度、缩放、首尾颜色与 2–16 个有序颜色停止点。
- 新增带完整 `ImageEditorGradientFillContent` 的视图模型创建入口，使 MCP、Figma/PSD 多段渐变模型与界面创建流程共用同一图层插入和历史记录语义。

### Fixed
- 参数化创建不再继承属性面板上一次残留的渐变状态；不完整或非法参数在插入图层和写入 Undo/History 前失败。

### Verification
- 创建 schema、多段渐变一次创建、界面状态隔离与非法参数原子失败定向 Xcode 测试 1/1 通过；CLI 2/2、发布契约 4/4（10 个断言）通过。
- 下一次常规完整构建、完整冒烟和 `/Applications` 覆盖门禁仍为 rc560。

## 2.12.0-rc532 - 2026-07-27

### Added
- MCP/CLI 新增 `xomo.layer.gradient_fill_settings`，可读取或批量替换选中渐变填充层的预设、样式、反向、角度、缩放、端点颜色与 2–16 个有序颜色停止点。
- 多段渐变使用与 Figma、PSD、矢量形状相同的持久化颜色停止点模型；设置时跳过锁定层和非渐变层，并返回真实 `updatedLayerCount`。

### Fixed
- 属性面板再次更新 MCP/PSD/Figma 导入的多段自定义渐变时，保留中间颜色停止点，只同步首尾颜色，避免退化成两段渐变。
- 重复设置不制造 Undo/History；越界角度、缩放、颜色或无序/不完整停止点会在修改文档前明确失败。

### Verification
- MCP schema、多段读写、锁定跳过、重复空操作、非法停止点与属性面板保真定向 Xcode 测试 1/1 通过；CLI 2/2、发布契约 4/4（10 个断言）通过。
- 下一次常规完整构建、完整冒烟和 `/Applications` 覆盖门禁仍为 rc560。

## 2.12.0-rc531 - 2026-07-27

### Added
- MCP/CLI 新增 `xomo.layer.solid_color_fill_settings`，可读取当前选中的纯色填充层，或一次批量替换完整 RGB 颜色。
- 设置操作跳过锁定层和非纯色填充层，返回真实 `updatedLayerCount`；颜色继续使用界面与渲染模型的 0–1 归一化。

### Fixed
- 重复设置不再制造多余 Undo/History；缺少颜色通道或没有可编辑目标时明确失败。

### Verification
- MCP schema、读取、批量更新、锁定跳过、颜色归一化、重复空操作与缺参定向 Xcode 测试 1/1 通过；CLI 2/2、发布契约 4/4（10 个断言）通过。
- 下一次常规完整构建、完整冒烟和 `/Applications` 覆盖门禁仍为 rc560。

## 2.12.0-rc530 - 2026-07-27

### Added
- MCP/CLI 新增 `xomo.layer.pattern_fill_settings`，可读取当前选中的图案填充层，或一次替换图案类型、RGB 颜色、不透明度、缩放与 X/Y 相位。
- 批量设置跳过锁定层和非图案填充层，返回真实 `updatedLayerCount`；数值沿用界面与渲染模型的归一化边界。

### Fixed
- 重复设置不再伪装成功或制造多余 Undo/History；未知图案类型在修改文档前明确失败。

### Verification
- MCP schema、读取、批量更新、锁定跳过、数值归一化、重复空操作与未知类型定向 Xcode 测试 1/1 通过；CLI 2/2、发布契约 4/4（10 个断言）通过。
- rc529 通用 Release（`arm64 + x86_64`）已完成签名校验、真实启动并覆盖 `/Applications/Xomo.app`；下一次常规完整门禁仍为 rc560。

## 2.12.0-rc529 - 2026-07-27

### Fixed
- 修复 macOS 13 画布拖放宿主偶发只发送拖拽更新、不发送结束阶段，导致矩形选区看似正在框选、松手后却没有选区，渐变工具也无法真正落笔的问题。
- 矩形选区与渐变现在由同一原生鼠标事务完整接管按下、移动和松开；选区在切换渐变工具后继续保留，渐变仍只修改选区遮罩内的像素。

### Verification
- Computer Use 在安装版复现出“工具可切换、拖拽坐标会更新，但松手后无历史”的失衡事件流；新增原生拖拽接线契约和“矩形框选 → 切换渐变 → 仅填充选区”业务回归。
- Xcode 定向测试 3/3、CLI 2/2、发布契约 4/4（10 个断言）通过，三语资源语法检查通过。
- 组件库模式继续恢复系统箭头，现有对象移动与中键画布平移仍使用各自独立事务；下一次完整构建、冒烟和 `/Applications` 覆盖门禁仍为 rc560。

## 2.12.0-rc528 - 2026-07-27

### Added
- MCP/CLI 的 `xomo.layer.create` 创建图案填充图层时，新增 `patternKind`、`patternRed`、`patternGreen`、`patternBlue`、`patternOpacity` 与 `patternScale` 可选参数，不再只能继承界面里碰巧留下的图案设置。
- 图案类型 schema 直接列出棋盘格、斜纹和圆点三种合法值；颜色、不透明度、缩放与既有相位偏移统一走图案填充模型的归一化边界。

### Verification
- 自动化专项覆盖完整 schema、三种图案枚举、颜色/不透明度/缩放/相位边界归一化，以及未知图案拒绝且不创建图层。
- 组件库模式继续由统一光标解析器强制恢复系统箭头，全部工具采用既有成熟软件语义映射；下一次完整构建、冒烟和 `/Applications` 覆盖门禁仍为 rc560。

## 2.12.0-rc527 - 2026-07-27

### Added
- 图案填充图层新增 X/Y 相位偏移，属性面板可在 `-128...128 px` 内调整铺图原点，图层摘要同步显示当前偏移。
- 相位通过 AppKit `patternPhase` 参与实际渲染，并写入项目文件；旧项目缺少偏移字段时自动回退为 `0, 0`。
- MCP/CLI 的 `xomo.layer.create` 在创建图案填充图层时接受可选 `offsetX`、`offsetY`，并使用与界面相同的边界归一化。

### Fixed
- 图案填充控制项使用明确的视图类型擦除边界，避免继续加深右侧属性面板的超大 SwiftUI 泛型树并触发 Swift 运行时元数据递归栈溢出。

### Verification
- 图案填充真实相位渲染、批量更新、旧项目兼容、项目往返与 MCP schema/调用定向测试 3/3 通过；测试宿主可正常构建属性面板并执行用例。
- 工具冒烟与三语本地化套件通过，三语 3292 个键一致；CLI 2/2、发布契约 4/4（10 条断言）通过。下一次完整构建、完整冒烟和 `/Applications` 覆盖门禁仍为 rc560。

## 2.12.0-rc526 - 2026-07-27

### Fixed
- 修复左侧工具栏在侧栏重建、组件拖拽或 Lazy Grid 复用后可能整体失去鼠标命中的问题：不再给 30 个工具分别挂透明 AppKit 视图，而由一个固定尺寸、不可键盘聚焦的原生网格命中面统一处理首个 `mouseDown`。
- 原生网格按固定行列和间距把鼠标位置映射到工具索引，间隙不会误触；选区工具右下角仍单独打开形状菜单，悬停、辅助功能名称与选中反馈保持不变。

### Verification
- 30 个网格单元映射、侧栏重建与选区子菜单定向单元测试通过；工具冒烟、rc525 图案叠加相位及缩放回归通过。
- Computer Use 在组件库往返后以真实屏幕坐标逐项点击 30 个工具，滚动到列表底部后路径选择、直接选择、抓手与缩放同样首击生效，结果 30/30。
- CLI 测试 2/2、发布契约 4/4（10 条断言）通过；下一次完整构建、完整冒烟和 `/Applications` 覆盖门禁仍为 rc560。

## 2.12.0-rc525 - 2026-07-23

### Added
- 图案叠加新增 X/Y 相位偏移，属性面板以不可键盘聚焦的步进控件支持多选混合值、锁定层跳过与单步 History/Undo/Redo。
- 图案相位通过 AppKit `patternPhase` 真正参与合成渲染，并写入项目及图层样式预设；效果缩放、画布缩放同步缩放相位，旧项目缺失字段时回退原点。
- `xomo.layer.style_settings` 新增 `patternOverlayOffsetX` 与 `patternOverlayOffsetY`，返回实际修改图层数并拒绝重复空操作。

### Verification
- 待完成图案叠加相位事务、真实渲染与持久化、缩放、界面契约、MCP、三语本地化、CLI 与发布契约定向验证；下一次完整构建、冒烟和 `/Applications` 覆盖门禁为 rc560。

## 2.12.0-rc524 - 2026-07-23

### Added
- 描边图案新增 X/Y 相位偏移，可在属性面板以不可键盘聚焦的步进控件调整；多选混合值、锁定层跳过、单步 History/Undo/Redo、效果缩放与画布缩放均采用一致语义。
- 图案偏移写入项目和图层样式预设，旧项目缺少该字段时回退到原点；渲染使用 AppKit 原生 `patternPhase`，实际移动铺图而非只改变参数。
- `xomo.layer.style_settings` 新增 `strokePatternOffsetX` 与 `strokePatternOffsetY`，返回实际修改图层数并拒绝重复空操作。

### Fixed
- 修复关闭 Xcode 自动签名后的增量测试宿主可能保留失效资源封印、被 macOS 在 XCTest 连接前强制终止的问题；测试包完成签名后会同步重签并严格校验其宿主 App。

### Verification
- 关闭并行后，描边图案偏移、真实渲染/持久化、效果与画布缩放、界面契约、MCP、本地化以及工具功能冒烟定向 Xcode 测试 40/40 通过；Debug 测试包自动重签后宿主可通过 `codesign --verify --deep --strict` 并正常启动。
- Computer Use 在当前 `/Applications/Xomo.app` 逐项点击全部 30 个工具 30/30，并验证“工具 → 组件库 → 工具 → 画笔”往返后第一击仍立即生效；CLI 2/2、发布契约 4/4（10 个断言）通过，三语 3286 个本地化键一致。下一次完整构建、冒烟和 `/Applications` 覆盖门禁为 rc560。

## 2.12.0-rc523 - 2026-07-23

### Added
- 描边填充为图案时，可直接编辑图案颜色；颜色入口支持多选混合值、不可键盘聚焦、锁定层跳过、单步 History/Undo/Redo，并在切换到图案描边时保留每层既有图案种类与缩放。
- `xomo.layer.style_settings` 新增 `strokePatternColor`，使用当前前景色调用与界面相同的批量事务，返回实际修改图层数并拒绝重复空操作。

### Verification
- 描边图案颜色事务、界面契约、MCP schema/调用与三语本地化定向 Xcode 测试 5/5 通过；CLI 测试 2/2、发布契约 4/4（10 个断言）通过，三语 `Localizable.strings` 语法正常且 3284 个键一致。下一次完整构建、冒烟和 `/Applications` 覆盖门禁为 rc560。

## 2.12.0-rc522 - 2026-07-23

### Added
- 描边填充为渐变时，可分别编辑起点和终点颜色；两个颜色入口支持多选混合值、不可键盘聚焦、锁定层跳过、单步 History/Undo/Redo，并且修改一端不会覆盖已有的另一端。
- `xomo.layer.style_settings` 新增 `strokeGradientStartColor` 与 `strokeGradientEndColor`，分别使用当前前景色和背景色，与界面复用同一批量事务并返回实际修改图层数。

### Verification
- 描边渐变颜色事务、界面契约、MCP schema/调用与三语本地化定向 Xcode 测试 4/4 通过；CLI 测试 2/2、发布契约 4/4（10 个断言）通过，三语 `Localizable.strings` 语法正常且 3283 个键一致。下一次完整构建、冒烟和 `/Applications` 覆盖门禁为 rc560。

## 2.12.0-rc521 - 2026-07-23

### Fixed
- 修复左侧工具栏在侧栏重建或组件库往返后偶发“图标可见但全部点不动”：原生命中面不再依赖 Lazy Grid 推导无固有尺寸的透明 `NSButton`，改为与图标严格一致的固定 36 × 36 `NSView`，在 `mouseDown` 首击直接切换工具且永不获取键盘焦点。

### Verification
- 原生命中源码/行为专项 2/2、工具冒烟 31/31、组件库往返 1/1、CLI 2/2、发布契约 4/4（10 条断言）通过；单任务 `build-for-testing` 与 macOS 13 双架构 Release 构建成功。
- Computer Use 在安装版上按真实屏幕坐标逐项点击全部 30 个工具：可见区 26/26、滚动区 4/4；“工具 → 组件库 → 工具 → 画笔”往返后仍可首击切换。
- `codesign --verify --deep --strict` 可通过的 Apple Development 新签名仍被当前系统在新 CDHash 启动前终止；同一双架构产物使用仓库支持的本地 ad-hoc 签名后可稳定启动、严格验签并覆盖安装到 `/Applications/Xomo.app`。未删除隔离或来源属性规避系统安全策略。

## 2.12.0-rc520 - 2026-07-23

### Changed
- 执行每 40 个候选版本一次的完整质量门禁，不引入新的产品行为；统一复核 macOS 13 部署目标、主程序、CLI、全量测试、Release 双架构、签名、安装包与真实工具点击。

### Verification
- 单任务整包测试在 Swift Testing 内部并发下出现共享 AppKit/CoreGraphics 状态互相污染，因此改按测试 Suite 分进程审计：覆盖 1,507 项测试、93 个 Suite，68 个 Suite 直接通过；其余 25 个并发敏感 Suite 已保留到 `test-reports/rc520-suites/report.json` 与 Markdown 报告，后续继续拆成单测试隔离，未把“组失败”误报成 871 项断言失败。
- 关键交互专项已独立通过：工具冒烟 31/31、画布光标 33/33、图层行批量属性 126/126；发布契约 4/4（10 条断言）通过。
- 首轮 `build-for-testing` 遇到 Swift 批编译对象文件丢失；切换单任务、whole-module 编译后完整测试构建成功。Release 双架构 `arm64 + x86_64` 构建成功，部署目标保持 macOS 13，版本/构建号为 `2.12.0-rc520 (520)`。
- 当前机器的 Developer ID 证书链不受系统信任，Developer ID 与 ad-hoc 产物均被当前 macOS 拒绝启动；改用本机 Apple Development 身份签名后完成真实启动、套索→画笔→橡皮擦点击及组件库默认箭头语义冒烟，并覆盖安装到 `/Applications/Xomo.app`。

## 2.12.0-rc519 - 2026-07-23

### Changed
- 光泽（Satin）的透明度、颜色、距离、大小、角度、反相与等高线七项 setter 统一返回实际修改图层数；混合选择只修改不匹配的可编辑图层，锁定层保持不变。
- `xomo.layer.style_settings` 的七项光泽属性现在返回 `updatedLayerCount`；重复设置明确失败，不再伪装成成功，也不会增加撤销或历史记录。

### Verification
- 新增表驱动专项测试，逐项覆盖七类 MCP 参数、实际修改计数、锁定层、选择保持、重复设置及 Undo/Redo；Xcode 精确目标测试真实执行 1/1 通过（表内覆盖 7 项属性）。
- 主程序与测试目标编译通过；CLI 测试 2/2、发布契约 4/4（10 条断言）通过。Xcode 测试宿主最初被 macOS 26 拒绝执行 ad-hoc 签名，改用本机有效 Apple Development 签名并严格校验后正常启动。

## 2.12.0-rc518 - 2026-07-23

### Added
- `xomo.layer.style_settings` 新增 `shadowUsesGlobalLight`、`innerShadowUsesGlobalLight` 与 `bevelUsesGlobalLight` 三个布尔属性，MCP/CLI 现在可以分别切换投影、内阴影和斜面与浮雕的全局光联动。

### Changed
- 三类全局光开关统一返回实际修改的 `updatedLayerCount`；混合选择只收敛可编辑图层，锁定层保持不变，重复设置明确失败且不产生多余撤销或历史记录。
- 从全局光切换到本地光时保留当前解析后的视觉角度；切回全局光时立即采用文档全局光角度，与界面三态开关、渲染、项目持久化和撤销/重做保持同一语义。

### Verification
- 新增专项测试覆盖 MCP schema、三种效果的混合选择收敛、实际修改计数、锁定层、重复设置、视觉角度保持及撤销/重做，Xcode 目标测试真实执行 2/2 通过。
- 主程序与测试目标编译通过；CLI 测试 2/2、发布契约 4/4（10 条断言）通过。测试插件写入后曾使缓存中的 Debug 宿主封装签名失效，深层临时重签并严格校验后，目标测试正常启动并通过。

## 2.12.0-rc517 - 2026-07-23

### Fixed
- 修复左侧工具图标可见但整列无法用鼠标点击的阻断回归：AppKit 命中层现在显式填满每个 36 × 36 pt 工具格，不再因 `NSViewRepresentable` 没有固有尺寸而退化为零命中区域。
- 工具格改用原生无边框 `NSButton` 的 mouse-down target-action 路径；按下立即切换工具、接受非活动窗口第一次点击，同时继续拒绝键盘焦点并保留悬停、选中、帮助和辅助功能语义。

### Verification
- Debug 主程序构建通过；工具条原生 mouse-down 与辅助功能命名专项测试真实执行 2/2 通过，CLI 测试 2/2、发布契约 4/4（10 条断言）通过。
- 使用 Computer Use 在 rc517 产物中连续切换“套索 → 画笔 → 橡皮擦”，3/3 均即时生效；同一产物已完成严格签名校验并安装到 `/Applications/Xomo.app`。
- XCUITest Runner 两次均在建立测试连接前被系统终止，因此没有把它计作通过；该基础设施异常不影响上述原生控件专项测试与真实应用交互结果。

## 2.12.0-rc516 - 2026-07-23

### Fixed
- 斜面与浮雕“光照角度”现在返回真实的可编辑选中层修改数，并明确报告本次操作是否同步改变文档全局光；混合选择在一次事务中收敛，锁定层与重复值安全跳过。
- 使用全局光时角度变化继续联动文档中所有已链接的投影、内阴影和斜面；使用本地光时只修改选中层。两条路径都保持大小、透明度、柔化、方向与颜色参数，每次只生成一步 Undo/History。

### Automation
- `xomo.layer.style_settings property=bevelAngle` 返回 `updatedLayerCount` 与 `globalLightUpdated`；规范化后没有变化时明确失败。跨文档的完整联动层/效果统计继续由显式 `globalLightAngle` 操作返回。

### Verification
- Xcode 专项 3/3、SwiftPM CLI 2/2、发布契约 4/4（10 条断言）通过，覆盖全局/本地光分支、角度规范化、混合值收敛、参数隔离、锁定层保护、跨层投影联动、单步 Undo/Redo、重复值零历史、MCP schema、真实修改数与全局光标记。常规完整 Release、冒烟与 `/Applications` 覆盖门禁仍为 rc520；下一小步处理斜面“使用全局光”开关事务。

## 2.12.0-rc515 - 2026-07-23

### Fixed
- 斜面与浮雕“方向”现在完整返回真实批量修改数；多选方向不一致时继续显示“多个值”，选择“上”或“下”后一次收敛全部可编辑目标，锁定层与重复值安全跳过。
- 方向事务只启用斜面并修改方向；大小、透明度、柔化、高光/阴影颜色和光照参数保持，每次批量操作只生成一步 Undo/History，选择不会丢失。

### Automation
- `xomo.layer.style_settings property=bevelDirection` 返回真实 `updatedLayerCount`；没有图层需要变化时明确失败，不再返回含糊的通用动作结果。

### Verification
- Xcode 专项 3/3、SwiftPM CLI 2/2、发布契约 4/4（10 条断言）通过，覆盖多选混合值、不可聚焦本地化选择器、参数隔离、锁定层保护、单步 Undo/Redo、重复值零历史、MCP schema、真实修改数和零变化失败。常规完整 Release、冒烟与 `/Applications` 覆盖门禁仍为 rc520；下一小步收紧斜面光照角度事务。

## 2.12.0-rc514 - 2026-07-23

### Fixed
- 斜面与浮雕“柔化”现在显示真实的多选共同值；可编辑图层数值不一致时提示“多个值”，调整后一次收敛全部目标，锁定层与重复值安全跳过。
- 柔化值统一限制在 0–24 px，只启用斜面并修改柔化；大小、透明度、高光/阴影颜色、方向和光照参数保持，每次批量操作只生成一步 Undo/History，选择不会丢失。

### Automation
- `xomo.layer.style_settings property=bevelSoften` 返回真实 `updatedLayerCount`；没有图层需要变化时明确失败，不再把空操作报告为成功。

### Verification
- Xcode 专项 3/3、SwiftPM CLI 2/2 通过，覆盖混合值收敛、0–24 px 夹取、参数隔离、锁定层保护、单步 Undo/Redo、重复值零历史、MCP schema、真实修改数和零变化失败。额外清理了遗留的 Xcode Debug 测试宿主，只保留 `/Applications/Xomo.app`，Computer Use 真实坐标连续点击工具与组件库往返均即时切换；常规完整 Release、冒烟与安装门禁仍为 rc520。

## 2.12.0-rc513 - 2026-07-23

### Fixed
- 斜面与浮雕“阴影颜色”现在显示真实的多选共同值；可编辑图层颜色不一致时提示“多个值”，选择颜色后一次收敛全部目标，锁定层与重复值安全跳过。
- 阴影颜色统一归一化到 sRGB，只启用斜面并修改阴影色；高光色、大小、透明度、柔化、方向和光照参数保持，每次批量操作只生成一步 Undo/History，选择不会丢失。

### Automation
- `xomo.layer.style_settings property=bevelShadowColor` 使用当前前景色并返回真实 `updatedLayerCount`；没有图层需要变化时明确失败，工具描述同步声明真实计数语义。

### Verification
- Xcode 专项 3/3、SwiftPM CLI 2/2、发布契约 4/4（10 条断言）通过，覆盖 Display P3→sRGB、多选混合值、不可聚焦颜色入口、高光/阴影参数隔离、锁定层保护、单步 Undo/Redo、重复值零历史、MCP schema、真实修改数和零变化失败。常规完整 Release、冒烟与 `/Applications` 覆盖门禁仍为 rc520；下一小步处理斜面柔化事务。

## 2.12.0-rc512 - 2026-07-23

### Fixed
- 斜面与浮雕“高光颜色”现在显示真实的多选共同值；可编辑图层颜色不一致时提示“多个值”，选择颜色后一次收敛全部目标，锁定层与重复值安全跳过。
- 高光颜色统一归一化到 sRGB，只启用斜面并修改高光色；阴影色、大小、透明度、柔化、方向和光照参数保持，每次批量操作只生成一步 Undo/History，选择不会丢失。

### Automation
- `xomo.layer.style_settings property=bevelHighlightColor` 使用当前前景色并返回真实 `updatedLayerCount`；没有图层需要变化时明确失败，工具描述同步声明真实计数语义。

### Verification
- Xcode 专项 3/3、SwiftPM CLI 2/2、发布契约 4/4（10 条断言）通过，覆盖 Display P3→sRGB、多选混合值、不可聚焦颜色入口、参数隔离、锁定层保护、单步 Undo/Redo、重复值零历史、MCP schema、真实修改数和零变化失败。常规完整 Release、冒烟与 `/Applications` 覆盖门禁仍为 rc520；下一小步处理斜面阴影颜色事务。

## 2.12.0-rc511 - 2026-07-23

### Fixed
- 左侧 26 个工具格不再依赖 `ScrollView` / 组件拖拽共享的 SwiftUI tap 手势链；每个工具使用独立 AppKit 命中面，在鼠标按下时立即切换，避免拖拽或视图切换后工具栏看得见却点不动。
- 工具命中面显式接受非活动窗口的第一次点击，同时保持不可聚焦、无焦点环；36 × 36 pt 命中范围、悬停、选中、帮助提示、白色图标、辅助功能动作和矩形选区子菜单保持不变。

### Verification
- Xcode 源码契约与 AppKit mouse-down 行为测试 2/2、Computer Use 真实坐标连续点击套索/画笔/橡皮擦 3/3 通过；组合 UI Runner 编译完成但本机 Xcode 卡在 worker materialize 阶段，未虚报执行通过。SwiftPM CLI 2/2、发布契约 4/4（10 条断言）通过；常规完整 Release 门禁仍为 rc520。

## 2.12.0-rc510 - 2026-07-23

### Fixed
- 斜面与浮雕“透明度”现在显示真实多选共同值；混合选择显示“多个值”，调整后一次收敛全部可编辑图层，锁定层与重复值跳过，选择保持且只生成一步 Undo/History。
- 透明度入口复用不可聚焦的混合数值 Stepper，限制在 5%–100%，仅启用斜面并修改透明度，不改大小、颜色、柔化、方向或光照参数。

### Automation
- `xomo.layer.style_settings property=bevelOpacity` 返回实际 `updatedLayerCount`；没有图层需要变化时明确失败，不再返回含糊的通用动作结果。

### Verification
- Xcode 定向测试 3/3、SwiftPM CLI 2/2、发布契约 4/4（10 条断言）通过，覆盖混合值收敛、锁定层保护、参数隔离、选择保持、单步 Undo/Redo、重复值零历史、界面混合态契约、MCP schema、真实修改数、零变化失败和 5% 下限夹取。常规完整 Release、冒烟与 `/Applications` 覆盖门禁仍为 rc520；下一小步处理斜面高光颜色事务。

## 2.12.0-rc509 - 2026-07-23

### Fixed
- 斜面与浮雕“大小”现在使用真实多选共同值：选中图层的大小不一致时显示“多个值”，调整后一次收敛全部可编辑图层；锁定层和重复值安全跳过，选择保持且只生成一步 Undo/History。
- 大小入口复用不可聚焦的混合数值 Stepper，仍限制在 1–24 px，并只启用斜面与修改大小，不触碰透明度、颜色、柔化、方向或光照参数。

### Automation
- `xomo.layer.style_settings property=bevelSize` 返回实际 `updatedLayerCount`；零变化明确失败，不再用通用动作结果掩盖空操作。

### Verification
- Xcode 定向测试 3/3、SwiftPM CLI 2/2、发布契约 4/4（10 条断言）通过，覆盖混合值收敛、锁定层保护、参数隔离、选择保持、单步 Undo/Redo、重复值零历史、界面混合态契约、MCP schema、真实修改数、零变化失败与 1–24 px 上限夹取。常规完整 Release、冒烟与 `/Applications` 覆盖门禁仍为 rc520；下一小步继续收紧斜面透明度事务。

## 2.12.0-rc508 - 2026-07-23

### Fixed
- 左侧工具格不再依赖可能被组件拖放或临时浮层残留追踪状态吞掉鼠标抬起事件的原生 `Button`；26 个工具统一改为普通命中面、显式轻量点击手势和辅助功能动作，避免整条工具栏突然无法点击。
- 保留 36 × 36 pt 命中范围、选中与悬停反馈、白色图标、不可聚焦语义、帮助提示和稳定辅助功能标识；矩形选区右下角形状菜单仍可独立点击。

### Verification
- 新增源码契约，禁止工具格退回原生按钮追踪并校验显式点击/辅助功能动作；工具栏相关 4 条源码契约通过。整组 `ImageEditorScopeTests` 共执行 132 条，仍有 26 条与本次无关的既有源码契约失败，未冒充整组全绿。
- Computer Use 使用真实坐标通过“选区形状浮层 → 画笔”“组件库插入 → 工具 → 套索 / 魔棒 / 裁切 / 油漆桶”连续点击；CLI 2/2、发布契约 4/4（10 条断言）通过，arm64 + x86_64 Release 编译与归档成功。
- 当前 Xcode 26.6 的 Developer ID 导出在双架构代码目录上产生 `invalid signature (code or signature have been modified)`，且显式分架构签名触发 codesign 内部错误，因此未把无效正式签名包安装。作为阻断主交互热修复，改用主程序签名校验通过、已真实启动验证的 arm64 Debug 包覆盖 `/Applications/Xomo.app`，原 rc506 正式包备份到 `/private/tmp/Xomo-rc506-backup.app`；常规完整门禁仍为 rc520。

## 2.12.0-rc507 - 2026-07-23

### Added
- 图层样式属性面板为图案叠加补齐独立颜色选择器，并提供中、英、日三语标签；颜色选择只启用图案效果并修改颜色，不会重置图案类型、透明度或缩放。

### Automation
- `xomo.layer.style_settings property=patternOverlayColor` 使用当前前景色批量设置图案颜色，返回实际 `updatedLayerCount`；锁定层安全跳过，零变化明确失败且不创建空 Undo/History。

### Verification
- Xcode 定向 5/5、混合状态补充复验 1/1、SwiftPM CLI 2/2、发布契约 4/4（10 条断言）通过；覆盖 sRGB 归一化、多选混合值提示、不可聚焦颜色入口、真实修改数、图案类型/透明度/缩放保持、锁定层保护、Undo/Redo、重复颜色零历史和 MCP 零变化失败。常规完整 Release、全量冒烟与 `/Applications` 覆盖门禁仍为 rc520；下一小步开始收紧斜面与浮雕参数事务。

## 2.12.0-rc506 - 2026-07-23

### Fixed
- 图案叠加缩放现在是参数独立的批量事务：调整 6–64 px 图案尺寸时只启用效果并修改缩放，不再把每个图层已经配置的图案颜色替换为当前前景色。
- 图案类型、颜色和透明度在缩放调整时完整保留；锁定层与重复值安全跳过，零变化不创建空 Undo/History。

### Automation
- `xomo.layer.style_settings property=patternOverlayScale` 现在返回实际 `updatedLayerCount`；没有图层需要变化时明确失败，超出范围的值统一夹取到 6–64 px。

### Verification
- Xcode 定向 3/3、SwiftPM CLI 2/2、发布契约 4/4（10 条断言）通过；覆盖混合值收敛、真实修改数、颜色/透明度保持、锁定层保护、上下限夹取、Undo/Redo、重复值零历史和 MCP 零变化失败。
- 纠正 rc504 本地安装包使用 ad-hoc 重签后与 Sparkle 框架无法通过 macOS 库校验的问题；rc506 改用同一 `ZH2S7D6PL6` Developer ID 签署主程序、Sparkle 与嵌套服务，严格签名与真实启动均通过。已覆盖 `/Applications/Xomo.app`，Computer Use 连续点击移动、画笔、矩形选区、套索、魔棒、裁剪与油漆桶均即时切换。常规完整门禁仍为 rc520；下一小步补齐图案叠加颜色的显式事务。

## 2.12.0-rc505 - 2026-07-23

### Fixed
- 图案叠加透明度现在是参数独立的批量事务：调整 5%–100% 透明度时只启用效果并修改透明度，不再把每个图层已经配置的图案颜色替换为当前前景色。
- 图案类型、颜色和缩放在透明度调整时完整保留；锁定层与重复值安全跳过，零变化不创建空 Undo/History。

### Automation
- `xomo.layer.style_settings property=patternOverlayOpacity` 现在返回实际 `updatedLayerCount`；没有图层需要变化时明确失败，超出范围的值统一夹取到 5%–100%。

### Verification
- Xcode 定向 3/3、SwiftPM CLI 2/2、发布契约 4/4（10 条断言）通过；覆盖混合值收敛、真实修改数、颜色/缩放保持、锁定层保护、范围夹取、Undo/Redo、重复值零历史和 MCP 零变化失败。常规完整 Release、全量冒烟与 `/Applications` 覆盖门禁仍为 rc520；下一小步处理图案叠加缩放事务。

## 2.12.0-rc504 - 2026-07-23

### Fixed
- 组件库拖拽源从可能残留 Transferable 鼠标跟踪会话的 `.draggable` 改为显式 `NSItemProvider` 拖拽；组件放入画布后切回工具栏，单击画笔、橡皮擦等工具不再被悬挂的原生拖拽会话吞掉。
- 点击插入、拖拽预览、组件实际尺寸和画布 Drop 数据格式保持不变；组件库切换后仍重建工具子树，工具按钮继续保持不可聚焦。

### Verification
- 新增“真实拖入组件 → 切回工具 → 连续单击画笔与橡皮擦”的组合 UI 回归，并增加源码契约防止组件拖拽源退回 `.draggable`。Xcode 定向源码契约 3/3、SwiftPM CLI 2/2、发布契约 4/4（10 条断言）及 arm64 Release 编译通过。
- Computer Use 在 rc504 构建中确认画笔、橡皮擦、矩形选区、套索可一次点击切换；点击插入组件、切回工具，以及拖放动作后再次切回时，画笔仍可立即选中。Release 已覆盖 `/Applications/Xomo.app`，包内版本 `2.12.0-rc504 (504)`、Bundle ID `im.some.xomo`、严格签名校验通过。组合 UI 用例本机启动时被 Xcode Runner 卡在 `waiting for workers to materialize`，未把 Runner 中断误记为用例通过；常规完整门禁仍为 rc520。

## 2.12.0-rc503 - 2026-07-23

### Fixed
- 图案叠加类型现在是参数独立的批量事务：切换棋盘格、斜纹或圆点时只启用效果并修改类型，不再把各图层已经配置的图案颜色重置为当前前景色。
- 图案颜色、透明度和缩放在类型切换时完整保留；锁定层和重复类型安全跳过，零变化不创建空 Undo/History。

### Automation
- `xomo.layer.style_settings property=patternOverlayKind` 现在返回实际 `updatedLayerCount`；没有图层需要变化时明确失败，界面与 MCP/CLI 共用同一事务。

### Verification
- Xcode 批量属性套件与精确 MCP 用例 126/126、SwiftPM CLI 2/2、发布契约 4/4（10 条断言）通过；覆盖三种图案类型、颜色/透明度/缩放保持、锁定层保护、真实修改数、Undo/Redo、重复类型零历史及 MCP 零变化失败。常规完整 Release、全量冒烟与 `/Applications` 覆盖门禁仍为 rc520；下一小步处理图案叠加透明度事务。

## 2.12.0-rc502 - 2026-07-23

### Added
- MCP `xomo.layer.style_settings` 新增 `gradientOverlayStartColor` 与 `gradientOverlayEndColor`：起始色使用当前前景色，结束色使用当前背景色，可直接驱动多选图层的完整渐变叠加配色。

### Fixed
- 渐变叠加起止色现在返回实际发生变化的可编辑图层数，统一转换为 sRGB；每端颜色独立修改，不触碰另一端颜色、锁定层或其它渐变参数。
- 重复颜色安全跳过，零变化不创建空 Undo/History；MCP 对零变化明确失败并返回真实 `updatedLayerCount`。

### Verification
- Xcode 批量属性套件与精确 MCP 用例 126/126、SwiftPM CLI 2/2、发布契约 4/4（10 条断言）通过；覆盖 Display P3→sRGB 归一化、前景/背景色路由、两端颜色互不串改、锁定层保护、真实修改数、Undo/Redo、重复颜色零历史及 MCP 零变化失败。常规完整 Release、全量冒烟与 `/Applications` 覆盖门禁仍为 rc520；下一小步开始收紧图案叠加类型事务。

## 2.12.0-rc501 - 2026-07-23

### Fixed
- 渐变叠加样式现在是参数独立的批量事务：切换线性、径向、角度、对称或菱形样式时只启用效果并修改样式，不再覆盖各图层已经配置的渐变起止色。
- 批量样式切换返回实际发生变化的可编辑图层数；锁定层和重复样式安全跳过，零变化不创建空 Undo/History；旧的隐式颜色初始化辅助代码已移除，显式启用效果仍保留原有默认色初始化行为。

### Automation
- `xomo.layer.style_settings property=gradientOverlayStyle` 现在返回 `updatedLayerCount`；没有图层需要变化时明确失败，界面与 MCP/CLI 共用同一事务。

### Verification
- Xcode 批量属性套件与精确 MCP 用例 125/125、SwiftPM CLI 2/2、发布契约 4/4（10 条断言）通过；覆盖五种样式枚举、渐变起止色保留、启用状态、锁定层保护、真实修改数、重复样式零历史及 MCP 零变化失败。常规完整 Release、全量冒烟与 `/Applications` 覆盖门禁仍为 rc520；下一小步处理渐变叠加起止色的真实批量修改数。

## 2.12.0-rc500 - 2026-07-23

### Fixed
- 渐变叠加角度现在是参数独立的批量事务：只启用渐变叠加并把任意输入规范化到 -180°–180°，不再在效果尚未启用时覆盖各图层已经配置的渐变起止色。
- 批量角度调整返回实际发生变化的可编辑图层数；锁定层和等价角度安全跳过，零变化不创建空 Undo/History。

### Automation
- `xomo.layer.style_settings property=gradientOverlayAngle` 现在返回 `updatedLayerCount`；没有图层需要变化时明确失败，480° 与 -240° 等等价角度遵循同一规范化与零变化语义。

### Verification
- Xcode 批量属性套件与精确 MCP 用例 125/125、SwiftPM CLI 2/2、发布契约 4/4（10 条断言）通过；覆盖角度规范化、渐变起止色保留、启用状态、锁定层保护、真实修改数、等价角度零历史及 MCP 零变化失败。常规完整 Release、全量冒烟与 `/Applications` 覆盖门禁仍为 rc520；下一小步处理渐变叠加样式的同类事务一致性。

## 2.12.0-rc499 - 2026-07-23

### Fixed
- 渐变叠加缩放现在是参数独立的批量事务：只启用渐变叠加并修改夹取到 25%–400% 的缩放，不再在效果尚未启用时覆盖各图层已经配置的渐变起止色。
- 批量缩放返回实际发生变化的可编辑图层数；锁定层、重复等价值和不适用层安全跳过，零变化不创建空 Undo/History。

### Automation
- `xomo.layer.style_settings property=gradientOverlayScale` 现在返回 `updatedLayerCount`；没有图层需要变化时明确失败，界面与 MCP/CLI 共用同一事务。

### Verification
- Xcode 批量属性套件与精确 MCP 用例 125/125、SwiftPM CLI 2/2、发布契约 4/4（10 条断言）通过；覆盖各图层渐变起止色保留、启用状态、锁定层保护、真实修改数、重复值零历史及 MCP 零变化失败。下一小步处理渐变叠加角度的同类事务一致性，常规完整 Release、全量冒烟与 `/Applications` 覆盖门禁仍为 rc520。

## 2.12.0-rc498 - 2026-07-23

### Fixed
- 渐变叠加不透明度现在是参数独立的批量事务：只启用渐变叠加并修改夹取到 5%–100% 的不透明度，不再在效果尚未启用时把各图层已配置的起止颜色替换为当前前景色和背景色。
- 批量调整返回实际发生变化的可编辑图层数；锁定层、重复等价值和不适用层安全跳过，零变化不创建空 Undo/History。

### Automation
- `xomo.layer.style_settings property=gradientOverlayOpacity` 现在返回 `updatedLayerCount`；没有图层需要变化时明确失败，界面与 MCP/CLI 继续共用同一事务。

### Verification
- Xcode 批量属性套件与精确 MCP 用例 125/125、SwiftPM CLI 2/2、发布契约 4/4（10 条断言）通过；覆盖各图层渐变起止色保留、启用状态、锁定层保护、真实修改数、重复值零历史和 MCP 零变化失败。下一小步处理渐变叠加缩放的同类事务一致性，常规完整 Release、全量冒烟与 `/Applications` 覆盖门禁仍为 rc520。

## 2.12.0-rc497 - 2026-07-23

### Fixed
- 设置颜色叠加颜色现在返回实际发生变化的可编辑图层数；锁定层、不适用层以及已经启用且颜色相同的图层不会被虚报为成功。
- 批量改色只启用颜色叠加并修改颜色，保留每个图层原有的不透明度；重复值不创建空 Undo/History，Undo/Redo 仍以一次批量事务恢复。

### Automation
- `xomo.layer.style_settings property=colorOverlayColor` 现在返回 `updatedLayerCount`；没有图层需要变化时明确失败，工具描述同步声明颜色与不透明度都具备真实计数。

### Verification
- Xcode 批量属性套件与精确 MCP 用例 125/125、SwiftPM CLI 2/2、发布契约 4/4（10 条断言）通过；覆盖启用状态、颜色收敛、不透明度保留、锁定层保护、真实修改数、重复值零历史及 MCP 零变化失败。下一小步处理渐变叠加不透明度的同类事务一致性，常规完整 Release、全量冒烟与 `/Applications` 覆盖门禁仍为 rc520。

## 2.12.0-rc496 - 2026-07-23

### Fixed
- 颜色叠加的不透明度现在是独立参数：调整时只启用颜色叠加并修改 5%–100% 不透明度，不再把每个图层原有的叠加颜色偷偷替换为当前前景色。
- 多选批量调整返回实际变化的可编辑图层数；锁定层和重复等价值安全跳过，零变化不再制造空 Undo/History。

### Automation
- `xomo.layer.style_settings property=colorOverlayOpacity` 现在返回 `updatedLayerCount`，没有图层需要变化时明确失败；MCP 与界面继续共用同一事务。

### Verification
- Xcode 批量属性套件与精确 MCP 用例 124/124、SwiftPM CLI 2/2、发布契约 4/4（10 条断言）通过；覆盖多选混合值收敛、各图层颜色保留、锁定层保护、真实更新数量、重复值零历史及 MCP 零变化失败。下一次常规完整 Release、全量测试、冒烟与 `/Applications` 覆盖门禁仍为 rc520。

## 2.12.0-rc495 - 2026-07-23

### Fixed
- 修复选区形状菜单打开后左侧工具看似全部无法点击的问题：原生临时 Popover 会吞掉下一次窗口外点击，现改为主窗口内的非阻塞浮层。
- 左侧工具按钮统一通过同一入口先关闭形状菜单、再立即切换工具；点击工具或切换工具/组件库只需一次，不再用第一下专门关弹层。浮层继续保持不可聚焦、深色外观、四种形状选择与辅助功能按钮语义。

### Verification
- Xcode 工具栏定向测试 3/3、SwiftPM CLI 2/2、发布契约 4/4（10 条断言）通过；双架构 Release、版本、macOS 13 下限和本地签名严格校验通过。
- 作为阻断主交互修复，本版已覆盖安装 `/Applications/Xomo.app`；Computer Use 在安装版中真实打开形状浮层后，单击一次画笔即切换并关闭浮层，魔棒与裁剪也均可立即切换。下一次常规完整门禁仍为 rc520。

## 2.12.0-rc494 - 2026-07-23

### Added
- 内发光补齐 Photoshop 式“柔和 / 精确”技术选择；精确模式用两遍线性距离场沿真实 Alpha 内轮廓计算光晕，边缘来源向内衰减，中心来源反向使用轮廓距离，因此异形对象不再退化为矩形径向渐变。
- 内发光技术贯通多选混合值、锁定层跳过、单步 History/Undo、不可聚焦三语界面、工程与样式预设往返，以及 MCP/CLI `xomo.layer.style_settings property=innerGlowTechnique`。

### Compatibility
- 新建样式默认“柔和”；旧工程没有 `innerGlowTechnique` 字段时同样回退为“柔和”，保持既有视觉。

### Verification
- Xcode 定向测试 4/4、SwiftPM CLI 2/2、发布契约 4/4（10 条断言）通过；真实像素回归覆盖技术差异、精确模式确定性、Alpha 轮廓内侧衰减、源图层像素不变与工程兼容。下一次完整 Release、全量测试、冒烟和 `/Applications` 覆盖门禁仍为 rc520。

## 2.12.0-rc493 - 2026-07-23

### Fixed
- 组件库卡片不再把原生 `Button` 跟原生拖拽源挂在同一个视图上；点击插入改为普通命中视图的轻量点击手势，拖放保持独立，避免拖拽结束后 AppKit 按钮追踪状态滞留、导致左侧工具整体收不到真实鼠标事件。
- 组件卡片继续暴露按钮语义与默认辅助功能动作，点击插入、拖入画布、选中反馈和键盘/辅助功能访问能力不倒退。

### Verification
- 新增源码结构回归，禁止组件卡片重新组合原生按钮追踪与拖拽源；Xcode 定向测试 1/1、SwiftPM CLI 2/2、发布契约 4/4（10 条断言）与 Release 签名校验通过。
- 已覆盖安装 `/Applications/Xomo.app`，并用 Computer Use 真实点击验证“组件库 → 点击插入组件 → 工具 → 矩形选区 / 套索 / 魔棒 / 画笔 / 橡皮擦”，以及模拟组件拖拽后返回移动工具，全部即时响应。由于这是阻断主交互的修复，本版额外发布，下一次常规完整门禁仍为 rc520。

## 2.12.0-rc492 - 2026-07-23

### Added
- 外发光增加 Photoshop 式“技术”选择：柔和沿用高斯扩散，精确使用线性复杂度的轮廓距离场，贴合真实 Alpha 边缘且不模糊源遮罩内部。
- 技术参数贯通不可聚焦的三语多选下拉、锁定层跳过、单步 Undo/Redo、工程与样式预设往返，以及 MCP/CLI `xomo.layer.style_settings(property=outerGlowTechnique)` 的真实 `updatedLayerCount`。

### Fixed
- 旧工程缺少技术字段时固定恢复“柔和”，保持历史渲染；重复设置同一技术不会制造空 History。

### Verification
- Xcode 定向测试 3/3 通过，覆盖柔和/精确真实像素差异、确定性重绘、工程/旧格式往返、多选事务、不可聚焦界面接线与 MCP 枚举修改计数；SwiftPM CLI 2/2、发布契约 4/4（10 条断言）通过。下一次完整 Release、全量冒烟与 `/Applications` 覆盖门禁仍为 rc520。

## 2.12.0-rc491 - 2026-07-23

### Added
- “外发光”增加 Photoshop 式抖动控制：0%–100% 在轮廓与范围计算后对最终光晕 Alpha 施加确定性纹理，与模糊前作用的“杂色”保持独立语义。
- 抖动参数贯通不可聚焦的三语多选步进器、锁定层跳过、单步 Undo/Redo、工程与样式预设往返，以及 MCP/CLI `xomo.layer.style_settings(property=outerGlowJitter)` 的真实 `updatedLayerCount`。

### Fixed
- 重复或夹取后等价的抖动输入不再制造空 History；旧工程缺少字段时恢复 0%，不会改变历史画面。

### Verification
- Xcode 定向测试 4/4 通过，覆盖真实外发光像素差异、确定性重绘、工程/旧格式往返、多选事务、不可聚焦界面接线与 MCP 修改计数；SwiftPM CLI 2/2、发布契约 4/4（10 条断言）通过。下一次完整 Release、全量冒烟与 `/Applications` 覆盖门禁仍为 rc520。

## 2.12.0-rc490 - 2026-07-23

### Added
- “外发光”增加 Photoshop 式范围控制：1%–100% 真实重映射轮廓后的 Alpha 衰减；新样式默认 50%，旧工程缺字段时按 100% 恢复，保持历史画面不变。
- 范围参数贯通不可聚焦的三语多选步进器、锁定层跳过、单步 Undo/Redo、工程与样式预设往返，以及 MCP/CLI `xomo.layer.style_settings(property=outerGlowRange)` 的真实 `updatedLayerCount`。

### Fixed
- 重复或夹取后等价的范围输入不再制造空 History；调整范围不会覆盖颜色、透明度、模糊、扩展、杂色或轮廓。

### Verification
- Xcode 定向测试 4/4 通过，覆盖真实外发光像素差异、工程/旧格式往返、多选事务、不可聚焦界面接线与 MCP 修改计数；SwiftPM CLI 2/2、发布契约 4/4（10 条断言）通过。下一次完整 Release、全量冒烟与 `/Applications` 覆盖门禁仍为 rc520。

## 2.12.0-rc489 - 2026-07-23

### Added
- “内发光”增加 Photoshop 式抖动控制：0%–100% 在轮廓与范围计算后对最终光晕 Alpha 施加确定性纹理，与模糊前的“杂色”形成可见且稳定的语义区分。
- 抖动参数贯通不可聚焦的三语多选步进器、锁定层跳过、单步 Undo/Redo、工程与样式预设往返，以及 MCP/CLI `xomo.layer.style_settings(property=innerGlowJitter)` 的真实 `updatedLayerCount`。

### Fixed
- 重复或夹取后等价的抖动输入不再制造空 History；旧工程缺少抖动字段时恢复为 0%，保持既有画面不变。

### Verification
- Xcode 定向测试 5/5 通过，覆盖真实像素差异与确定性、工程/旧格式往返、多选事务、不可聚焦界面接线、MCP 修改计数及组件库前一工具光标不泄漏；SwiftPM CLI 2/2、发布契约 4/4（10 条断言）通过。下一次完整 Release、全量冒烟与 `/Applications` 覆盖门禁仍为 rc520。

## 2.12.0-rc488 - 2026-07-23

### Added
- “内发光”增加 Photoshop 式范围控制：1%–100% 会真实重映射等高线后的 Alpha 衰减；新样式默认 50%，旧工程缺少该字段时按 100% 恢复，避免历史画面变化。
- 范围参数贯通不可聚焦的三语多选步进器、单步 Undo/Redo、Xomo 工程往返及 MCP/CLI `xomo.layer.style_settings(property=innerGlowRange)`，并返回真实 `updatedLayerCount`。

### Fixed
- 属性面板从 8 个大 SwiftUI 元数据子树继续细分为 21 个职责分区，并将 15 层调整控件条件树通过 `AnyView` 隔离，修复 rc488 Release 优化版启动时的主线程栈溢出。
- `/Applications` 中滞留的 rc481 已替换为包含 rc485 鼠标事件归属修复的 rc488；组件库拖放后不再让左侧工具栏整体失去点击响应。

### Verification
- Xcode 定向测试 5/5、结构启动回归 1/1、SwiftPM CLI 2/2、发布契约 4/4（10 条断言）通过；通用 Release 双架构构建、严格签名核验和真实启动通过。
- Computer Use 真实坐标验证矩形选区、套索、画笔、橡皮擦即时切换，并通过“组件库 → 拖放 → 工具 → 画笔”回归；安装后的 `/Applications/Xomo.app` 再次验证矩形选区与画笔可点击。

## 2.12.0-rc487 - 2026-07-23

### Added
- “内发光”增加 Photoshop 式等高线控制，提供线性、柔和、陡峭、锥形和环形五种 Alpha 衰减曲线；界面使用本地化、不可聚焦的多选菜单，并支持混合值。
- 等高线参与边缘与中心两类内发光的真实像素合成，并随 Xomo 工程、图层样式预设复制与重开完整保留。
- MCP/CLI `xomo.layer.style_settings(property=innerGlowContour)` 开放同一五档枚举并返回真实 `updatedLayerCount`。

### Fixed
- 多图层修改只收敛可编辑目标并跳过锁定层；首次设置会自动启用内发光，重复设置不制造空 Undo/History，非法枚举和零变化均明确失败。

### Verification
- 内发光等高线批量事务、不可聚焦界面接线、真实像素差异/工程往返及 MCP 枚举与更新计数用例 4/4 真实执行通过；SwiftPM CLI 2/2、发布契约 4/4（10 条断言）通过。下一次完整 Release、全量测试、真实冒烟与 `/Applications` 覆盖门禁仍为 rc520。

## 2.12.0-rc486 - 2026-07-23

### Changed
- “内发光来源”现在是可观测的多图层事务：边缘/中心会收敛所有可编辑选中图层，锁定层安全跳过，并只统计真正发生变化或需要自动启用内发光的图层。
- MCP/CLI `xomo.layer.style_settings(property=innerGlowSource)` 返回真实 `updatedLayerCount`；重复设置不再制造空 History/Undo，而是明确报告没有可修改目标。

### Verification
- 图层样式批量模型与 MCP 注册表定向测试 2/2 通过，覆盖混合值、锁定层、自动启用、属性保留、重复值零操作、实际更新数量和边缘/中心往返；SwiftPM CLI 2/2、发布契约 4/4（10 条断言）通过。下一次完整 Release、全量测试、真实冒烟与 `/Applications` 覆盖门禁仍为 rc520。

## 2.12.0-rc485 - 2026-07-23

### Fixed
- 组件拖动的 AppKit 本地监听器现在只在命中可移动对象后完整接管配对的 `mouseDown`、`mouseDragged` 与 `mouseUp`，避免与 SwiftUI 画布手势同时处理同一条序列，导致拖动结束后左侧工具栏集体失去点击响应。
- 只点按未形成拖动时也会消费配对的释放并清理候选状态；下一次点到画布外会主动结束任何陈旧捕获，再把工具栏点击原样放行。
- 组件库卡片去掉点击期间的异步临时选中重绘，插入与原生拖放保持在同一轮鼠标事件内，避免组件插入后工具/组件 Tab 偶发无法切换。

### Verification
- Xcode 释放归属策略定向测试 2/2、SwiftPM CLI 测试 2/2、发布契约 4/4（10 条断言）通过。
- Computer Use 真实鼠标坐标回归通过“组件插入 → 拖动 → 切回工具”，并确认套索、画笔、油漆桶、文字四个工具均可立即点击切换；下一次完整 Release、全量测试与 `/Applications` 覆盖门禁仍为 rc520。

## 2.12.0-rc484 - 2026-07-23

### Changed
- 内发光噪点支持多选混合值：不同噪点强度同时选中时显示本地化“多个值”，并复用不可聚焦的图层样式数值步进器。
- `xomo.layer.style_settings(property=innerGlowNoise)` 返回实际修改的 `updatedLayerCount`，让 MCP/CLI 调用能够核验批量结果。

### Fixed
- 噪点输入继续夹取到 0%–100%；调整只改变内发光启用状态与噪点强度，不覆盖颜色、透明度、模糊、阻塞或来源，锁定层和不适用层安全跳过。
- 重复值或夹取后等价设置不再制造空 Undo/History；MCP 对零实际变化明确失败。

### Verification
- 模型事务、混合值控件契约与 MCP 批量结果定向测试 3/3，SwiftPM CLI 2/2、发布契约 4/4（10 条断言）通过；下一次完整 Release、全量测试、真实界面冒烟与 `/Applications` 覆盖门禁为 rc520。

## 2.12.0-rc483 - 2026-07-23

### Changed
- 内发光阻塞支持多选混合值：不同阻塞半径同时选中时显示本地化“多个值”，并复用不可聚焦的图层样式数值步进器。
- `xomo.layer.style_settings(property=innerGlowChoke)` 返回实际修改的 `updatedLayerCount`，让 MCP/CLI 调用能够核验批量结果。

### Fixed
- 阻塞输入继续夹取到 0–24 px；调整只改变内发光启用状态与阻塞半径，不覆盖颜色、透明度、模糊、杂色或来源，锁定层和不适用层安全跳过。
- 重复值或夹取后等价设置不再制造空 Undo/History；MCP 对零实际变化明确失败。

### Verification
- 模型事务、混合值控件契约与 MCP 批量结果定向测试 3/3，SwiftPM CLI 2/2、发布契约 4/4（10 条断言）通过；下一次完整 Release、全量测试、真实界面冒烟与 `/Applications` 覆盖门禁为 rc520。

## 2.12.0-rc482 - 2026-07-23

### Changed
- 内发光模糊半径支持多选混合值：不同模糊半径同时选中时显示本地化“多个值”，并复用不可聚焦的图层样式数值步进器。
- `xomo.layer.style_settings(property=innerGlowBlur)` 返回实际修改的 `updatedLayerCount`，让 MCP/CLI 调用可以核验真实结果。

### Fixed
- 内发光模糊继续夹取到 0–40 px；只更新启用状态与模糊半径，不覆盖颜色、透明度、阻塞、杂色或来源，锁定层和不适用层安全跳过。
- 重复值或夹取后等价的设置不再制造空 Undo/History；MCP 对零实际变化明确失败。

### Verification
- 模型事务、混合值控件契约和 MCP 批量结果定向测试 3/3，SwiftPM CLI 2/2、发布契约 4/4（10 条断言）通过；下一次完整 Release、全量测试、真实界面冒烟与 `/Applications` 覆盖门禁为 rc520。

## 2.12.0-rc481 - 2026-07-23

### Fixed
- 画布对象只有按下候选、尚未跨过拖动阈值时，释放事件现在只清理候选状态并继续传给原目标；不会再误吞工具按钮的 `mouseUp`，修复工具栏偶发整体“点不动”。
- 已进入真实对象移动事务时仍独占并消费释放事件，即使鼠标越过画布或窗口边缘也会可靠结束拖动，不留下闭手光标或半截历史事务。

### Verification
- 真实界面先经过组件库往返与组件插入，再以鼠标坐标逐个点击 26 个当前可见工具，全部即时切换成功；测试插入的组件已用 `Command+Z` 还原。
- 新增对象拖动释放策略回归：真实移动会结束并消费事件，候选态释放与无关拖动事件均不会截走下一层控件的点击。

## 2.12.0-rc480 - 2026-07-23

### Added
- 接入 Sparkle 2 稳定通道自动更新与“检查更新…”菜单；测试环境不会启动网络更新器，更新源、平台与通道由集中配置和单元测试约束。

### Changed
- 内发光颜色 setter 返回实际修改的可编辑选中图层数；MCP `xomo.layer.style_settings(property=innerGlowColor)` 返回 `updatedLayerCount`。
- 内、外发光颜色共用类型擦除的不可聚焦颜色行；多选颜色不一致时显示本地化“多个值”、稳定辅助标识和辅助功能值。
- 全量隔离测试器在 Xcode 未产出 `.xcresult` 且命中工具链启动崩溃时最多自动重试 2 次；真实测试断言仍按原规则立即失败。
- App、测试目标与 UI 测试目标的构建号统一为 `480`；发布契约要求 `CURRENT_PROJECT_VERSION` 与 `-rcN` 的 N 严格一致，避免自动更新把新包误判为旧构建。

### Fixed
- 调整颜色只改变内发光启用状态与颜色，不覆盖透明度、模糊、阻塞、杂色或来源；锁定层与不适用层安全跳过，重复值不制造空 Undo/History，MCP 对零实际变化明确失败。
- 经典“反相”改用确定性的 RGBA 字节通道反相并保留 Alpha，避免 Core Image 线性色彩空间产生与 Photoshop 式 `255 - 通道值` 不一致的结果。
- “图层转背景”烘焙时补齐编辑器左上角坐标到 AppKit 左下角坐标的换算，非全画布图层不再发生纵向位置偏移。
- 裁切、按选区裁切与透明边缘修剪统一在新画布建立全画布选区，并移除裁切区域外的参考线，不再把越界参考线挤到画布边缘。
- 发光颜色控件通过真实 `AnyView` 边界降低 SwiftUI 元数据嵌套深度，避免属性面板在测试或 Release 启动时触发类型实例化栈溢出。

### Verification
- 内发光颜色 4/4、调整 24/24、背景转换 7/7、混合模式 5/5、画布命令 7/7、画布几何 4/4，以及居中缩放、通道预览、Alpha 通道预览、压感回归各 1/1 均通过。
- SwiftPM CLI 2/2、发布版本契约 4/4（10 条断言）通过。
- 自动更新静态审计通过，构建号漂移会由发布契约直接阻断。
- 作为第 480 个小版本，完整 1438 项 App 测试、通用 Release、真实界面冒烟与 `/Applications` 覆盖安装仍是发布前强制门禁；当前未把中途主动停止的 59/1438 冒充完整通过。

## 2.12.0-rc479 - 2026-07-22

### Changed
- 内发光透明度 setter 返回实际修改的可编辑选中图层数；MCP `xomo.layer.style_settings(property=innerGlowOpacity)` 返回 `updatedLayerCount`。
- 透明度控件改用不可聚焦的多选数值步进器，所选可编辑图层数值不一致时显示本地化“多个值”，输入保持 5%–100% 夹取。

### Fixed
- 调整透明度只改变内发光启用状态与透明度，不覆盖颜色、模糊、阻塞、杂色或来源；锁定层与不适用层安全跳过。
- 重复值或夹取后等价值不再制造空 Undo/History，MCP 对零实际变化明确失败。

### Verification
- 混合态、真实数量、5%–100% 夹取、参数保留、锁定层、不可聚焦控件、MCP 结果及弱／强内发光真实合成与工程往返测试 4/4，外发光轮廓相邻回归 4/4 通过。
- SwiftPM CLI 2/2、发布版本契约 7/7 通过；本版不覆盖 `/Applications`，rc480 将执行完整 Release、冒烟与安装覆盖门禁。

## 2.12.0-rc478 - 2026-07-22

### Changed
- 外发光轮廓 setter 返回实际修改的可编辑选中图层数；MCP `xomo.layer.style_settings(property=outerGlowContour)` 返回 `updatedLayerCount`。
- 线性、柔和、陡峭、锥形与环形五档轮廓继续使用不可聚焦的本地化多选菜单，混选时显示“多个值”。

### Fixed
- 轮廓更新只改变外发光启用状态与轮廓，不覆盖颜色、透明度、模糊、扩展或杂色；锁定层与不适用层安全跳过。
- 重复轮廓不再制造空 Undo/History，非法枚举与零实际变化均由 MCP 明确失败。

### Verification
- 混合态、真实数量、五档 schema、参数保留、锁定层、不可聚焦控件、MCP 结果及陡峭／线性真实 Alpha 衰减与工程往返测试 4/4，外发光杂色相邻回归 4/4 通过。
- SwiftPM CLI 2/2、发布版本契约 7/7 通过；本版不覆盖 `/Applications`，下一次完整 Release、冒烟与安装门禁仍为 rc480。

## 2.12.0-rc477 - 2026-07-22

### Changed
- 外发光杂色 setter 返回实际修改的可编辑选中图层数；MCP `xomo.layer.style_settings(property=outerGlowNoise)` 返回 `updatedLayerCount`。
- 杂色控件改用不可聚焦的多选数值步进器，所选可编辑图层数值不一致时显示本地化“多个值”，输入保持 0%–100% 夹取。

### Fixed
- 调整杂色只改变外发光启用状态与杂色参数，不覆盖颜色、透明度、模糊、扩展或轮廓；锁定层与不适用层安全跳过。
- 重复值或夹取后等价值不再制造空 Undo/History，MCP 对零实际变化明确失败。

### Verification
- 混合态、真实数量、0%–100% 夹取、参数保留、锁定层、不可聚焦控件、MCP 结果及真实确定性杂色／工程往返测试 4/4，外发光扩展相邻回归 4/4 通过。
- SwiftPM CLI 2/2、发布版本契约 7/7 通过；本版不覆盖 `/Applications`，下一次完整 Release、冒烟与安装门禁仍为 rc480。

## 2.12.0-rc476 - 2026-07-22

### Changed
- 外发光扩展 setter 返回实际修改的可编辑选中图层数；MCP `xomo.layer.style_settings(property=outerGlowSpread)` 返回 `updatedLayerCount`。
- 扩展控件改用不可聚焦的多选数值步进器，所选可编辑图层数值不一致时显示本地化“多个值”，输入保持 0–24 px 夹取。

### Fixed
- 调整扩展只改变外发光启用状态与扩展参数，不覆盖颜色、透明度、模糊、杂色或轮廓；锁定层与不适用层安全跳过。
- 重复值或夹取后等价值不再制造空 Undo/History，MCP 对零实际变化明确失败。

### Verification
- 混合态、真实数量、0–24 px 夹取、参数保留、锁定层、不可聚焦控件、MCP 结果及真实像素扩张／工程往返测试 4/4，外发光模糊相邻回归 4/4 通过。
- SwiftPM CLI 2/2、发布版本契约 7/7 通过；本版不覆盖 `/Applications`，下一次完整 Release、冒烟与安装门禁仍为 rc480。

## 2.12.0-rc475 - 2026-07-22

### Changed
- 外发光模糊半径 setter 返回实际修改的可编辑选中图层数；MCP `xomo.layer.style_settings(property=outerGlowBlur)` 返回 `updatedLayerCount`。
- 保持既有不可聚焦的多选“多个值”控件和 0–40 px 范围；锁定层及不适用层安全跳过，需要自动启用外发光的图层仍计入真实修改。

### Fixed
- 调整模糊半径只改变外发光启用状态与模糊参数，不覆盖颜色、透明度、扩展、杂色或轮廓。
- 重复值或夹取后等价值不再制造空 Undo/History，MCP 对零实际变化明确失败。

### Verification
- 实际数量、0–40 px 夹取、自动启用、颜色保留、锁定层、不可聚焦控件、MCP 结果以及硬边／软边真实合成与工程往返测试 4/4，外发光颜色相邻回归 4/4 通过。
- SwiftPM CLI 2/2、发布版本契约 7/7 通过；本版不覆盖 `/Applications`，下一次完整 Release、冒烟与安装门禁仍为 rc480。

## 2.12.0-rc474 - 2026-07-22

### Added
- 外发光颜色增加多选混合态；所选可编辑图层颜色不一致时，属性面板显示本地化“多个值”并提供对应辅助功能值。
- 外发光颜色控件增加稳定辅助标识并保持不可聚焦，避免 ColorPicker 抢走编辑器键盘焦点。

### Changed
- 外发光颜色 setter 返回实际修改数量；MCP `xomo.layer.style_settings(property=outerGlowColor)` 使用当前前景色批量应用并返回 `updatedLayerCount`。

### Fixed
- 已使用目标颜色且效果启用、锁定层及不适用层安全跳过，需要自动启用外发光的图层仍计入；颜色更新不改变透明度、模糊、扩展、杂色或轮廓。
- 重复颜色不再制造空 Undo/History，MCP 对零实际变化明确失败。

### Verification
- 混合态、实际数量、自动启用、参数保留、锁定层、不可聚焦控件、MCP 结果及真实颜色合成／工程往返测试 4/4，外发光透明度相邻回归 4/4 通过。
- SwiftPM CLI 2/2、发布版本契约 7/7 通过；本版不覆盖 `/Applications`，下一次完整 Release、冒烟与安装门禁仍为 rc480。

## 2.12.0-rc473 - 2026-07-22

### Changed
- 外发光透明度 setter 返回实际修改的可编辑选中图层数；MCP `xomo.layer.style_settings(property=outerGlowOpacity)` 返回 `updatedLayerCount`。
- 保持既有不可聚焦的多选“多个值”控件和 5%–100% 范围，锁定层及不适用层安全跳过，需要自动启用外发光的图层仍计入真实修改。

### Fixed
- 调整透明度只改变外发光启用状态与透明度，不覆盖用户选定的颜色、模糊、扩展、杂色或轮廓参数。
- 重复值或夹取后等价值不再制造空 Undo/History，MCP 对零实际变化明确失败。

### Verification
- 批量数量、范围夹取、自动启用、颜色保留、零变化、锁定层、不可聚焦控件、MCP 结果及真实合成测试 4/4，外发光杂色与工程往返相邻回归 1/1 通过。
- SwiftPM CLI 2/2、发布版本契约 7/7 通过；本版不覆盖 `/Applications`，下一次完整 Release、冒烟与安装门禁仍为 rc480。

## 2.12.0-rc472 - 2026-07-22

### Changed
- 内阴影角度批量命令返回实际修改的可编辑选中图层数；MCP `xomo.layer.style_settings(property=innerShadowAngle)` 同时返回 `updatedLayerCount` 与 `globalLightUpdated`。
- 保持 Photoshop 式 -180°…180° 角度规范化、全局光／局部光混选语义和不可聚焦的多选步进器；文档全局光变化继续驱动其它链接效果，但不冒充直接编辑数量。

### Fixed
- 调整已经启用的内阴影角度不再把用户定制颜色重置为当前前景色；只有首次启用效果时才初始化颜色。
- 315° 与 -45° 等等价输入不再制造空 Undo/History，锁定层保持不变，MCP 对零实际变化明确失败。

### Verification
- 内阴影角度批量事务、颜色保留、等价角度、锁定层、界面非焦点契约、MCP 结果以及方向性合成测试 4/4、发布版本契约 7/7 通过。
- 外部项目持续占用唯一 Swift 构建槽，本版未并发启动独立 CLI 测试；CLI 与 App 的 rc472 版本一致性已由发布契约验证。
- 本小版本不覆盖 `/Applications`；下一次完整 Release、冒烟与安装门禁仍为 rc480。

## 2.12.0-rc471 - 2026-07-22

### Fixed
- 将属性面板约 1,900 行的单一 SwiftUI `ViewBuilder` 分成八个布局透明分区，避免 Release 全模块优化后在窗口恢复阶段构造超大 `buildBlock` 触发主线程栈溢出。
- 保留 rc466 的组件库往返清理和 36 × 36 pt 工具命中区域，确保覆盖安装后的真实鼠标事件不再落到旧组件拖放视图。

### Verification
- 属性面板分区源码回归 1/1、SwiftPM CLI 2/2、发布版本契约 7/7 通过；rc471 Release 构建、递归签名与 macOS 13 最低版本核验通过。
- Computer Use 在临时 Release 和最终 `/Applications/Xomo.app` 上均完成真实启动、组件库往返，以及画笔中心/橡皮擦边缘坐标点击；套索、矩形选区与油漆桶坐标点击亦通过。

## 2.12.0-rc470 - 2026-07-22

### Changed
- 内阴影距离（Distance）setter 返回实际修改的可编辑选中图层数；MCP `xomo.layer.style_settings(property=innerShadowDistance)` 返回 `updatedLayerCount`。
- 保持既有不可聚焦的多选“多个值”控件和 0–48 px 范围，首次启用内阴影时才使用当前前景色初始化效果颜色。

### Fixed
- 已处于目标距离且内阴影已启用、锁定层及不适用层不再计入更新；需要自动启用内阴影的图层仍计为真实修改。
- 调整已启用内阴影的距离不再覆盖用户定制颜色；重复值或夹取后等价值不再制造空 Undo/History，MCP 对零变化明确失败。

### Verification
- 内阴影距离真实数量、0–48 px 夹取、自动启用、颜色保留、重复值、锁定层、混合值控件、0/11 px 真实像素位移及相邻 Contour 回归测试 5/5 通过；SwiftPM CLI 2/2、发布版本契约 7/7 通过。

## 2.12.0-rc469 - 2026-07-22

### Changed
- 内阴影轮廓（Contour）setter 返回实际修改的可编辑选中图层数；MCP `xomo.layer.style_settings(property=innerShadowContour)` 返回 `updatedLayerCount`。
- 继续使用五档本地化轮廓菜单和公开 MCP 枚举，首次启用内阴影时才使用当前前景色初始化效果颜色。

### Fixed
- 已处于目标轮廓且内阴影已启用、锁定层及不适用层不再计入更新；需要自动启用内阴影的图层仍计为真实修改。
- 调整已启用内阴影的轮廓不再覆盖用户定制颜色；重复枚举不再制造空 Undo/History，MCP 对零变化及非法枚举明确失败。

### Verification
- 内阴影轮廓真实数量、自动启用、颜色保留、重复枚举、锁定层、混合值菜单、非法值拒绝、真实像素衰减/工程往返及相邻 Noise 回归测试 5/5 通过；SwiftPM CLI 2/2、发布版本契约 7/7 通过。

## 2.12.0-rc468 - 2026-07-22

### Changed
- 内阴影杂色（Noise）setter 返回实际修改的可编辑选中图层数；MCP `xomo.layer.style_settings(property=innerShadowNoise)` 返回 `updatedLayerCount`。
- 保持既有不可聚焦的多选“多个值”百分比控件和 0%–100% 范围，首次启用内阴影时才使用当前前景色初始化效果颜色。

### Fixed
- 已处于目标杂色且内阴影已启用、锁定层及不适用层不再计入更新；需要自动启用内阴影的图层仍计为真实修改。
- 调整已启用内阴影的杂色不再覆盖用户定制颜色；重复值或夹取后等价值不再制造空 Undo/History，MCP 对零变化明确失败。

### Verification
- 内阴影杂色真实数量、0%–100% 夹取、自动启用、颜色保留、重复值、锁定层、混合值控件、真实渲染/工程往返及相邻 Choke 回归测试 5/5 通过；SwiftPM CLI 2/2、发布版本契约 7/7 通过。

## 2.12.0-rc467 - 2026-07-22

### Changed
- 内阴影阻塞（Choke）setter 返回实际修改的可编辑选中图层数；MCP `xomo.layer.style_settings(property=innerShadowChoke)` 返回 `updatedLayerCount`。
- 保持既有不可聚焦的多选“多个值”控件和 0–24 px 范围，首次启用内阴影时才使用当前前景色初始化效果颜色。

### Fixed
- 已处于目标阻塞值且内阴影已启用、锁定层及不适用层不再计入更新；需要自动启用内阴影的图层仍计为真实修改。
- 调整已启用内阴影的阻塞值不再覆盖用户定制颜色；重复值或夹取后等价值不再制造空 Undo/History，MCP 对零变化明确失败。

### Verification
- 内阴影阻塞真实数量、0–24 px 夹取、自动启用、颜色保留、重复值、锁定层、混合值控件、真实渲染/工程往返及相邻模糊回归测试 5/5 通过；SwiftPM CLI 2/2、发布版本契约 7/7 通过。

## 2.12.0-rc466 - 2026-07-22

### Changed
- 工具栏按钮的真实标签命中区域扩大到 36 × 36 pt，图标仍保持原有视觉尺寸，按钮中心和边缘都能轻快点击。
- “工具 / 组件库”切换内容使用独立 SwiftUI 子树身份，离开组件库时会销毁组件预览安装的原生拖放命中视图。

### Fixed
- 修复进入组件库再切回工具后，残留的拖放命中层吞掉普通鼠标点击、导致工具图标看得见却点不了的问题。
- 修复仅在按钮外层扩大布局、实际可点击区域仍停留在 30 × 30 pt 的问题。

### Verification
- 工具栏命中区域与侧栏重建回归测试 2/2 通过；Computer Use 在最终 Debug 版中完成“组件库 → 工具 → 坐标点击画笔与橡皮擦边缘”，工具状态均立即切换。Xcode UI Test Runner 在自动化连接建立前被系统终止，未执行到断言。
