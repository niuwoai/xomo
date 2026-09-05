# Test Plan

- Figma provenance 新增恰好 1 个表驱动测试：四个已知值、大小写/空白近似值、未来值、空串和纯空白。
- 断言 presentation、rawType、原属性 type、诊断/可写状态、JSON 往返和项目/历史零副作用。
- 对 raw type、三语标签、unknown key/诊断词执行搜索，必须无命中；key/value 搜索旧合同保留。
- 扩写既有 Inspector 静态合同：共享 presentation、accessibility id、raw help、只读 badge、六个三语 key，且 filter 不读取 type/presentation/localization/diagnosis。
- 目标：Figma 32/32、Automation 323/323、Localization 46/46、Cursor 128/128、CLI/MCP 2/2、Release contract 9/9。
- 全部构建与测试严格复用唯一 DerivedData 并串行执行。
