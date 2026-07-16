# 象墨 PSD 支持说明

> 最后更新：2026-07-17 ｜ 对应版本：v2.12.0-rc180

## 1. 结论

象墨当前已经可以可靠处理以像素图层为主的常见 PSD，并保留基础图层结构、嵌套组、栅格蒙版、混合模式、Fill 不透明度和锁定状态。Raw、RLE、ZIP、ZIP Prediction 四种 8-bit 通道压缩均可读取。对能解析 TySh/EngineData 的基础文字层，还会生成 Xomo 原生可编辑文字层，读取一组基础字符与段落样式，并保留段落文本框边界；简单 vmsk/vsms 闭合路径、Image Resources 中的 Path Resource、额外 Alpha/Spot 通道以及结构完整的原生矢量蒙版也支持在导入时进入可编辑模型。

rc174 补齐连续剪贴蒙版链的 PSD 导出、重新导入与项目保存重开回归，基底关系、透明度和选择状态都有测试证据。rc169 修复了 `vmsk`/`vsms` 子路径长度记录的保留字节偏移，矢量蒙版和路径资源的单/多子路径导入、导出与项目往返测试通过。rc170 修复 EngineData UTF-16 字体名终止符解析，基础文字层字体名可稳定往返；rc171 修复 ZIP 通道 zlib 头处理，外部 ZIP 合成与 ZIP 组蒙版进入可读模型；rc172 改用 Core Graphics 无插值逐像素读取栅格蒙版 alpha，复杂蒙版 alpha 精确往返。

这还不是“完整 Photoshop 语义兼容”。复杂文字变换、逐字符样式、矢量形状、智能对象、调整层、图层效果和填充层等 Photoshop 专有对象，仍不能完整保留为同类可编辑对象。打开 PSD 后，象墨会生成兼容性报告，明确列出文件中被栅格化、忽略或降级的内容。

建议把象墨原生项目格式作为持续编辑的主文件，把 PSD 作为与 Photoshop 或其他设计软件交换的格式。

## 2. 导入支持矩阵

| 能力 | 当前状态 | 说明 |
|---|---|---|
| PSD 文件版本 | 支持 | 支持 PSD v1；不支持 PSB v2。 |
| 位深 | 支持 8-bit | 16-bit、32-bit 会在兼容性报告中标记为不支持，并拒绝原生分层解析。 |
| 颜色模式 | 支持 RGB | Bitmap、灰度、索引色、CMYK、Multichannel、Duotone、Lab 暂不支持。 |
| 文档通道 | RGB / RGBA + 额外 Alpha / Spot | 文件头允许 3–56 个通道；RGB 和第一个透明通道用于成像，其余通道读取为带名称的 Xomo Alpha 或 Spot 通道。 |
| 通道压缩 | 支持 | Raw、RLE、ZIP、8-bit ZIP Prediction。 |
| 像素图层 | 支持 | 保留名称、顺序、位置、可见性、图层不透明度和透明像素。 |
| 剪贴蒙版标记 | 支持 | 导入图层的 clipping 标记。复杂 Photoshop 剪贴链的最终视觉仍建议人工核对。 |
| 嵌套图层组 | 支持 | 保留父子层级、展开/折叠状态和组的 Pass Through。 |
| 栅格图层蒙版 | 支持 | 保留蒙版像素、启用/停用和链接状态；蒙版密度、羽化等参数不会作为 Photoshop 参数继续编辑。 |
| 组蒙版 | 支持 | 作为组的栅格蒙版导入。 |
| Fill 不透明度 | 支持 | 读取 `iOpa` 并映射到象墨 Fill 不透明度。 |
| 锁定状态 | 支持 | 透明像素、像素、位置和全部锁定。 |
| 混合模式 | 支持 | 支持象墨全部 27 种像素混合模式，以及图层组 Pass Through；未知模式会报告并按 Normal 降级。 |
| 只有合成图的 PSD | 降级支持 | 没有可用图层记录时，读取合成图并建立单个像素图层。 |
| Path Resource | 支持 | Image Resources 中的命名路径导入为 Xomo 路径面板项目，支持闭合路径、开放路径、多子路径和 Bézier 控制柄。 |
| Finder 打开 | 支持 | 可双击 PSD、通过“打开方式”或象墨的打开面板载入。大文件会显示启动主视觉和加载动画。 |

当前支持的像素混合模式为：Normal、Dissolve、Multiply、Screen、Overlay、Darken、Lighten、Darker Color、Lighter Color、Color Dodge、Color Burn、Linear Dodge、Linear Burn、Subtract、Divide、Soft Light、Hard Light、Vivid Light、Linear Light、Pin Light、Hard Mix、Difference、Exclusion、Hue、Saturation、Color、Luminosity。

## 3. 语义降级情况

