# 2.12.0-rc1602 Tasklist

Goal：抓手只表示真实画布平移，并保持既有组件、对象和工具鼠标语义。

| Task ID | Member | Claimed By | Status | Locked Scope | Deliverable | Done Criteria | Verification | Docs/SPEC Update |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| GT-1602-01 | 需求分析-现代图像编辑器路线图 | requirements_rc1602 | done | 只读 | 需求与后续路线 | 找到非重复、可验证里程碑 | 独立评审 | 规格卡、PRD |
| GT-1602-02 | 开发-画布平移鼠标语义 | developer_rc1602 | done | 画布输入、光标及直接测试 | 最小修复 | 光标与动作一致，活动事务稳定 | QA + 评审 | Architecture Design |
| GT-1602-03 | 测试-版本门禁验收 | qa_rc1602 | done | 独立动态测试 | 测试计划与执行证据 | 定向测试及契约全绿 | 评审 | Test Plan、Acceptance |
| GT-1602-04 | 评审-鼠标语义与路线复核 | review_rc1602 | passed | 只读 | 独立评审 | 缺口、边界和验收明确 | Goal Lead | Acceptance |
| GT-1602-05 | Goal Lead | root | running | 版本、文档、Git | rc1602 闭环 | 提交、标签、main、远端一致 | Git + 契约 | 全部状态文档 |

动态门禁已恢复并完成：唯一 `build-for-testing` 成功；新增测试 11/11、相关套件 197/197 通过，合计实际执行 208 项、22 个执行组，失败 0、跳过 0。此前受外部构建污染的中断结果继续作废，不计入通过证据。
