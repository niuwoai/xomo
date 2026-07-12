# Xomo MCP 与 CLI

> 当前版本：v2.10.0-rc3

## 架构

Xomo MCP 分为两个进程：

- `Xomo.app` 持有真实画布和编辑状态，在 `127.0.0.1` 的随机端口提供本机自动化协议。
- `xomo` 是可独立安装的单文件 CLI；`xomo mcp` 把 MCP JSON-RPC stdio 请求转发到当前运行的 Xomo App。

App 每次启动都会生成新的随机令牌，并以 `0600` 权限写入自身沙盒容器。CLI 只读取当前用户的端点文件；服务拒绝非 loopback 客户端。令牌不会出现在进程参数、MCP 配置和正常日志中。

## 构建与安装 CLI

```bash
scripts/build_xomo_cli_release.sh
dist/xomo-macos-universal install
```

默认安装到 `~/.local/bin/xomo`。也可以指定前缀：

```bash
dist/xomo-macos-universal install /usr/local
```

## CLI

```bash
xomo status
xomo doctor
xomo tools
xomo call xomo.document.get '{}'
xomo call xomo.tool.select '{"tool":"brush"}'
xomo call xomo.selection.rectangle '{"x":20,"y":20,"width":200,"height":120}'
xomo call xomo.component.insert '{"component":"button","theme":"native","x":80,"y":100}'
xomo export ~/Desktop/xomo.png --format png --scope composited --scale 2
xomo project export ~/Desktop/design.qpicproject
xomo project import ~/Desktop/design.qpicproject
xomo import-image ~/Desktop/reference.png --into-selection
```

`xomo call` 的第二个参数必须是 JSON object。对象 ID 可通过 `xomo.layer.list`、`xomo.channel.list`、`xomo.history.list` 和 `xomo.guide.list` 获取。

## MCP 客户端配置

运行 `xomo mcp-config` 可生成配置片段：

```json
{
  "mcpServers": {
    "xomo": {
      "command": "/Users/you/.local/bin/xomo",
      "args": ["mcp"]
    }
  }
}
```

MCP 服务器实现 `initialize`、`ping`、`tools/list` 和 `tools/call`。当 Xomo 尚未启动时，`tools/list` 仍返回二进制内置目录；真正调用编辑工具时会明确提示启动 Xomo。

## 当前工具范围

- 共 104 个 MCP 工具；同类细粒度操作通过带严格枚举参数的 action 工具组织。
- App 与文档状态
- 预设或自定义画布创建、可编辑文字/形状检查与更新，以及详细调整、滤镜和图层样式参数
- 完整 `qpicproject` 项目导入导出，以及 PNG/JPEG/WebP 等图像图层导入
- 28 种编辑器工具选择
- 前景色、背景色、画笔、橡皮擦、渐变
- 矩形、椭圆、文字和 UI 组件创建
- 图层查询、选择、创建、删除、复制、命名、显隐、锁定、透明度、混合模式、移动、排序、分组、链接、合并、对齐、分布、智能对象、Layer Comps 与几何变换
- 图层蒙版、矢量蒙版、十类图层效果、样式复制粘贴、智能滤镜
- 矩形、椭圆、套索、魔棒、快速选择、全选、反选、羽化、平滑、像素填充、描边、清除和内容识别填充
- 系统剪贴板复制、剪切，以及将剪贴板图片粘贴为可编辑图层
- 矢量路径创建、锚点与控制柄、子路径、闭合与反向、填充、描边、选区和蒙版转换
- Alpha 通道查询、创建、复制、改名、删除及选择布尔运算
- 历史状态、撤销、重做、截断、恢复与命名快照
- 图像尺寸、画布尺寸、裁切、缩放、参考线与网格
- 22 类可编辑 UI 组件与七套主题
- PNG、JPEG、WebP、PDF、SVG、PSD 渲染导出

## 边界

- MCP 操作当前活动编辑器窗口，不在后台偷偷创建不可见文档。
- 涉及系统文件选择器的菜单命令不直接远程点击；CLI 通过编码数据与 App 交换，再由 CLI 在用户指定路径读写项目、图像和导出文件，保持沙盒边界清晰。
- 第一版不开放局域网、远程 TCP 或固定长期令牌。
