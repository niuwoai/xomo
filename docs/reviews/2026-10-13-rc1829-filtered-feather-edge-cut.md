# rc1829：带智能滤镜的羽化剪切四边缘回归

## 用户工作流与范围

rc1818 已验证普通栅格层在左、右、上、下画布边缘执行羽化选区剪切；带智能滤镜的图层走不同的 `postFilterCutoutMask` 路径，既有滤镜羽化剪切回归只覆盖画布内部的多边形选区。本版在四边缘逐项覆盖这一分支，防止用户剪切边缘内容时，滤镜输出与剪贴内容之间出现 alpha 缺口或双重覆盖。

回归以全画布不透明图层和高斯模糊为源，在每个画布边缘创建单像素选择并羽化。逐像素验证：剪贴图 alpha 与滤镜后源图 alpha 之和在 1 个 8-bit 量化单位内等于剪切前合成 alpha；剪贴图 frame 被画布边界裁切；智能滤镜与 post-filter cutout 保留；剪切只有一个撤销步骤；Undo/Redo 和项目保存重开保持同一合成结果。

检查表明当前生产实现通过这些场景，无需算法修复；rc1829 只增加真实用户路径的回归覆盖。

## 验证

- `ruby scripts/run_tests_isolated.rb --group-by-suite --filter featheredFilteredCutConservesCoverageAtEveryCanvasEdge --out /private/tmp/xomo-rc1829-filtered-cut`：1/1 通过。
- `ruby scripts/run_tests_isolated.rb --group-by-suite --filter ImageEditorSelectionCutSamplingTests --out /private/tmp/xomo-rc1829-cut-suite`：21/21 通过；rc1829 版本号同步后重跑同一套件 21/21 通过。
- `ruby scripts/test_release_contract.rb`：10 runs / 30 assertions 通过。
- `ruby scripts/test_xomo_cli_release_build.rb`：7 runs / 24 assertions 通过。
- `ruby scripts/test_run_tests_isolated_contract.rb`：PASS。
- `git diff --check`：通过。

未运行完整 Release、全量测试、桌面冒烟或 `/Applications` 安装；rc1840 仍是下一完整门槛。
