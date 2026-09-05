# Architecture Design

- 单项 reset 的传播条件增加 `defaultProperty.type == "TEXT"`。
- resetAll 的传播条件增加默认类型检查和 value 差异检查。
- 属性赋值、default 字典、锁前置、Undo/History 与 status 路径保持不动。
- resetAll 继续依赖已排序 override keys 在单次 mutation 中消费匹配文本。
