# 测试计划：rc1603

## 新增测试

- IMAGE Paint 的映射内非 NORMAL 模式均产生 unsupportedPaint/partial。
- 未知、PASS_THROUGH 模式产生诊断。
- opacity 小于 1、非有限或非法值产生诊断。
- blendMode nil/NORMAL、opacity nil/1 不误报。
- 正常 image asset/filter/transform/materializer 行为不回归。

## 邻接回归

- 新测试逐项。
- 相关 Figma Content API、Image Asset、Image Filter、Import Plan 与 Materializer 套件。
- `ruby scripts/test_release_contract.rb`。
- `ruby scripts/test_run_tests_isolated_contract.rb`。
- `swift test --package-path xomo-cli`。

rc1603 不做完整门禁；rc1640 执行全量、Release、签名、安装和真实冒烟。
