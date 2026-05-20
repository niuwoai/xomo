# 轻图产品概览

## 产品定位

轻图是一个 macOS native 图床客户端，工程名保留 VeilPic。它面向经常写文档、发 issue、写博客、做客服或协作沟通的人：用户把截图、图片文件拖入系统托盘面板，或复制截图后点击菜单栏图标，轻图自动读取剪贴板图片、生成多种图片版本、上传到用户自己的对象存储，并把可分享 URL 写回剪贴板。

核心原则：不要求终端用户依赖轻图自建服务器。用户提供自己的云存储凭据，客户端直接上传到目标存储后端。

## 核心工作流

1. 用户截图或复制图片。
2. 点击 macOS 菜单栏里的轻图图标。
3. 在下拉面板里拖拽图片，或点击读取剪贴板图片。
4. 客户端生成原图、压缩图、缩略图和 WebP 引用版本。
5. 客户端上传到用户配置的存储后端。
6. 客户端返回多种 URL，并默认复制原图 URL。

## 支持的存储后端

当前产品设计以统一的 `ImageUploading` 协议承载多后端能力：

- 阿里云 OSS
- Amazon S3
- Cloudflare R2
- 腾讯云 COS
- 七牛云 Kodo
- Wasabi
- Backblaze B2
- DigitalOcean Spaces
- MinIO
- 兼容 S3 的对象存储服务

后续实现真实上传时，应优先拆分为独立 provider，并把签名、区域、endpoint、bucket、ACL、Content-Type、缓存策略等逻辑封装在 provider 内部。

## 配置项

基础配置：

- 存储后端类型
- Access Key ID
- Access Key Secret
- Bucket
- Region
- Endpoint 或 API 域名
- CDN 域名
- 对象前缀

安全要求：

- 密钥不应明文写入仓库、日志或崩溃报告。
- macOS 客户端应优先使用 Keychain 保存 secret。
- 导出配置时必须脱敏。

## 图片版本策略

默认生成：

- 原图：保留 PNG，用于最高保真场景。
- 压缩图：限制宽度并使用 JPEG 压缩，用于常规分享。
- 缩略图：小尺寸 JPEG，用于列表、预览、文档摘要。
- WebP 引用：保留链接形态，后续接入真实 WebP 编码或云端转换能力。

后续可配置：

- 是否保留原图
- 压缩质量
- 最大宽度
- 缩略图尺寸
- 文件命名模板
- 是否按日期目录归档
- 是否写入随机后缀避免撞名

## 当前实现状态

1.9.0 已提供 macOS 托盘窗口、首次启动三步设置引导、独立存储设置窗口、拖拽区、剪贴板读取、多版本图片数据生成、链接结果区和上传历史页，并接入“轻图”正式 AppIcon。首次启动或存储配置未完成时，轻图会主动打开普通设置窗体，用“准备存储 / 填写配置 / 回到菜单栏”三步说明初始化路径；第二步会根据当前配置完整度显示已完成状态或缺失字段，帮助用户确认每一步信息。托盘面板已精简为“上传 / 链接 / 历史”，配置表单移出托盘，避免为了低频设置拉高整个弹窗。配置页会按不同存储后端展示官方常用凭据名称，例如阿里云 OSS 的 `AccessKey ID / AccessKey Secret`、腾讯云 COS 的 `SecretId / SecretKey`、七牛云 Kodo 的 `AccessKey / SecretKey`、Backblaze B2 的 `Application Key ID / Application Key`。Cloudflare R2 支持长期 S3 API 凭据，也支持临时凭据模式下的 `Session Token`。配置会自动保存，普通配置写入 UserDefaults，Access Key Secret 和 Session Token 写入 macOS Keychain。上传前会校验必要字段，失败时打开设置窗口并提示缺失字段；上传过程中会展示读取、生成、上传、复制和完成状态；成功、警告、错误和处理中反馈都有独立横幅。上传成功后会保存本地历史记录，包括缩略图预览、上传时间、来源、provider、bucket 和各版本链接；历史页支持复制主链接、复制全部链接、复制 Markdown 图片引用和删除本地记录。项目已新增隐私清单，声明仅使用 UserDefaults 做本地配置和历史保存，不采集用户数据、不做追踪。上传服务已经接入真实对象存储 PUT / 表单上传：

- Amazon S3、兼容 S3 和 Cloudflare R2 使用 AWS Signature V4。
- Wasabi、Backblaze B2、DigitalOcean Spaces 和 MinIO 复用 S3 兼容 AWS Signature V4 上传链路。
- 阿里云 OSS 使用 OSS HMAC-SHA1 签名。
- 腾讯云 COS 使用 COS HMAC-SHA1 签名。
- 七牛云 Kodo 使用上传策略 token 和 multipart 表单上传。
- URL 返回优先使用 CDN 域名；未配置 CDN 时使用 endpoint。

下一阶段应继续补齐生产化能力：

- 增加历史搜索、按 provider / bucket 过滤和收藏置顶。
- 增加 provider 连接测试、Bucket 列表读取和路径写入权限检查。
- 增加真实云端集成测试；测试凭据必须通过本地环境变量注入，不得提交到仓库。
