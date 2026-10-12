# rc1833：统一逐像素调整的直通 RGB 契约

- 基线：`main` / `61a7224cc3ea52a49af1119f01a1312f38cf6be4`（rc1832）
- 版本：`2.12.0-rc1833`，build `1833`
- 范围：修复共享像素映射器的 premultiplied-alpha 读写契约；不改变调整层事务、文档格式或界面。

## 问题与场景

`pixelMappedByCoordinate` 使用 premultiplied RGBA CGContext 缓冲区，但此前将缓冲区 RGB 直接传给颜色变换并将变换结果直接写回。多数变换的计算语义是直通 RGB，因此半透明图层的颜色会错误地依赖 alpha；Levels、Curves、Color Lookup 又在各自实现里补偿 alpha，形成不一致的隐式约定。

现改为共享入口在变换前将非零 alpha 的预乘通道还原为直通 RGB，透明像素使用黑色；写回时由公共路径将变换 RGB 按输出 alpha 预乘。Levels、Curves 与 Color Lookup 移除局部预乘/反预乘逻辑。回归以相同直通色的全不透明与 50% 半透明像素对照多类调整，并确认输出 alpha 保持。

## 验证

- 修复前新增回归实际失败，首先报告半透明结果红通道与不透明参考不一致；修复后 `ImageEditorAdjustmentTests` 51/51 通过，覆盖反相、阈值、Levels、Curves、亮度对比度、曝光、色相饱和度、阴影高光、通道混合、Color Lookup 与渐变映射。
- `ruby scripts/test_release_contract.rb`：10 runs / 30 assertions；`ruby scripts/test_xomo_cli_release_build.rb`：7 runs / 24 assertions；`ruby scripts/test_product_overview_archive.rb`：3 runs / 30 assertions；`ruby scripts/test_run_tests_isolated_contract.rb`：PASS；`git diff --check`：PASS。
- 未运行完整 Release、GUI 冒烟或本机安装；完整门槛仍为 rc1840。
