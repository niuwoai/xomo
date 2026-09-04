# 2.12.0-rc1614 Decisions

- Slice 不参与 `revealAllCanvasRect()`；只有旧画布与可见可合成图层的渲染边界决定新画布。
- Slice 复用 rc1612 的完整浮点平移与源/目标 preset 双校验 helper；源整数可见交集只校验，不替代完整历史 frame 的几何。
- Reveal 必须稳定 `map` 全部 Slice；helper 返回 nil 即视为 unexpected removal 并原子失败，禁止 `compactMap`。
- 部分旧画布越界区域若落入新 target 可重新显露；源完全不可见仍是损坏输入，不能借 Reveal 复活。
- 成功只更新 frame，保持 Slice 数量、顺序、UUID、名称和 preset 全字段及 Optional 形态；随后协调 Slice scope 和主 preset。
- optional nil 分支在合法 Reveal 数学下不可达，不为动态命中而扭曲公开 API；由生产 guard 和独立静态复核保证。
