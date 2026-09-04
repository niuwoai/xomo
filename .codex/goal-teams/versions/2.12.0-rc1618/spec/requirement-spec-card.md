# Requirement Specification Card

- Automation 客户端必须能解释 metadata-only override 的具体差异和 Reset 目标。
- 每项同时返回 current type/value/preferredValues、完整 importedDefault、兼容 defaultValue 与 overridden。
- 无默认 Custom 的 importedDefault/defaultValue 都是 null，overridden=false。
- 根级 propertyCount/overrideCount 对应当前 mutation 后快照。
- list/set/reset/resetAll 返回结构一致。
