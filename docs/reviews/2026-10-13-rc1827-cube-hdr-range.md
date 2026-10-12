# rc1827：保留 Cube LUT 的 HDR 输出范围

## 用户影响

Cube LUT 样本的输出不限制在 0–1。Adobe 的规范说明输入域与输出范围都不限于 0–1，且表样本值在格式范围内不受约束；附带的 ACES Proxy 示例也包含 1.165、1.84 等大于 1 的输出值。[Cube LUT Specification 1.0，第 5.7 节及附录 A.2](https://kono.phpage.fr/images/a/a1/Adobe-cube-lut-specification-1.0.pdf)

此前 Xomo 在 `.cube` 解析和 `normalized()` 时就将所有表值夹到 0–1，造成插值前数据损失。现保留有限且在规范 ±1e37 数值范围内的 1D/3D LUT 输出，拒绝越界数值而不是跳过坏行后错位读取；调整层编码往返继续保存原值。实际图像当前为 8-bit，最终像素写入仍由既有字节转换统一裁切。这样例如 1D 样本 `0 → 2` 在输入 `0.5` 时插值得到 `1`，而不是先夹点后错误得到 `0.5`。

## 验证

- `ruby scripts/run_tests_isolated.rb --group-by-suite --filter Cube --out /private/tmp/xomo-rc1827-hdr-cube`：Cube LUT 专项 7/7。新增 1D HDR 表的项目编码往返与实际像素断言，并验证 3D HDR 表真实像素输出、超出规范数值范围时拒绝导入；既有 65³ 导入、四面体插值、轴顺序、域映射、1D 和旧项目迁移回归仍通过。
- `ruby scripts/test_release_contract.rb`：10 runs / 30 assertions 通过。
- `ruby scripts/test_xomo_cli_release_build.rb`：7 runs / 24 assertions 通过。
- `ruby scripts/test_run_tests_isolated_contract.rb`：PASS。
- `git diff --check`：通过。

未运行全量 Release、完整 XCTest、桌面冒烟或 `/Applications` 安装。rc1840 仍是下一完整构建、冒烟与本机安装门槛。
