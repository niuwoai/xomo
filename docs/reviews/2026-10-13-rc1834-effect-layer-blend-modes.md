# rc1834：调整层与滤镜层混合模式

- 基线：`main` / `222ef0bf62a6b831390c597346ad5979ab3a5fee`（rc1833）
- 版本：`2.12.0-rc1834`，build `1834`
- 范围：修复特殊效果层 blend mode 属性与画布/合并输出脱节；不改变滤镜或调整算法。

## 问题与场景

图层面板为所有非组图层提供混合模式选择，但 `canSetLayerBlendMode` 明确排除调整层和滤镜层；这两种层的 `compositeLayer` 调用也没有把 `layer.blendMode` 传给已有支持混合模式的 `applyingAdjustment` / `applyingFilter`。因此用户选择“正片叠底”或“滤色”时设置保持 `.normal`，画布和“合并到下方”结果都不反映所选模式。

修复后，效果层可写入常规图层混合模式，画布合成及合并层使用同一混合语义，历史事务可撤销/重做。回归分别验证反相调整层的正片叠底和高斯滤镜层的滤色结果，并比较画布与合并输出。

## 验证

- 新增调整层和滤镜层端到端用例各 1 项均通过；`ImageEditorAdjustmentTests` 52/52、`ImageEditorFilterTests` 85/85。覆盖画布输出、合并到下方、Undo/Redo 及项目保存重开后的混合模式和像素结果。
- 发布合同：10 runs / 30 assertions；CLI 发布构建合同：7 runs / 24 assertions；产品概览归档合同：3 runs / 30 assertions；隔离测试器合同 PASS；`git diff --check` PASS。测试目标 `build-for-testing` 成功。
- 未运行完整 Release、GUI 冒烟或本机安装；完整门槛仍为 rc1840。
