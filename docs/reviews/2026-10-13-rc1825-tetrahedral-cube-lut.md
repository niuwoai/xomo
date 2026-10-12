# rc1825：3D Cube LUT 四面体插值

## 用户影响

rc1824 修正样本轴序后，3D `.cube` 仍按三线性算法计算 RGB 之间的值。Adobe Cube 规范要求 LUT 样本针对四面体插值生成正确结果，并建议读入器使用四面体插值（规范第 7.1 与 8 节）。对非线性调色表，三线性和四面体插值可能产生明显不同的颜色，尤其是不同 RGB 分量在单元格内同时变化时。

现根据 `rt`、`gt`、`bt` 的六种大小排列选择对应四面体，以四个顶点的重心权重计算结果；1D LUT、域归一化和 Cube 文件红轴最快的存储顺序保持不变。验证数据令输出通道分别为输入 `r*g`、`g*b`、`r*b`：三线性中心结果为 0.25，而四面体中心预期为 0.5，因此能直接区分算法。像素回归进一步覆盖 RGB 六种严格次序组合。

格式依据：[Cube LUT Specification 1.0，第 7.1、7.2 和 8 节](https://kono.phpage.fr/images/a/a1/Adobe-cube-lut-specification-1.0.pdf)。

## 验证

- `ruby scripts/run_tests_isolated.rb --group-by-suite --filter Cube --out /private/tmp/xomo-rc1825-tetrahedral`：Cube LUT 专项 5/5；覆盖四面体中心与六种 RGB 排序、标准轴序交换、声明域恒等映射、1D LUT 及旧项目迁移。
- `ruby scripts/test_release_contract.rb`：10 runs / 30 assertions 通过。
- `ruby scripts/test_xomo_cli_release_build.rb`：7 runs / 24 assertions 通过。
- `ruby scripts/test_run_tests_isolated_contract.rb`：PASS。
- `git diff --check`：通过。

未运行全量 Release、完整 XCTest、桌面冒烟或 `/Applications` 安装。rc1840 仍是下一完整构建、冒烟与本机安装门槛。
