# rc1735 活动滤镜剪贴层剪切

## 工作流与验收

覆盖图层栈组合：对带 Gaussian Blur 的剪贴层执行“剪切到新图层”，新分层仍保持剪贴关系，源层继续持有滤镜与滤镜后裁切遮罩，合成像素不变。

- `ImageEditorSelectionCutSamplingTests`：`.xcresult` 实际执行 19 项，0 失败。
- 新增场景逐项检查源/新层的 `isClippingMask`、源滤镜和 cutout、完整合成 RGBA、单步 Undo/Redo 及项目保存重开。
- 本版本没有生产代码变化；合入的价值是约束此前未覆盖的“智能滤镜 × 剪贴层 × 选区分层”组合语义。
- 未运行全量构建/回归、真实 GUI 冒烟或 `/Applications` 安装；安装版仍为 rc1729，下一完整门槛 rc1760。

## 集成

- 基线为本地 `main` 的 rc1734；`origin/main` 仍为 rc1731。
- 功能分支：`codex/filtered-clipping-cut-rc1735`。待提交并合入本地 `main`；本轮不推送或创建 tag。
- 不涉及图层样式合成策略；部分选区剪切时样式如何分配仍待用户确认。
