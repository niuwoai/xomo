# 测试计划：rc1606

## 直接测试

- 80×60 画布上的 (10,12,30,20) 保留 `coords="10,12,40,32"` 回退及同值源坐标元数据。
- 图片节点包含稳定标识与源宽高。
- 脚本分别从 `clientWidth/sourceWidth` 和 `clientHeight/sourceHeight` 计算比例并将四个坐标取整。
- 初始、load、window resize 与可用时 ResizeObserver 都调用同一同步函数。
- 名称、URL、标题继续正确 HTML 转义，用户内容不进入脚本。
- 危险/未知协议回退 `#`，合法绝对、相对与片段地址保持可用。
- 使用 JavaScriptCore 最小 DOM mock 实际执行脚本，验证多个 area 的非等比缩放及全部触发路径。

## 相邻回归

- `ImageEditorExportFormatTests` 的热点 HTML 测试。
- `XomoAutomationTests` 的热点 update/export 测试。
- 发布契约、隔离测试器契约、发布结构与 CLI/MCP 2/2。
- 组件库 cursor 合同不改；动态门禁至少复跑其系统箭头核心测试。

rc1606 不执行 Release/安装；rc1640 执行完整门禁。
