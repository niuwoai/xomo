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

- `open -a /Applications/Xomo.app` 返回 Launch Services `kLSNoExecutableErr`；包内 `CFBundleExecutable` 为 `Xomo`，对应 `Contents/MacOS/Xomo` 文件实际存在且为 arm64/x86_64 通用二进制。
- 直接执行该二进制退出码 134，未得到光标观察结果。
- 安装包与 rc1760 archive 的逐项文件清单和 SHA-256 完全一致；因此没有证据表明安装包在拷贝后发生内容漂移。
- 当前 `codesign --verify --deep --strict` 对安装包、archive 及 rc1729 可恢复副本均报告签名无效；对系统 `/usr/bin/osascript` 的验证返回 `CSSMERR_TP_NOT_TRUSTED`。这是当前主机签名信任链/验证环境异常的证据，但尚不能据此认定其为启动失败的唯一原因，也不能推翻 rc1760 当时记录的验签结果。
- AppleScript `System Events` 只读进程查询返回错误 `-10827`，未建立可用的桌面鼠标自动化通道。

## 结论与后续

- 未观察到组件库悬停/选中时的真实光标，未验证工具切换、画布进出时的指针恢复；光标运行时验收仍未通过。
- 当前结果是安装启动/主机信任环境风险，不是已确认的光标算法回归。没有改写或覆盖 `/Applications`，也没有修改产品源码。
- rc1800 门槛继续要求实际桌面光标冒烟；执行前需先让安装版可正常启动，并区分主机代码签名信任故障与 Xomo 自身启动故障。不得将本记录当作完整门槛通过证据。
