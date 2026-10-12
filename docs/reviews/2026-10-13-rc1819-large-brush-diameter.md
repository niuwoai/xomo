# rc1819 大画笔尺寸范围验证

- 时间：2026-10-13（本地工作区日期）
- 分支：`codex/brush-size-range-rc1819`
- 起始基线：`d6e52a41`
- 目标：将经典画笔直径上限由 96 px 扩展到 512 px，并确认 UI、自动化、保存设置、光标与实际像素笔触保持一致。

## 实现与用户路径

- `ImageEditorBrushSizeLimits` 提供统一的 1–512 px 有限值归一化；画笔动态偏好和自定义预设都经此处理，避免重开项目或切换预设时悄悄回落到旧上限。
- 选项栏尺寸滑块、快捷键和选项预设使用同一上限；`@Published brushSize` 也会规整自动化等直接赋值，并持久化结果。
- 画布笔尖光标上限同步至 512 px，避免显示的小圆环比真实笔刷小一截。
- 核心像素集成回归在 600×600 透明画布上以 512 px 画笔落笔：距中心 200 px 的像素应覆盖、距中心 260 px 的像素应透明；并验证尺寸偏好保存、一次笔刷历史、Undo 恢复原图和 Redo 恢复落笔结果。
- 路径和形状描边仍采用它们既有的 96 px 限制；本次只扩展像素画笔笔尖，不改变矢量对象描边语义。

## 验证

测试前确认无其他 `xcodebuild`/XCTest 进程，并在 `/private/tmp/veilpic-build.lock` 下完成一次测试构建；随后复用同一测试产物顺序运行：

- `ImageEditorBrushStrokeTests`：63/63
- `ImageEditorBrushDynamicsPreferencesTests`：37/37
- `ImageEditorCanvasCursorTests`：130/130
- `ImageEditorScopeTests`：198/198
- 发布合同：10 次 / 30 项断言
- CLI Release Build 合同：7 次 / 24 项断言
- 产品概览归档合同：3 次 / 30 项断言

全部上述检查通过。未运行全量 Release 测试、桌面交互冒烟或覆盖 `/Applications`；不能据此宣称完整门槛或本机安装验收完成。下一完整构建、全量测试、桌面冒烟与本机安装门槛为 rc1840。
