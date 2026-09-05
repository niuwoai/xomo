# Architecture Design

- 在 `updateSelectedFigmaComponentProperty` 的唯一归一化入口按 property type 分流。
- TEXT 直接使用调用方 value；非 TEXT 沿用 `trimmingCharacters(in: .whitespacesAndNewlines)`。
- 既有 guard、default snapshot、精确后代匹配、文本层重建、锁、Undo/History 与 status 路径保持不动。
- UI TextField 和 Automation `set` 均继续调用同一 ViewModel 方法，不引入平行实现。
