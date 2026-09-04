# 2.12.0-rc1603 Goal Packet

- 目标：Figma IMAGE Paint blendMode/opacity 诊断不再静默丢失。
- 允许：`XomoFigmaNodeContentAPI.swift`、新增直接测试、版本/发布文档。
- 禁止：Paint→layer 模式提升、持久化 schema、Group/Frame 背景语义、多 Fill 折叠、Release/安装覆盖。
- 测试：IMAGE 非 NORMAL/未知模式、非 1/非法 opacity、默认值不误报、现有 image asset/filter/materializer 邻接套件、CLI/发布契约。
- 下一完整门禁：2.12.0-rc1640。
