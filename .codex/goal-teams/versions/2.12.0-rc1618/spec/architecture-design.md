# Architecture Design

在 `figmaComponentPropertiesAction` 的 result 闭包内用局部 helper 将属性统一编码为 type/value/preferredValues。当前属性对象在兼容字段基础上追加 importedDefault、defaultValue 与 overridden；根对象追加 propertyCount/overrideCount。默认对象不存在时写 `.null`。

list/set/reset/resetAll 已共用 result 闭包，天然返回动作后的同一契约；无需输入 schema 或项目迁移。
