# rc1830：滤镜羽化选区剪切到新图层的四边缘回归

## 用户工作流与范围

rc1829 覆盖了带智能滤镜的羽化剪切到剪贴板；本版补齐另一条不同的命令路径：用户把羽化选区剪切为新图层。测试对全画布高斯滤镜图层分别选择左、右、上、下边缘的单像素区域，并核验：切出图层 frame 被画布正确裁切，羽化半透明尾仍保留，源图层与切出像素的 alpha 覆盖分量逐像素守恒，源智能滤镜及 post-filter cutout 保留，操作只有一条 Undo 记录，Undo/Redo 和项目保存重开一致。

这里验证的是剪切后源与新图层各自携带的覆盖率，不把两个普通 alpha-over 图层的合成结果等同于剪切前画面；羽化边缘的常规 alpha 分配不是无损分层合成。本版未改变该既有编辑语义，也未修改生产算法。

## 验证

- `lockf -t 1 /private/tmp/veilpic-build.lock env XOMO_DERIVED_DATA_PATH=/private/tmp/xomo-rc1830-cut-layer-derived ruby scripts/run_tests_isolated.rb --group-by-suite --filter filteredFeatheredCutToLayerConservesCoverageAtEveryCanvasEdge --out /private/tmp/xomo-rc1830-cut-layer-semantic`：1/1 测试方法通过，覆盖四个边缘参数案例。
- `lockf -t 1 /private/tmp/veilpic-build.lock env XOMO_DERIVED_DATA_PATH=/private/tmp/xomo-rc1830-cut-layer-derived ruby scripts/run_tests_isolated.rb --group-by-suite --filter ImageEditorSelectionCutSamplingTests --out /private/tmp/xomo-rc1830-cut-layer-full`：22/22 测试通过。
- `ruby scripts/test_release_contract.rb`：10 runs / 30 assertions 通过。
- `ruby scripts/test_xomo_cli_release_build.rb`：7 runs / 24 assertions 通过。
- `ruby scripts/test_run_tests_isolated_contract.rb`：PASS。
- rc1830 版本同步后重跑剪切采样套件：22/22 通过。
- `git diff --check`：通过。

未运行完整 Release、全量测试、桌面冒烟或 `/Applications` 安装；rc1840 仍为下一完整门槛。
