# rc1761 光标策略复核与桌面验收阻断

- 源码基线：本地 `main` `d87ffce1`；工作区干净。
- 安装候选：`/Applications/Xomo.app` 为 `2.12.0-rc1760` / build `1760`。
- 目的：在继续接近 rc1800 完整门槛前，复核组件库系统箭头及工具语义光标。

## 当前源码测试

- 命令：`ruby scripts/run_tests_isolated.rb --group-by-suite --filter ImageEditorCanvasCursorTests --out /private/tmp/veilpic-rc1761-cursor-current`。
- 首次构建因受限环境不能写 Swift/Clang 用户缓存失败（`Operation not permitted`），没有执行测试；授权环境中使用同一命令和仓库构建锁重跑。
- 最终结果：build-for-testing 成功，`ImageEditorCanvasCursorTests` 130/130 通过，1/1 执行组通过，0 失败。
- 该结果证明当前源码的光标解析策略回归通过，不证明真实桌面鼠标下 AppKit cursor-rect 和组件库悬停/选中表现。

## 安装版启动与签名观察

- 初次 `open -a /Applications/Xomo.app` 返回 Launch Services `kLSNoExecutableErr`；包内 `CFBundleExecutable` 为 `Xomo`，对应 `Contents/MacOS/Xomo` 文件实际存在且为 arm64/x86_64 通用二进制。紧接着直接执行该二进制退出码 134。
- 安装包与 rc1760 archive 的逐项文件清单和 SHA-256 完全一致；因此没有证据表明安装包在拷贝后发生内容漂移。
- 同一检查轮中，`codesign --verify --deep --strict` 对安装包、archive、rc1729 可恢复副本及系统 `/usr/bin/osascript` 均曾报告信任/签名错误。稍后复查时 `/usr/bin/osascript`、`/Applications/Xomo.app` 与 Gatekeeper 均恢复为有效；再次 `open -a` 成功，AppleScript 读到进程 `Xomo` 和窗口“未命名画布”，并正常退出。故初次启动/验签失败是已恢复的主机瞬态，不能据此判定应用包损坏。
- 可访问性 API 可读取 Xomo 窗口标题和矩形，但查询嵌套元素返回 `-10827`；普通及授权级 `screencapture -C` 均返回 `could not create image from display`。没有获得包含实际鼠标指针的桌面图像，未建立可用的指针观察通道。

## 结论与后续

- 未观察到组件库悬停/选中时的真实光标，未验证工具切换、画布进出时的指针恢复；光标运行时验收仍未通过。
- 当前安装启动与签名已恢复，但显示捕获/辅助功能通道仍不可用。没有改写或覆盖 `/Applications`，也没有修改产品源码。
- rc1800 门槛继续要求实际桌面光标冒烟；执行前需取得可用的屏幕/指针观察通道。不得将本记录当作完整门槛通过证据。
