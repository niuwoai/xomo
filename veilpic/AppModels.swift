//
//  AppModels.swift
//  veilpic
//
//  Created by Codex on 2026/5/20.
//

import Foundation

enum AppVersion {
    static let current = "1.9.0"
}

enum StorageCredentialMode: String, CaseIterable, Identifiable, Codable {
    case longTerm
    case temporary

    var id: String { rawValue }

    var title: String {
        switch self {
        case .longTerm:
            "长期 S3 API 凭据"
        case .temporary:
            "临时凭据"
        }
    }

    var note: String {
        switch self {
        case .longTerm:
            "使用控制台创建的 Access Key ID 和 Secret Access Key。"
        case .temporary:
            "使用临时 Access Key ID、Secret Access Key 和 Session Token。"
        }
    }
}

enum StorageProviderKind: String, CaseIterable, Identifiable, Codable {
    case aliyunOSS
    case amazonS3
    case cloudflareR2
    case tencentCOS
    case qiniuKodo
    case wasabi
    case backblazeB2
    case digitalOceanSpaces
    case minio
    case customS3

    var id: String { rawValue }

    var title: String {
        switch self {
        case .aliyunOSS:
            "阿里云 OSS"
        case .amazonS3:
            "Amazon S3"
        case .cloudflareR2:
            "Cloudflare R2"
        case .tencentCOS:
            "腾讯云 COS"
        case .qiniuKodo:
            "七牛云 Kodo"
        case .wasabi:
            "Wasabi"
        case .backblazeB2:
            "Backblaze B2"
        case .digitalOceanSpaces:
            "DigitalOcean Spaces"
        case .minio:
            "MinIO"
        case .customS3:
            "兼容 S3"
        }
    }

    var shortTitle: String {
        switch self {
        case .aliyunOSS:
            "OSS"
        case .amazonS3:
            "S3"
        case .cloudflareR2:
            "R2"
        case .tencentCOS:
            "COS"
        case .qiniuKodo:
            "Kodo"
        case .wasabi:
            "Wasabi"
        case .backblazeB2:
            "B2"
        case .digitalOceanSpaces:
            "Spaces"
        case .minio:
            "MinIO"
        case .customS3:
            "S3-like"
        }
    }

    var symbolName: String {
        switch self {
        case .aliyunOSS:
            "shippingbox"
        case .amazonS3:
            "externaldrive.connected.to.line.below"
        case .cloudflareR2:
            "cloud"
        case .tencentCOS:
            "square.stack.3d.up"
        case .qiniuKodo:
            "tray.and.arrow.up"
        case .wasabi:
            "leaf"
        case .backblazeB2:
            "flame"
        case .digitalOceanSpaces:
            "circle.grid.cross"
        case .minio:
            "internaldrive"
        case .customS3:
            "server.rack"
        }
    }

    var endpointPlaceholder: String {
        switch self {
        case .aliyunOSS:
            "https://bucket.oss-cn-hangzhou.aliyuncs.com"
        case .amazonS3:
            "https://s3.us-east-1.amazonaws.com"
        case .cloudflareR2:
            "https://<account-id>.r2.cloudflarestorage.com"
        case .tencentCOS:
            "https://bucket-appid.cos.ap-guangzhou.myqcloud.com"
        case .qiniuKodo:
            "https://upload-z2.qiniup.com"
        case .wasabi:
            "https://s3.wasabisys.com"
        case .backblazeB2:
            "https://s3.us-west-001.backblazeb2.com"
        case .digitalOceanSpaces:
            "https://nyc3.digitaloceanspaces.com"
        case .minio:
            "https://minio.example.com"
        case .customS3:
            "https://storage.example.com"
        }
    }

    var regionPlaceholder: String {
        switch self {
        case .aliyunOSS:
            "cn-hangzhou"
        case .amazonS3:
            "us-east-1"
        case .cloudflareR2:
            "auto"
        case .tencentCOS:
            "ap-guangzhou"
        case .qiniuKodo:
            "z2"
        case .wasabi:
            "us-east-1"
        case .backblazeB2:
            "us-west-001"
        case .digitalOceanSpaces:
            "nyc3"
        case .minio:
            "us-east-1 或服务端配置"
        case .customS3:
            "auto 或服务商区域"
        }
    }

