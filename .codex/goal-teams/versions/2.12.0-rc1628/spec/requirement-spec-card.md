# Requirement Specification Card

- 用户价值：无需记忆 Figma 机器常量即可识别组件属性类型，同时仍能排查原始协议值。
- 显示：紧凑 Capsule，只读，无点击和焦点。
- 三语：Text/文本/テキスト，Toggle/开关/切り替え，Variant/变体/バリアント，Instance swap/实例交换/インスタンス入れ替え。
- 异常：未知非空逐字显示；空白显示 Unknown type/未知类型/不明な型。
- 可观测性：辅助说明 `Figma raw type: %@` 及中日对应文案，参数是完整 raw。
- 稳定标识：`image-editor-figma-property-type-\(key)`。
- 回归：搜索、数据、写入、诊断、历史、Automation 与 cursor 全部不变。
