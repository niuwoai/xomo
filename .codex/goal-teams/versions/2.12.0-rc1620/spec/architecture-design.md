# Architecture Design

1. Copy Overrides 保留纯文本 JSON，并在同一 `NSPasteboardItem` 写入版本化私有 sidecar。
2. Paste 先快照剪贴板，再 decode、validate、plan；私有类型存在时必须通过版本、key 集和 imported baseline 校验。
3. legacy 纯文本只接受与目标 default 同 type、同 preferredValues 的 schema-compatible value override。
4. 基于修改前属性构造完整 replacement 与 TEXT old-to-new 计划；冲突映射整单失败。
5. 有变化时一次 `pushUndo()`、一次 document mutation、一次 History；no-op 不写项目。
6. Automation 调用相同 ViewModel 入口，并把格式问题映射为 invalid argument、内容锁映射为 operation failed。