| Photoshop 内容 | 导入结果 | 主要影响 |
|---|---|---|
| 基础文字层 | 映射为 Xomo 原生文字层 | 读取纯文本、字体、字号、颜色、基础段落对齐、粗斜体、下划线、删除线、字距、行距和缩进；复杂逐字符混排、变换和部分 EngineData 仍降级。无法解析的 TySh 继续使用 PSD 像素内容并报告。 |
| 矢量形状 | 使用像素内容 | 路径、描边、填充和布尔运算语义不保留。 |
| 简单矢量蒙版 | 映射为 Xomo 原生路径蒙版 | 支持多个闭合子路径、Bézier 控制柄和偶数奇数填充（包括带孔洞形状）；开放路径、反相/断链等复杂记录继续栅格化并报告。 |
| 路径资源 | 映射为 Xomo 原生命名路径 | 支持同一资源内的多个同闭合状态子路径；闭合状态混合、损坏记录和未识别路径资源会跳过，不影响像素图层导入。 |
| 智能对象 | 使用像素内容 | 嵌入源、链接源和可替换内容不保留。 |
| 调整层 | 参数不保留 | 没有独立像素回退的调整层可能不会成为可编辑图层，视觉结果必须核对。 |
| 图层效果 | 使用图层已有像素表现 | 阴影、描边、发光等 Photoshop 参数不保留。 |
| 纯色/渐变/图案填充层 | 使用像素内容 | 填充参数和图案引用不保留。 |
| ICC 配置文件 | 忽略并提示 | 当前按设备 RGB 处理，可能出现颜色差异。 |
| 额外 Alpha 通道 | 映射为原生 Alpha 通道 | 读取 Image Resources 中的名称和复合图像中的 8-bit 掩码，可在通道面板与项目格式中继续使用。 |
| Spot 通道 | 映射为原生 Spot 通道 | 读取 DisplayInfo（1077）的 Spot 模式、色彩空间、四个 16-bit 分量和不透明度；像素平面继续作为灰度覆盖率预览，并可随项目和 PSD 往返。 |
| 未识别图层数据 | 忽略并提示 | 对应 Photoshop 私有元数据或第三方插件数据不会保留。 |

兼容性报告会统计画布尺寸、位深、颜色模式、图层数、组数、蒙版数和实际出现的压缩方式，并列出上述风险。存在问题时会在 PSD 打开后自动显示，也可以从“文件”菜单再次查看。

## 4. PSD 导出支持矩阵

| 能力 | 当前状态 | 说明 |
|---|---|---|
| 输出格式 | PSD v1、8-bit RGB/RGBA + Alpha / Spot | 同时写入图层记录、文档合成图和额外 Alpha/Spot 通道；Spot 的 DisplayInfo 元数据同步写出。 |
| 通道压缩 | Raw | 当前导出器优先保证结构简单可靠，尚未输出 RLE/ZIP。 |
| 像素图层 | 支持 | 保留名称、位置、可见性、不透明度、Fill、剪贴标记、混合模式和锁定状态。 |
| 嵌套组 | 支持 | 写入组开始/结束记录、展开状态、组混合模式和组蒙版。 |
| 栅格蒙版 | 支持 | 写入蒙版像素、启用/停用和链接状态。象墨中的密度、羽化会烘焙进有效蒙版像素，不会保存为独立 Photoshop 参数。 |
| 基础文字层 | 部分支持 | 写入 TySh/EngineData，保留文本、字体、字号、颜色、段落框、对齐、缩进和基础字符样式；复杂逐字符混排与变换仍依赖像素回退。 |
| 形状、智能对象 | 栅格化导出 | 视觉内容进入普通像素层，不保留原对象语义。 |
| 命名路径 | 支持 | 写入 Image Resources 的 Path Resource，保留名称、闭合/开放状态、多子路径和 Bézier 控制柄。 |
| 额外 Alpha / Spot 通道 | 支持 | 导入与导出均保留名称和 8-bit 掩码；Spot 还保留 DisplayInfo 色彩元数据。Xomo 目前不把专色参与 RGB 屏幕合成。 |
| 矢量蒙版 | 部分支持 | 结构完整的闭合路径写入图层 `vmsk`，保留子路径、控制柄和启用状态；开放路径、反相/断链及复杂记录栅格化导出。 |
| 图层效果 | 烘焙到像素 | 效果参数不写入 Photoshop 图层效果块。 |
| 调整层、滤镜层 | 不作为独立图层写出 | 最终合成图包含当前文档视觉结果，但可编辑的调整/滤镜层记录会省略。 |
| ICC、路径、参考线、切片等元数据 | 暂不写出 | 导出的 PSD 以画布、像素和图层结构为主。 |

## 5. 大文件加载与性能边界

- 从 Finder 或“打开方式”载入 PSD 时，文件达到 12 MB，或实际加载超过 180 ms，才显示“一墨生万象”启动图和原生转圈动画；普通启动直接进入主窗口。
- PSD 文件读取、结构解析以及 Raw/RLE/ZIP 解压在后台执行；创建可编辑图层时会分批让出主线程，降低界面假死概率。
- 当前仍是整文件、整通道和整图层的内存模型，没有分块解码、磁盘缓存或 Photoshop Large Document（PSB）支持。超大画布、数百图层或高压缩比文件仍可能占用较多内存和时间。
- 兼容性扫描本身不会证明最终视觉完全一致。混合链、颜色配置、调整层和插件数据较复杂时，应对照 Photoshop 原图人工核验。

