# 2.12.0-rc1606 Goal Teams 进展

| 成员 | 任务 | 状态 | 当前证据 | 下一步 |
| --- | --- | --- | --- | --- |
| 需求审计 | GT-1606-01 | done | 现有热点仅持久化像素 frame，无 normalized/anchor/constraint 可直接复用 | 冻结小范围 |
| 架构审计 | GT-1606-02 | done | 持久化模式与完整几何闭环均跨越多个消费者 | 大改后置 |
| 测试设计 | GT-1606-03 | done | HTML 固定 coords 与 CSS 响应式图片存在可复现错位合同 | 定向测试 |
| 开发 | GT-1606-04 | done | 响应式重算、安全 href 与 JavaScriptCore 动态脚本测试完成 | Goal Lead 收口 |
| QA | GT-1606-04 | done | 唯一冷构建成功；导出器/Automation/cursor 合计 5/5，零失败/跳过/重试 | Goal Lead 收口 |
| 独立评审 | GT-1606-04 | done | 两轮安全与测试强度修正后最终 PASS | Goal Lead 收口 |
| Goal Lead | GT-1606-05 | running | 发布契约 9/9（27 断言）、运行器/结构契约及 CLI/MCP 2/2 通过 | 提交、标签、main、远端核验 |
