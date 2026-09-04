# PRD：2.12.0-rc1602 画布平移鼠标语义

## 背景

本需求来源于已确认的 Requirement Specification Card。Xomo 已有丰富的 Photoshop 式工具光标和 Sketch/Figma 式对象箭头语义，本版修复剩余的输入优先级断点，不重做已有光标。

## 功能需求

1. 空闲 Space 临时平移或已激活画布平移优先于控制点悬停光标。
2. 平移首击不得启动 resize、rotate、reference point 或对象移动候选。
3. 已开始的对象/变换事务保持原事务和原光标，不被后来 Space 打断。
4. Move 工具无可移动目标、未启用框选时返回系统箭头。
5. 组件库普通箭头、真实对象拖动、真实平移和控制点语义保持不变。

## 验收

- 新回归能证明旧优先级错误，修复后通过。
- 平移只改变 canvasOffset，不改变对象 frame 或 History。
- 光标、Space、中键、对象移动和变换邻接测试全部通过。
- App、CLI、Xcode 版本统一为 2.12.0-rc1602/build1602。
- 更新 Changelog、产品概览和路线图；提交、标签、main 与远端闭环。
