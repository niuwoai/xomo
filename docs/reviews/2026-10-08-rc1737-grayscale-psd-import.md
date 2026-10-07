# rc1737：8 位灰度 PSD 导入

## 范围与基线

- 基于本地 `main`：`f9932fc6`（rc1736 集成文档）；当时远端跟踪基线为 `a88f0535`（rc1731）。
- 本版新增标准 Photoshop 8 位灰度模式（color mode 1）导入，将灰度像素映射到 Xomo RGB 画布；不改变 PSD 导出格式，不扩张 Figma 能力。
- 此版本不是四十版本完整门槛：不运行全量 Release 构建、界面冒烟或 `/Applications` 覆盖安装；下一门槛仍是 rc1760，安装版本记录为 rc1729。

## 实现与用户路径

- 兼容性扫描接受灰度 PSD 的 1–56 个通道；正式解码依据 color mode 使用至少 1 个颜色 plane，而 RGB 仍要求至少 3 个。
- 分层灰度 PSD 的图层 channel 0 复制到 RGB 三个分量，channel -1 透明度保持原值；复合灰度按 1 个颜色 plane、随后透明度、再随后附加 alpha/spot plane 解析。
- 无图层 PSD 仍通过既有扁平背景层导入路径生成可编辑背景像素。
- 增加独立生成的 `grayscale-layer.psd` 和 `grayscale-composite.psd` 外部规格夹具；前者覆盖 ZIP Prediction，二者覆盖透明度与兼容性报告。

## 验证证据

- `xcodebuild ... -only-testing:veilpicTests/ImageEditorPSDTests build-for-testing`：成功。
- `scripts/run_tests_isolated.rb --group-by-suite --filter ImageEditorPSDTests --skip-build`：61/61 实际测试通过，失败/跳过 0；包含两项新增灰度导入测试。
- 初始像素断言曾失败，因为 AppKit 灰度转 RGB 的量化值会有 1 级差异；将灰度读回容差定为 1，同时要求 RGB 三分量一致且 alpha 精确一致。一次测试提取错误使用 document composite 检查扁平导入，已改为断言实际背景层像素。
- 两项版本/CLI 发布合同仍待本记录写入后的验证。

## 未覆盖与集成状态

- 不支持 16/32 位深、索引色、CMYK、Lab 或双色调；兼容性扫描继续明确标记这些模式。
- 尚未实测无 alpha 的单通道灰度 PSD 和灰度 PSD 的多个附加 alpha/spot channel；复合 plane 起始偏移在实现中按标准布局处理，建议后续加入 fixture 覆盖。
- 尚未做真实 UI 打开文件冒烟或全量 Release 回归；不安装、不推送、不打标签。
