# 2.12.0-rc1616 Goal Packet

目标：为导入 Figma 组件提供 Sketch 式“全部还原”属性覆盖能力，并保持编辑器、自动化与历史事务一致。

成功标准：仅恢复具备导入默认且完整对象不同的属性；Custom 保留；一次 Undo/Redo；锁定零副作用；UI、i18n 与 Automation `resetAll` 有动态证据。

禁止范围：组件 schema、网络导入、绑定模型重构、Release、安装覆盖及 rc1640 全量门禁。
