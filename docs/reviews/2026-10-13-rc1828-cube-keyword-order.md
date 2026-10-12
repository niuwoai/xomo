# rc1828：拒绝重复或迟到的 Cube 关键字

## 用户影响

Cube 解析器此前允许重复的 `TITLE`/`DOMAIN_*` 关键字，并在读取 LUT 样本行后继续处理元数据。重复的 `DOMAIN_MIN` 会以后值覆盖先值，进而改变同一组 LUT 样本的输入映射；表后的声明也会被静默采纳。Adobe 规范要求所有关键字位于表数据之前，且每个关键字最多出现一次（第 5.5 节）。

现在为关键字维护去重集合及表数据阶段状态：重复的标题、尺寸、域声明和未知 `LUT_`/`DOMAIN_` 扩展声明会被拒绝；任何已开始表数据后的关键字或非表数据文本也会拒绝导入。现有样本数检查继续负责拒绝欠采样/多采样文件。

规范依据：[Cube LUT Specification 1.0，第 5.5 节](https://kono.phpage.fr/images/a/a1/Adobe-cube-lut-specification-1.0.pdf)。

## 验证

- `ruby scripts/run_tests_isolated.rb --group-by-suite --filter Cube --out /private/tmp/xomo-rc1828-cube-keywords`：Cube LUT 专项 7/7，新增重复域声明和表后域声明拒绝回归；既有 1D/3D/HDR、65³、轴序、四面体插值和项目往返回归均通过。
- `ruby scripts/test_release_contract.rb`：10 runs / 30 assertions 通过。
- `ruby scripts/test_xomo_cli_release_build.rb`：7 runs / 24 assertions 通过。
- `ruby scripts/test_run_tests_isolated_contract.rb`：PASS。
- `git diff --check`：通过。

未运行全量 Release、完整 XCTest、桌面冒烟或 `/Applications` 安装。rc1840 仍是下一完整构建、冒烟与本机安装门槛。