## 6. 测试证据

rc166 的专色通道定向回归通过；完整套件仍有既有文字、矢量路径与外部 fixture 回归，详见 [`test-reports/rc166-psd-spot/report.md`](../test-reports/rc166-psd-spot/report.md)。

rc167 的画布光标定向回归 10/10 通过，详见 [`test-reports/rc167-cursor/report.md`](../test-reports/rc167-cursor/report.md)。

rc168 修复 Path Resource 记录对齐；闭合/开放命名路径导出与外部导入往返通过，详见 [`test-reports/rc168-psd-path/report.md`](../test-reports/rc168-psd-path/report.md)。

本版本使用四份由独立 Ruby 生成器按 PSD 二进制结构构造的夹具，避免只用象墨自己的编码器做“自己写、自己读”的循环验证：

- `zip-group-mask.psd`：ZIP 图层、ZIP Prediction、嵌套组和栅格蒙版。
- `zip-composite.psd`：只有 ZIP 合成图的 PSD。
- `unsupported-features.psd`：文字、矢量、智能对象、调整层、效果、填充层、ICC、额外通道和未知数据的报告分类。
- `editable-text.psd`：独立生成的 TySh/EngineData 段落文字层，验证纯文本、Helvetica、24pt、颜色、居中对齐、基础字符/段落样式、文本框边界、溢出状态及项目格式保存重开。
- `vector-mask.psd`：独立生成的 vmsk 三点闭合路径，验证 Bézier 锚点、控制柄、矢量蒙版和项目格式保存重开。
- `vector-mask-multi.psd`：独立生成的 vmsk 双闭合子路径，验证 `pathSubpaths`、偶数奇数填充的孔洞和项目格式保存重开。
- `path-resources.psd`：独立生成的 Image Resources 路径资源，验证命名闭合路径、开放路径和项目格式保存重开。
- `extra-alpha.psd`：独立生成的五通道 PSD，验证额外 Alpha 名称、透明度掩码和项目格式保存重开。

相关文件：

- 夹具与说明：[`veilpicTests/Fixtures/PSD`](../veilpicTests/Fixtures/PSD)
- 夹具生成器：[`scripts/generate_psd_compatibility_fixtures.rb`](../scripts/generate_psd_compatibility_fixtures.rb)
- PSD 测试报告：[`test-reports/rc157-psd-suite/report.md`](../test-reports/rc157-psd-suite/report.md)
- 文字导出定向报告：[`test-reports/rc157-text-export/report.md`](../test-reports/rc157-text-export/report.md)
- 额外 Alpha 通道导出定向报告：[`test-reports/rc156-alpha-export/report.md`](../test-reports/rc156-alpha-export/report.md)
- PSD 原生矢量蒙版导出定向报告：[`test-reports/rc154-vector-mask-export/report.md`](../test-reports/rc154-vector-mask-export/report.md)
- 外部打开测试报告：[`test-reports/rc145-external-open/report.md`](../test-reports/rc145-external-open/report.md)
- 本地化测试报告：[`test-reports/rc145-localization/report.md`](../test-reports/rc145-localization/report.md)

rc157 的 PSD 定向验证结果为：PSD 专项 17/17、文字导出 1/1、Xomo CLI 2/2；开放/复杂路径安全回退由专项回归覆盖。

## 7. 使用建议

1. 日常持续编辑优先保存为象墨原生项目；需要交换时再另存 PSD。
2. 打开 PSD 后先查看兼容性报告。出现文字、矢量、智能对象、调整层、效果、ICC 或未知数据时，不要覆盖唯一原件。
3. 重要交付文件应重点核对文字排版、颜色、混合链、蒙版边缘、调整层效果和画布边界。
4. 如果只要求最终视觉而不要求图层语义，可以使用扁平化导入或常规图像格式，结果通常更可预测。

## 8. 后续建议

下一阶段不建议同时追求所有 Photoshop 私有结构。按用户价值和实现风险排序：

1. 可编辑文字层：继续扩展段落框溢出语义、逐字符混排和文字变换；当前基础 TySh/EngineData 已可交换，复杂文字仍使用像素回退。
2. 可编辑矢量形状与矢量蒙版：继续扩展复杂 vmsk、矢量形状和文字/路径交换；当前开放、反相/断链路径仍安全栅格化。
3. 智能对象的安全栅格回退与元数据保留：先允许重新定位原始内容，再考虑嵌套编辑。
4. 常用调整层：优先 Levels、Curves、Hue/Saturation，并为无法映射的参数继续保留明确报告。
5. 颜色管理、16-bit 和 PSB：这些会牵动渲染、内存与项目模型，应作为独立工程阶段处理。

格式实现依据：[Adobe Photoshop File Formats Specification](https://www.adobe.com/devnet-apps/photoshop/fileformatashtml/)。