    var configurationNote: String {
        switch self {
        case .aliyunOSS:
            "Endpoint 建议使用 bucket 绑定后的 OSS 域名；CDN 域名可选。"
        case .amazonS3:
            "使用 path-style 上传；Bucket 会写入请求路径。"
        case .cloudflareR2:
            "Region 可填 auto；Endpoint 使用账号级 R2 API 域名。"
        case .tencentCOS:
            "Endpoint 通常包含 bucket-appid 和区域。"
        case .qiniuKodo:
            "Endpoint 使用上传域名；必须配置 CDN 域名用于返回公开链接。"
        case .wasabi:
            "Wasabi 使用 S3 兼容 API；Region 通常与 endpoint 匹配。"
        case .backblazeB2:
            "使用 B2 S3 Endpoint；Application Key ID 相当于 Access Key。"
        case .digitalOceanSpaces:
            "Endpoint 使用 Spaces 区域域名；可选 CDN 域名用于公开访问。"
        case .minio:
            "适合自建 MinIO；Endpoint 填写 MinIO API 地址。"
        case .customS3:
            "适合 MinIO、Wasabi、Backblaze B2 等兼容 S3 的服务。"
        }
    }

    var accessKeyLabel: String {
        switch self {
        case .aliyunOSS:
            "AccessKey ID"
        case .tencentCOS:
            "SecretId"
        case .qiniuKodo:
            "AccessKey"
        case .backblazeB2:
            "Application Key ID"
        case .amazonS3, .cloudflareR2, .wasabi, .digitalOceanSpaces:
            "Access Key ID"
        case .minio, .customS3:
            "Access Key"
        }
    }

    var secretKeyLabel: String {
        switch self {
        case .aliyunOSS:
            "AccessKey Secret"
        case .amazonS3, .cloudflareR2, .wasabi:
            "Secret Access Key"
        case .tencentCOS:
            "SecretKey"
        case .qiniuKodo:
            "SecretKey"
        case .backblazeB2:
            "Application Key"
        case .digitalOceanSpaces, .minio, .customS3:
            "Secret Key"
        }
    }

    var supportsTemporaryCredentials: Bool {
        self == .cloudflareR2
    }

    var usesS3V4Signing: Bool {
        switch self {
        case .amazonS3, .cloudflareR2, .wasabi, .backblazeB2, .digitalOceanSpaces, .minio, .customS3:
            true
        case .aliyunOSS, .tencentCOS, .qiniuKodo:
            false
        }
    }
}

struct StorageProfile {
    var provider: StorageProviderKind = .aliyunOSS
    var credentialMode: StorageCredentialMode = .longTerm
    var accessKeyId = ""
    var accessKeySecret = ""
    var sessionToken = ""
    var bucket = ""
    var region = ""
    var endpoint = ""
    var cdnDomain = ""
    var objectPrefix = "veilpic"

    var baseURL: URL? {
        let rawDomain = cdnDomain.isEmpty ? endpoint : cdnDomain
        guard !rawDomain.isEmpty else { return nil }
        let normalized = rawDomain.hasPrefix("http") ? rawDomain : "https://\(rawDomain)"
        return URL(string: normalized.trimmingCharacters(in: CharacterSet(charactersIn: "/")))
    }

    var requiredFields: [(name: String, value: String)] {
        var fields = [
            ("Bucket", bucket),
            ("Endpoint / API 域名", endpoint),
            (provider.accessKeyLabel, accessKeyId),
            (provider.secretKeyLabel, accessKeySecret)
        ]

        if provider.supportsTemporaryCredentials, credentialMode == .temporary {
            fields.append(("Session Token", sessionToken))
        }

        if provider == .qiniuKodo {
            fields.append(("七牛云 CDN 域名", cdnDomain))
        }

        return fields
    }

    var missingFields: [String] {
        requiredFields
            .filter { $0.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .map(\.name)
    }

    var configurationProgress: Double {
        guard !requiredFields.isEmpty else { return 1 }
        let filledCount = requiredFields.count - missingFields.count
        return Double(filledCount) / Double(requiredFields.count)
    }

    var isReadyForUpload: Bool {
        missingFields.isEmpty
    }

    var activeSessionToken: String {
        guard provider.supportsTemporaryCredentials, credentialMode == .temporary else {
            return ""
        }

        return sessionToken
    }
}

enum ImageVariantKind: String, CaseIterable, Identifiable, Codable {
    case original
    case compressed
    case thumbnail
    case webpReference

