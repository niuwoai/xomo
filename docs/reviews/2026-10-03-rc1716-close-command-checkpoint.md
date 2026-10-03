# rc1716 原生关闭命令与工作流验证

> 2026-10-03（Asia/Shanghai）；基线 main `799adc7f629d7fedf997f429b849438c8e27c326`；分支 `codex/restore-close-shortcut-rc1716`。专项、扩大回归和 Cmd-W 实际保存保护通过，不是完整 Release 门槛。

## 真实入口修复

替换系统文件菜单后的共享菜单只有“取消”，没有关闭快捷键。失败基线 `/private/tmp/veilpic-rc1716-close-baseline-tests.xcresult` 确认原生菜单 Command-W 关闭项为 0：1 个方法/1 次运行、2 处失败断言、退出 65、63.11 秒。此基线版本已更新 rc1716，但关闭生产实现仍是 rc1715，不能误称全部输入与旧版相同。

沿用 `.cancel` 菜单槽位与既有 `actions.cancel → closeWindow → keyWindow.performClose` 路径，三语本地化“关闭”并增加 Cmd-W；不新增事件拦截、不直接 `NSWindow.close`，仍由窗口协调器执行未保存确认。工具栏及其它“取消”文案不变，新 `WindowCommands.strings` 三语实际打包校验。

## 实际回归与夹具修正

- 首轮 `/private/tmp/veilpic-rc1716-close-green-tests.xcresult`：4 组、51 个方法/53 次运行，1 个失败方法、退出 65、41.09 秒；仅夹具要求 `NSMenuItem.action != nil` 失败，快捷键数量和标题已通过。SwiftUI 管理菜单分发时 selector 可为空；实际界面 Cmd-W 能触发原有确认，因此取消内部 selector 假设，不删除快捷键、资源或保护路径检查。
- 最终专项 `/private/tmp/veilpic-rc1716-close-verified-tests.xcresult`：关闭命令、关闭保护、外部打开、键盘路由 4 组，51 个方法/53 次运行，零失败/跳过，退出 0、34.86 秒。新增关闭回归 3 个方法/5 次运行；源码路径契约不冒充实际按键行为。
- 扩大回归 `/private/tmp/veilpic-rc1716-expanded-tests.xcresult`：44 组、860 个方法/1022 次运行，零失败/跳过，退出 0、26.45 秒；复用产物 `test-without-building`，仅不重复此前已测的脏状态性能方法，其它功能回归不排除。
- 404 个已记录输入（401 个 Swift/Xcode 输入加三份新增资源）在最终专项与扩大回归前后未变；有序路径→SHA256 JSON 指纹 `8aa7762478bd2a5adaef5e68b1e20d411cb1b40ede890950376826a30e45907d`。界面验收后只修正新增测试，生产/资源未变；最终 Debug 版本实读 rc1716/1716。
- 版本契约 10 项/30 断言、归档契约 3 项/22 断言、README 29 项及 diff 检查通过。依 build-test-acceleration 技能复用 DerivedData/SourcePackages、唯一锁串行验证，不 clean、不宣称整个构建链路提速。

## 实际 Cmd-W 任务及边界

只使用已有合成项目 `/private/tmp/xomo-ui-transform-rc1713-saved.xomoproject`：46,505,000 字节，原 SHA256 `ed0f8bf54993038d1f121a86d9ef55922c906dd0847ecac2d260e9136107a16d` 前后不变，没有编辑用户项目。

1. 原生文件菜单显示“关闭”。打开 2048² 项目后 Right 微移，Cmd-W 真正弹出“保存/不保存/取消”。取消保留文档，历史 8 项、Undo 1/Redo 0；Cmd-Z 恢复历史 7 项、0/1，再 Cmd-W 无保存确认关闭原项目，重新激活显示新未命名画布。
2. 重开原件并微移，另存为不存在的新文件 `/private/tmp/xomo-ui-close-rc1716-saved.xomoproject`，实际生成 46,505,326 字节、8 个历史标题，SHA256 `478442af2dd2bff46b75a5689701b435b08c9b343b82499d0e74b445bbeb1f3c`。
3. 再微移后 Cmd-W，确认中选择“保存”：新文件变为 46,505,480 字节、格式 10、9 个存储历史标题，SHA256 `f519369b4dc50f062ebdc474d1c00503649d5a03a00b01bf845cf4e3cfe583e4`，随后关闭原项目。实际面板重开新文件，2048²、历史 10 项、Undo/Redo 0/0；保持重开追加历史而不持久化撤销快照的既有语义。

菜单直接 AX 点击多次报索引失效，后续控制仅返回 Unknown 窗口及残留文件菜单，不能计为直接菜单点击通过。随后 Cmd-Q 退出未确认，进程复查自己的 Debug App 仍驻留；没有强制退出其它应用，也不把工具失效直接诊断为产品卡死。此边界须独立复核。没有新增导出像素对照或独立读取窗口脏点，不冒充已验证。

## 产品概览归档与方向

概览从 2999 行降到 559 行；2448 行版本说明移至三份不足 1000 行的历史文件，仅调整六处相对链接。去除归档头尾并还原链接后，历史逐字节一致，SHA256 `5efa1684b561cb8308a62c8e3c084c1c34b4a9f893e60a0a568d9f627a530883`；原“产品定位”至文末正文未变，SHA256 `8fc23ee2abc489bdf663bad653e3a6d65c58a50862cc4277abd2cef3c5bbb8b4`。Ruby 契约检查历史完整性、有效链接、行数与当前版本；历史安装记录不作为当前证明。

上一只读审查窗口为北京时间 10:26:39–14:26:39，main 基线 `8607dbe63795b856c6f17319cc2c5e258d2b94dd`，终点为本轮基线。主线是保存、位图保真、Undo/Redo 与实测性能，没有 Figma 扩张。变换取消依赖栈顶快照，普通编辑仍能压入快照，非变换编辑交错的取消/Redo 尚无有效回归，是下一事务里程碑，而非继续堆微优化。

巨型 View/ViewModel/Scope 测试拆分债务未解决。本轮不安装或公开发布；安装仍 rc1680，旧回退包已失效。下一完整 Release 构建、回归、冒烟及可恢复安装门槛仍 rc1720，覆盖前须验证新完整备份。结构化证据见 [JSON](2026-10-03-rc1716-close-command-result.json)。
