# rc1816 零压力涂抹端点

## 用户影响

当涂抹笔刷开启「压力控制大小」时，零压力被映射成 0 直径，但 `smudgeDiameter` 和后续笔触掩码又把它提升到至少 1px。像素中心对齐的笔迹因此仍能移动颜色；手指涂抹也可能在起笔位置留下颜色。现在零直径段会被跳过，零直径起笔不再种色；未启用压力控制大小时沿用原有最小 1px 逻辑。

## 验证

- 修复前，`zeroPressureSmudgeDoesNotMovePixelsOrSeedFingerPaint` 对齐到像素中心后失败：普通涂抹输出 PNG 与原图不同，证明旧 1px 下限产生可见像素变化。
- 修复后，同一项回归通过；补充验证笔压从 0 恢复时，普通涂抹与手指涂抹均恢复工作；`ImageEditorToneAirbrushTests` 10/10。
- 发布合同 10 runs / 30 assertions、CLI Release Build 合同 7 / 24、产品概览归档合同 3 / 30、隔离测试器合同均通过；`git diff --check` 通过。
- 完整构建、全量测试、桌面冒烟与安装不在本版执行；下一门槛仍为 rc1840。
