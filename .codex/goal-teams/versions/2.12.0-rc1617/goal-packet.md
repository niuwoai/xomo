# 2.12.0-rc1617 Goal Packet

目标：让 Figma 组件属性的单项 Reset 精确恢复完整 imported property object，消除 ghost override。

成功标准：metadata-only 与 value+metadata 覆盖均彻底清除；目标外属性不变；一次 Undo/Redo；TEXT、锁定、no-op 和 Automation 语义保持。

禁止范围：新 UI/i18n、Automation schema 扩张、Figma 网络写回、主组件身份、结构同步、swap/detach 与项目迁移。
