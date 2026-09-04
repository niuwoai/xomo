# Architecture Design：导出时响应式热点

## 设计

- Swift exporter 继续生成原始整数 `coords`，并在固定 data 属性中保存同一源坐标。
- `<img>` 暴露固定源画布宽高和稳定 DOM 标识。
- 内联脚本取得图片 `clientWidth/clientHeight`，分别计算 X/Y scale，再将每个源坐标转换为当前 CSS 像素坐标。
- 使用一次初始同步、load 与 window resize；浏览器支持 `ResizeObserver` 时观察图片元素，覆盖非窗口引起的容器变化。

## 不变量

- 项目持久化和编辑器仍以画布像素 frame 为唯一真相。
- 原 HTML 内容转义、base64 图片、链接目标和 Automation 返回格式不变。
- 无外部依赖、无网络、无用户字符串插入脚本。
