//
//  AppModels.swift
//  veilpic
//
//  Created by Codex on 2026/5/20.
//

import Foundation

enum AppVersion {
    static let current = "1.347.0"
}

enum StorageCredentialMode: String, CaseIterable, Identifiable, Codable, Sendable {
    case longTerm
    case temporary

    var id: String { rawValue }

    var title: String {
        switch self {
        case .longTerm:
            L10n.text("credential.longTerm.title")
        case .temporary:
            L10n.text("credential.temporary.title")
        }
    }

    var note: String {
        switch self {
        case .longTerm:
            L10n.text("credential.longTerm.note")
        case .temporary:
            L10n.text("credential.temporary.note")
        }
    }
}

enum StorageProviderKind: String, CaseIterable, Identifiable, Codable, Sendable {
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
            L10n.text("provider.aliyunOSS.title")
        case .amazonS3:
            "Amazon S3"
        case .cloudflareR2:
            "Cloudflare R2"
        case .tencentCOS:
            L10n.text("provider.tencentCOS.title")
        case .qiniuKodo:
            L10n.text("provider.qiniuKodo.title")
        case .wasabi:
            "Wasabi"
        case .backblazeB2:
            "Backblaze B2"
        case .digitalOceanSpaces:
            "DigitalOcean Spaces"
        case .minio:
            "MinIO"
        case .customS3:
            L10n.text("provider.customS3.title")
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
            "https://oss-cn-hangzhou.aliyuncs.com"
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
            L10n.text("provider.minio.regionPlaceholder")
        case .customS3:
            L10n.text("provider.customS3.regionPlaceholder")
        }
    }

    var configurationNote: String {
        switch self {
        case .aliyunOSS:
            L10n.text("provider.aliyunOSS.note")
        case .amazonS3:
            L10n.text("provider.amazonS3.note")
        case .cloudflareR2:
            L10n.text("provider.cloudflareR2.note")
        case .tencentCOS:
            L10n.text("provider.tencentCOS.note")
        case .qiniuKodo:
            L10n.text("provider.qiniuKodo.note")
        case .wasabi:
            L10n.text("provider.wasabi.note")
        case .backblazeB2:
            L10n.text("provider.backblazeB2.note")
        case .digitalOceanSpaces:
            L10n.text("provider.digitalOceanSpaces.note")
        case .minio:
            L10n.text("provider.minio.note")
        case .customS3:
            L10n.text("provider.customS3.note")
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

struct StorageProfile: Sendable {
    var provider: StorageProviderKind = .aliyunOSS
    var credentialMode: StorageCredentialMode = .longTerm
    var accessKeyId = ""
    var accessKeySecret = ""
    var sessionToken = ""
    var bucket = ""
    var region = ""
    var endpoint = ""
    var cdnDomain = ""
    var objectPrefix = "musepic"
    var automaticallyCopyAfterUpload = true
    var automaticallyCopyScreenshotToClipboard = true
    var automaticCopyVariant: ImageVariantKind = .compressed
    var losslessCompressionBeforeOutput = false

    var baseURL: URL? {
        let rawDomain = cdnDomain.isEmpty ? endpoint : cdnDomain
        guard !rawDomain.isEmpty else { return nil }
        let normalized = rawDomain.hasPrefix("http") ? rawDomain : "https://\(rawDomain)"
        return URL(string: normalized.trimmingCharacters(in: CharacterSet(charactersIn: "/")))
    }

    var requiredFields: [(name: String, value: String)] {
        var fields = [
            (L10n.text("field.bucket"), bucket),
            (L10n.text("field.endpoint"), endpoint),
            (provider.accessKeyLabel, accessKeyId),
            (provider.secretKeyLabel, accessKeySecret)
        ]

        if provider.supportsTemporaryCredentials, credentialMode == .temporary {
            fields.append((L10n.text("field.sessionToken"), sessionToken))
        }

        if provider == .qiniuKodo {
            fields.append((L10n.text("field.qiniuCdnDomain"), cdnDomain))
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

enum ImageVariantKind: String, CaseIterable, Identifiable, Codable, Sendable {
    case original
    case compressed
    case thumbnail
    case webpReference

    var id: String { rawValue }

    var title: String {
        switch self {
        case .original:
            L10n.text("variant.original.title")
        case .compressed:
            L10n.text("variant.compressed.title")
        case .thumbnail:
            L10n.text("variant.thumbnail.title")
        case .webpReference:
            L10n.text("variant.webp.title")
        }
    }

    var detail: String {
        switch self {
        case .original:
            L10n.text("variant.original.detail")
        case .compressed:
            L10n.text("variant.compressed.detail")
        case .thumbnail:
            L10n.text("variant.thumbnail.detail")
        case .webpReference:
            L10n.text("variant.webp.detail")
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

extension ImageVariantKind {
    var copiedTitle: String {
        switch self {
        case .original:
            L10n.text("variant.original.copiedTitle")
        case .compressed:
            L10n.text("variant.compressed.copiedTitle")
        case .thumbnail:
            L10n.text("variant.thumbnail.copiedTitle")
        case .webpReference:
            L10n.text("variant.webp.copiedTitle")
        }
    }
}

struct GeneratedImageVariant: Identifiable, Sendable {
    let id = UUID()
    let kind: ImageVariantKind
    let filename: String
    let data: Data
    let contentType: String

    var byteCountText: String {
        ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file)
    }
}

struct UploadResult: Identifiable, Sendable {
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

struct UploadDashboardState: Equatable {
    var totalTasks = 0
    var completedTasks = 0
    var failedTasks = 0
    var activeTasks = 0
    var queuedTasks = 0
    var uploadedBytes = 0
    var startedAt: Date?

    static let idle = UploadDashboardState()

    var isActive: Bool {
        totalTasks > 0
    }

    var progress: Double {
        guard totalTasks > 0 else { return 0 }
        return Double(completedTasks + failedTasks) / Double(totalTasks)
    }

    var percentText: String {
        "\(Int((progress * 100).rounded()))%"
    }

    var speedText: String {
        guard let startedAt else { return ByteCountFormatter.string(fromByteCount: 0, countStyle: .file) + "/s" }
        let elapsed = max(Date().timeIntervalSince(startedAt), 0.5)
        let bytesPerSecond = Double(uploadedBytes) / elapsed
        return ByteCountFormatter.string(fromByteCount: Int64(bytesPerSecond), countStyle: .file) + "/s"
    }
}

enum PanelSection: String, CaseIterable, Identifiable {
    case workbench
    case links
    case history

    var id: String { rawValue }

    var title: String {
        switch self {
        case .workbench:
            L10n.text("section.workbench")
        case .links:
            L10n.text("section.links")
        case .history:
            L10n.text("section.history")
        }
    }

    var icon: String {
        switch self {
        case .workbench:
            "slider.horizontal.3"
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
            L10n.text("phase.idle")
        case .reading:
            L10n.text("phase.reading")
        case .preparing:
            L10n.text("phase.preparing")
        case .uploading(let current, let total):
            L10n.format("phase.uploading", current, total)
        case .copying:
            L10n.text("phase.copying")
        case .finished:
            L10n.text("phase.finished")
        case .failed:
            L10n.text("phase.failed")
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
