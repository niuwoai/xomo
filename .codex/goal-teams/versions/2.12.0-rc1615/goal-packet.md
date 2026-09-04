# 2.12.0-rc1615 Goal Packet

目标：让 Fireworks 风格 Slice 在五种画布 Rotate/Flip 中保持几何、交付 preset、scope 与历史事务一致。

成功标准：五种变换精确；非法输入在 Undo 前原子失败；metadata 与 Optional 形态保真；Direct/Automation/Undo/Redo 有独立动态证据；版本、Git 与 main 闭环。

禁止范围：新 UI、schema/wire 变更、Release、安装覆盖、响应式约束与大模型重构。
