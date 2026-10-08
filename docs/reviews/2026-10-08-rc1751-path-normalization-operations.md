# rc1751 路径归一化与布尔运算对齐

## 问题与影响范围

`ImageEditorShapeContent.normalized(size:)` 会剔除锚点少于两个的 `pathSubpaths`，但原实现保留完整 `pathComponentOperations`。已保存的旧项目或外部 JSON 若在有效子路径前含有退化轮廓，归一化后后续形状可能继承被剔除轮廓的运算；例如本应 `intersect` 的有效轮廓会被错配为 `subtract`。

PSD vector mask parser 已拒绝少于三个锚点的轮廓，因此主要覆盖面是项目文档/外部模型归一化，而非声称当前 PSD parser 会产生此状态。

## 修复

- 归一化时枚举原始子路径；只有保留的轮廓才追加其原始索引对应的运算。
- 如果运算数组原本为空，仍保持为空，不改变 legacy 普通路径的隐式填充行为。
- 若显式运算数组比有效几何短，缺省项继续按既有 resolved 语义补为 `.exclude`。

## 验证

- 新增 `normalizedPathSubpathsKeepMatchingComponentOperations`：在两个有效三角路径之间放入单锚点退化子路径，验证几何归一化结果保留三条有效路径，运算严格为 `[combine, intersect, continuePrevious]`。
- `ImageEditorVectorLayerTests`：109/109 实际通过。
- `scripts/test_release_contract.rb`：10 runs / 30 assertions 通过。
- `scripts/test_xomo_cli_release_build.rb`：7 runs / 24 assertions 通过。
- `scripts/verify_release_contract.rb`：通过，App/CLI/Xcode 版本 `2.12.0-rc1751`，build 号 `1751`。
- `scripts/test_product_overview_archive.rb`：3 runs / 26 assertions 通过。
- `git diff --check`：通过。

Xcode 测试由仓库级构建锁串行执行。未运行完整项目门槛、真实 GUI 冒烟或覆盖 `/Applications`；下一完整门槛仍为 rc1760。
