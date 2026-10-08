# rc1753 复合路径组件顺序调整

## 用户工作流

闭合复合路径按组件顺序应用合并、减去、相交与排除。此前用户可以更改单个组件的运算，却不能调整绘制顺序；相交形状需要先后叠加、或希望改变减去组件对交叠区域的影响时，只能手工删除并重建路径。

## 实现

- 路径属性面板增加“组件上移 / 组件下移”，只改变复合路径内部顺序，不改变图层栈顺序。
- 子路径几何与对应布尔运算一并交换，保持组件身份；`continuePrevious` 不会被移到首组件。
- 重排以一个 History/Undo 事务提交，并保留当前被选中的组件及其锚点索引。
- 简体中文、英语、日语文案同步。

## 验证

- `ImageEditorVectorLayerTests`：112/112 实际通过，0 失败。新增覆盖重叠的合并/减去组件，验证交叠像素随组件顺序改变、独占区域不变，运算数组与几何一起重排，Undo/Redo 恢复像素和运算；另测首项 `continuePrevious` 的非法移动不产生事务。
- `LocalizationResourceTests`：46/46 实际通过，新增中英日动作、状态与历史文案均能从资源表加载。
- `scripts/test_release_contract.rb`：10 runs / 30 assertions 通过。
- `scripts/test_xomo_cli_release_build.rb`：7 runs / 24 assertions 通过。
- `scripts/verify_release_contract.rb`：通过，App/CLI/Xcode 版本 `2.12.0-rc1753`，build 号 `1753`。
- `scripts/test_product_overview_archive.rb`：3 runs / 26 assertions 通过。
- `git diff --check`：通过。

测试由仓库级构建锁串行执行。首次像素回归选点落在第三组件独占区，失败后按实际重叠范围修正为 `x=71` 并重跑；最终完整向量套件通过。未做真实 SwiftUI 按钮冒烟、全量构建或 `/Applications` 安装；下一完整门槛仍为 rc1760。
