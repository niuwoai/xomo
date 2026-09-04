# 2.12.0-rc1618 Decisions

- `importedDefault` 为完整 `{type,value,preferredValues}` 或显式 null；不复用 current metadata。
- `defaultValue` 保持 string/null 作为兼容别名。
- preferredValues 保持导入数组顺序；JSON object 键顺序不构成契约。
- propertyCount 包含 Custom；overrideCount 只计具备默认且完整对象不同的属性。
- Registry action result 是输出协议权威证据；tools/list 仅证明输入注册，不冒充端到端结果验证。