    var id: String { rawValue }

    var title: String {
        switch self {
        case .original:
            "原图"
        case .compressed:
            "压缩图"
        case .thumbnail:
            "缩略图"
        case .webpReference:
            "WebP"
        }
    }

    var detail: String {
        switch self {
        case .original:
            "保留 PNG 原始质量"
        case .compressed:
            "适合文档和聊天分享"
        case .thumbnail:
            "适合列表和预览"
        case .webpReference:
            "更小体积的现代格式"
        }
    }

    var symbolName: String {
        switch self {
        case .original:
            "photo"
        case .compressed:
            "rectangle.compress.vertical"
        case .thumbnail:
            "square.grid.2x2"
        case .webpReference:
            "sparkles.rectangle.stack"
        }
    }
}

struct GeneratedImageVariant: Identifiable {
    let id = UUID()
    let kind: ImageVariantKind
    let filename: String
    let data: Data
    let contentType: String

    var byteCountText: String {
        ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file)
    }
}

struct UploadResult: Identifiable {
    let id = UUID()
    let sourceName: String
    let createdAt: Date
    let links: [ImageVariantKind: URL]
}

struct UploadHistoryItem: Identifiable, Codable, Equatable {
    let id: UUID
    let sourceName: String
    let createdAt: Date
    let provider: StorageProviderKind
    let bucket: String
    let thumbnailData: Data?
    let links: [ImageVariantKind: URL]

    var primaryURL: URL? {
        links[.original] ?? links[.compressed] ?? links[.thumbnail] ?? links[.webpReference]
    }

    var providerSummary: String {
        bucket.isEmpty ? provider.shortTitle : "\(provider.shortTitle) · \(bucket)"
    }

    init(
        id: UUID = UUID(),
        sourceName: String,
        createdAt: Date,
        provider: StorageProviderKind,
        bucket: String,
        thumbnailData: Data?,
        links: [ImageVariantKind: URL]
    ) {
        self.id = id
        self.sourceName = sourceName
        self.createdAt = createdAt
        self.provider = provider
        self.bucket = bucket
        self.thumbnailData = thumbnailData
        self.links = links
    }
}

enum PanelSection: String, CaseIterable, Identifiable {
    case upload
    case links
    case history

    var id: String { rawValue }

    var title: String {
        switch self {
        case .upload:
            "上传"
        case .links:
            "链接"
        case .history:
            "历史"
        }
    }

    var icon: String {
        switch self {
        case .upload:
            "arrow.up.circle"
        case .links:
            "link"
        case .history:
            "clock.arrow.circlepath"
        }
    }
}

enum UploadPhase: Equatable {
    case idle
    case reading
    case preparing
    case uploading(current: Int, total: Int)
    case copying
    case finished
    case failed

    var progress: Double {
        switch self {
        case .idle:
            return 0
        case .reading:
            return 0.12
        case .preparing:
            return 0.28
        case .uploading(let current, let total):
            guard total > 0 else { return 0.5 }
            return 0.35 + (Double(current) / Double(total)) * 0.52
        case .copying:
            return 0.92
        case .finished:
            return 1
        case .failed:
            return 1
        }
    }

    var title: String {
        switch self {
        case .idle:
            "准备就绪"
        case .reading:
            "正在读取图片"
        case .preparing:
            "正在生成多版本"
        case .uploading(let current, let total):
            "正在上传 \(current)/\(total)"
        case .copying:
            "正在复制链接"
        case .finished:
            "上传完成"
        case .failed:
            "上传失败"
        }
    }
}

enum FeedbackKind: Equatable {
    case success
    case warning
    case error
    case progress

    var symbolName: String {
        switch self {
        case .success:
            "checkmark.circle.fill"
        case .warning:
            "exclamationmark.triangle.fill"
        case .error:
            "xmark.octagon.fill"
        case .progress:
            "arrow.triangle.2.circlepath"
        }
    }
}

struct UserFeedback: Identifiable, Equatable {
    let id = UUID()
    let kind: FeedbackKind
    let title: String
    let message: String
}

extension DateFormatter {
    static let objectKeyDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd"
        return formatter
    }()
}
