# rc158 Figma 描边样式报告

- 定向测试：`mapperAndMaterializerPreserveFigmaStrokeCapAndJoin`
- 编译：**通过**（`build-for-testing` 成功）。
- 运行：当前受限 macOS 环境的 `testmanagerd`/分布式通知服务不可用，`xcodebuild test-without-building` 在测试主进程启动后返回失败，未产生断言结果；原始运行日志已移至临时目录。
- 代码覆盖：Figma `SQUARE`/`BEVEL` 映射、`NONE`→`butt` 兼容回退、Shape 模型和项目存档字段。
