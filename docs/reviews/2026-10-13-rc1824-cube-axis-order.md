# rc1824：修复 3D Cube LUT 样本轴序

## 用户影响

Adobe Cube 3D 表格按红色输入索引最快变化、绿色其次、蓝色最慢变化排列，等价于 `r + N*g + N*N*b`。当前实现把红色当作最慢轴，因而真实导入的 `.cube` 会按错误通道取样，导致调色结果偏离 LUT 作者定义。Adobe 的格式说明明确记录了该顺序：[Cube LUT Specification 1.0，第 7.2 节](https://kono.phpage.fr/images/a/a1/Adobe-cube-lut-specification-1.0.pdf)。

旧的 “Swap RB” 测试数据实际上按规范顺序表示恒等映射；错误索引反而把它解释成通道交换，使测试通过并掩盖了回归。现将索引改为 `b*N*N + g*N + r`，并修正夹具：导入流程使用真实红蓝交换表，自定义输入域测试使用规范顺序的恒等表。两个回归都检查渲染后的像素，而不只检查解析或模型状态。

## 验证

- `ruby scripts/run_tests_isolated.rb --group-by-suite --filter Cube --out /private/tmp/xomo-rc1824-cube-axis`：Cube LUT 专项 4/4，包含 3D 导入及调整层像素路径、声明域恒等映射、无效域与旧项目迁移、1D LUT 回归。
- `ruby scripts/test_release_contract.rb`：10 runs / 30 assertions 通过。
- `ruby scripts/test_xomo_cli_release_build.rb`：7 runs / 24 assertions 通过。
- `ruby scripts/test_run_tests_isolated_contract.rb`：PASS。
- `git diff --check`：通过。

未运行全量 Release、完整 XCTest、桌面冒烟或 `/Applications` 安装。rc1840 仍是下一完整构建、冒烟与本机安装门槛。
