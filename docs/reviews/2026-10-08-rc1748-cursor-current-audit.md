# rc1748 当前画布光标策略审查

## 范围

针对经典 Photoshop 目标中“工具光标按交互语义设计、组件库使用系统箭头”的明确要求，在当前 `main`（rc1748）复跑完整 `ImageEditorCanvasCursorTests`，并抽查生产光标解析优先级。

## 结果

- 命令：`ruby scripts/run_tests_isolated.rb --group-by-suite --filter ImageEditorCanvasCursorTests --out /tmp/veilpic-rc1748-cursor-current`，外层持有仓库 `/private/tmp/veilpic-build.lock`。
- 实际执行：130 项，1 个测试套件，1/1 组通过，0 失败、0 基础设施重试。
- 生产代码按侧栏模式解析组件库交互；普通悬停和选中状态返回系统箭头，明确的画布平移及真实变换手柄仍可显示对应手势光标。
- 工具光标测试覆盖工具家族语义、选择修饰键、笔刷轮廓、取样/修复状态、路径状态、阻止操作提示和刷新接线。

## 结论与缺口

当前实现与自动化测试对系统箭头/工具语义要求一致，本轮没有发现需要修改的光标策略缺陷，因此不为递增 rc 号增加冗余版本。此结果只证明解析器和接线测试通过，不证明实际桌面上 AppKit cursor-rect、窗口切换、鼠标进出与组件拖放后的可见指针表现。真实 GUI 光标冒烟、全项目完整构建/回归及可恢复安装仍须在下一门槛 rc1760 实测；当前安装版仍记录为 rc1729。
