# Acceptance

状态：PASS。

- 初审 P1：移除会截断悬停 `.help` 的 `.allowsHitTesting(false)`；纯 `Text`/`Capsule` 保持无点击、无焦点、无写入。
- 初审 P2：在唯一新增测试中读取三份 strings，精确锁定 6×3 个冻结键值。
- 复审确认：四种精确映射、未知 raw、空白兜底/raw 保真、搜索隔离、Codable/诊断/历史边界均无剩余 P0/P1/P2。
- 动态证据：Figma provenance 32/32、Automation 323/323、Localization 46/46、cursor 128/128、CLI/MCP 2/2 全部通过。
- 静态证据：发布契约 9/9（27 assertions）、隔离运行器合同、release verifier、三语 plutil 与 `git diff --check` 全部通过。
