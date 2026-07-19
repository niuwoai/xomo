# rc401 对象坐标选择测试报告

- 日期：2026-07-19
- 版本：`2.12.0-rc401`
- Debug `build-for-testing`：通过
- 定点测试：**3/3 通过**

通过项目：

- `registryAdvertisesBroadEditorCapabilities`
- `registrySelectsCanvasComponentsAndDeepChildrenByVisiblePoint`
- `registryObjectPointSelectionCanClearOnMissAndRejectUnknownDepth`

覆盖 MCP 工具声明、组件父对象命中、深层子图层命中、真实联合边界、空白清选、非法模式拒绝，以及选择操作不写入 History。

本版不是 40 个 rc 的完整门禁版本，未执行 Release 安装覆盖；下一次完整门禁为 rc440。
