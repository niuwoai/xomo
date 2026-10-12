# rc1805 自定义缩放对话框布局

## 发现与修复

rc1804 的九点锚点逻辑测试通过，但对隔离构建版做实际 UI 检查时发现 `NSAlert.accessoryView` 中的 percentage field 和 anchor picker 越出窗口右侧，且与说明文字重叠。根因是纵向 `NSStackView` 未按其内容尺寸设置 frame。rc1805 在赋给 alert 前显式使用 `fittingSize` 设置 stack frame。

## 验证

- 2026-10-12 16:44（Asia/Shanghai）：`ImageEditorSelectionPixelTransformTests` 22/22 通过，0 次基础设施重试。
- 发布合同：10 tests / 30 assertions；CLI 发布合同：7 / 24；产品概览合同：3 / 30，均通过。
- `plutil -lint` 对 en、ja、zh-Hans 三语 `.strings` 资源通过；`plutil -lint veilpic.xcodeproj/project.pbxproj` 与 `git diff --check` 通过。
- 用 rc1805 隔离构建版在临时空白画布启动「编辑 → 缩放选区像素 → 自定义比例…」。截图确认说明、百分比输入与参考点菜单完整分行显示，没有重叠或裁切；菜单中九个锚点均可见，默认值为“中心”。
- 临时选取“左上角”，输入 200% 并应用，状态栏读回“已将选区像素缩放到 200%（固定参考点：左上角）”；撤销恢复原选区反馈、重做可用。最后丢弃未命名临时项目，不保存用户图稿。

## 门槛边界

此次为隔离 Debug 构建和临时 GUI 冒烟，不是全量 Release 构建、签名验收或 `/Applications` 覆盖安装。下一完整构建/冒烟/安装门槛仍为 rc1840；rc1800 记录中的系统签名信任异常继续单独跟踪，不绕过 Gatekeeper。
