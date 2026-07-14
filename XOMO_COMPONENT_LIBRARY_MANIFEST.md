# 像界（Xomo）组件库资源清单

> 最后更新：2026-07-15 ｜ 组件库版本：v2.12.0-rc67

这份清单记录 UI 组件库 v1 的资源来源、许可和版本。它只覆盖组件库自身的预览与默认插入内容；用户之后导入的图片由其自己负责相应权利。

## 风格包、来源与许可

- **可编辑性**：所有包都由文字、形状、路径或像素图层组成；用户插入后可用现有图层工具逐层修改，不会得到不可编辑的品牌截图。
- **像界原创**：柔和安卓、社交内容、玻璃拟态、高密度后台与极简 SaaS 是 Xomo 原创 token、几何、排版与占位内容，许可证标为 `Xomo Original`。
- **第三方参考包**：Chakra UI 与 Radix Themes 仅作为设计系统来源与命名标注；本项目未复制其 React/TypeScript 源码、官方图标、品牌标识、截图或其他素材。Xomo 中实际插入的是本地原生实现的可编辑图层，并非官方产品或官方组件发行版。

| 风格包 | 来源 | 许可证 / 义务 | Xomo 内实现 |
| --- | --- | --- | --- |
| 柔和安卓、社交内容、玻璃拟态、高密度后台、极简 SaaS | Xomo 原创 | Xomo Original | 原生 token + 可编辑图层 |
| Chakra UI 参考 | [chakra-ui/chakra-ui LICENSE](https://github.com/chakra-ui/chakra-ui/blob/main/LICENSE) | MIT；出处与版权声明见第三方声明 | 原生可编辑参考包，不复制上游代码 |
| Radix Themes 参考 | [radix-ui/themes LICENSE](https://github.com/radix-ui/themes/blob/main/LICENSE) | MIT；出处与版权声明见第三方声明 | 原生可编辑参考包，不复制上游代码 |

| 组件家族 | 可插入变体 | 来源 | 许可证 | 资源类型 | 首次版本 |
| --- | --- | --- | --- | --- | --- |
| 按钮 | 主、次、幽灵 | Xomo 原创代码生成 | Xomo Original | 形状 + 文字 | v2.3.0-rc1 |
| 图标按钮 | 图标按钮 | Xomo 原创代码生成 | Xomo Original | 形状 + 文字 | v2.3.0-rc1 |
| 标签 | 标签 | Xomo 原创代码生成 | Xomo Original | 形状 + 文字 | v2.3.0-rc3 |
| 徽标 | 徽标 | Xomo 原创代码生成 | Xomo Original | 形状 + 文字 | v2.3.0-rc3 |
| 文本输入 | 输入框 | Xomo 原创代码生成 | Xomo Original | 形状 + 文字 | v2.2.0-rc3 |
| 搜索输入 | 搜索框 | Xomo 原创代码生成 | Xomo Original | 形状 + 文字 | v2.3.0-rc2 |
| 多行输入 | 文本域 | Xomo 原创代码生成 | Xomo Original | 形状 + 文字 | v2.3.0-rc2 |
| 选择输入 | 选择框 | Xomo 原创代码生成 | Xomo Original | 形状 + 文字 | v2.3.0-rc2 |
| 开关 | 开关 | Xomo 原创代码生成 | Xomo Original | 形状 | v2.3.0-rc3 |
| 复选框 | 复选框 | Xomo 原创代码生成 | Xomo Original | 形状 + 文字 | v2.3.0-rc3 |
| 卡片 | 卡片 | Xomo 原创代码生成 | Xomo Original | 形状 + 文字 | v2.2.0-rc4 |
| 列表 | 列表行 | Xomo 原创代码生成 | Xomo Original | 形状 + 文字 | v2.3.0-rc4 |
| 顶部导航 | 顶部导航 | Xomo 原创代码生成 | Xomo Original | 形状 + 文字 | v2.3.0-rc4 |
| 侧边导航 | 侧边导航 | Xomo 原创代码生成 | Xomo Original | 形状 + 文字 | v2.3.0-rc4 |
| Tab 导航 | Tab 栏 | Xomo 原创代码生成 | Xomo Original | 形状 + 文字 | v2.3.0-rc4 |
| 轮播内容 | 轮播卡片 | Xomo 原创代码生成 | Xomo Original | 像素 + 形状 + 文字 | v2.3.0-rc5 |
| 空内容 | 空状态 | Xomo 原创代码生成 | Xomo Original | 形状 + 文字 | v2.3.0-rc5 |
| 视觉占位 | 图片占位符、头像、通用图标 | Xomo 原创代码生成 | Xomo Original | 像素 / 形状 / 路径 / 文字 | v2.2.0-rc5 |

## 18 个家族与 22 个变体的计数说明

路线图的“18 项”按用户可理解的**组件家族**计算。库内把按钮的三种层级、图片 / 头像 / 通用图标等做成独立可插入变体，因此目前共有 22 个插入入口，仍归属上表固定的 18 个家族。新增入口若不属于这些家族，必须移入下一批，不得继续扩大 v1 范围。
