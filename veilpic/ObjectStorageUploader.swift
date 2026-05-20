//
//  ObjectStorageUploader.swift
//  veilpic
//
//  Created by Codex on 2026/5/19.
//

import CryptoKit
import Foundation

enum UploadError: LocalizedError {
    case missingField(String)
    case invalidEndpoint(String)
    case invalidResponse
    case uploadFailed(statusCode: Int, body: String)

    var errorDescription: String? {
        switch self {
        case .missingField(let name):
            return "缺少配置：\(name)"
        case .invalidEndpoint(let endpoint):
            return "Endpoint 无效：\(endpoint)"
        case .invalidResponse:
            return "上传响应无效"
        case .uploadFailed(let statusCode, let body):
            return "上传失败 HTTP \(statusCode)：\(body)"
        }
    }
}

struct ObjectStorageUploader: ImageUploading {
    func upload(_ variants: [GeneratedImageVariant], profile: StorageProfile) async throws -> UploadResult {
        try profile.validateForUpload()

        let uploadedAt = Date()
        let prefix = profile.normalizedObjectPrefix(date: uploadedAt)
        var links: [ImageVariantKind: URL] = [:]

        for variant in variants {
            let objectKey = "\(prefix)/\(variant.filename)"
            try await upload(variant, objectKey: objectKey, profile: profile)
            links[variant.kind] = try profile.publicURL(for: objectKey)
        }

        return UploadResult(
            sourceName: profile.provider.title,
            createdAt: uploadedAt,
            links: links
        )
    }

    private func upload(_ variant: GeneratedImageVariant, objectKey: String, profile: StorageProfile) async throws {
        var request = try request(for: variant, objectKey: objectKey, profile: profile)
        request.httpMethod = "PUT"
        request.httpBody = variant.data
        request.timeoutInterval = 90

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw UploadError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw UploadError.uploadFailed(statusCode: httpResponse.statusCode, body: body)
        }
    }

    private func request(for variant: GeneratedImageVariant, objectKey: String, profile: StorageProfile) throws -> URLRequest {
        switch profile.provider {
        case .aliyunOSS:
            return try AliyunOSSRequestSigner().signedPutRequest(variant: variant, objectKey: objectKey, profile: profile)
        case .tencentCOS:
            return try TencentCOSRequestSigner().signedPutRequest(variant: variant, objectKey: objectKey, profile: profile)
        case .amazonS3, .cloudflareR2, .customS3:
            return try S3V4RequestSigner().signedPutRequest(variant: variant, objectKey: objectKey, profile: profile)
        case .qiniuKodo:
            return try QiniuKodoRequestBuilder().uploadRequest(variant: variant, objectKey: objectKey, profile: profile)
        }
    }
}

struct S3V4RequestSigner {
    func signedPutRequest(variant: GeneratedImageVariant, objectKey: String, profile: StorageProfile) throws -> URLRequest {
        let now = Date()
        let endpoint = try profile.endpointURL()
        let url = try profile.objectAPIURL(for: objectKey)
        let payloadHash = SHA256.hash(data: variant.data).hexString
        let amzDate = DateFormatter.awsDate.string(from: now)
        let credentialDate = DateFormatter.awsCredentialDate.string(from: now)
        let region = profile.region.isEmpty ? "auto" : profile.region
        let service = "s3"
        let scope = "\(credentialDate)/\(region)/\(service)/aws4_request"
        let canonicalURI = URLComponents(url: url, resolvingAgainstBaseURL: false)?.percentEncodedPath ?? "/"
        let canonicalHeaders = [
            "content-type:\(variant.contentType)",
            "host:\(endpoint.host ?? "")",
            "x-amz-content-sha256:\(payloadHash)",
            "x-amz-date:\(amzDate)"
        ].joined(separator: "\n") + "\n"
        let signedHeaders = "content-type;host;x-amz-content-sha256;x-amz-date"
        let canonicalRequest = [
            "PUT",
            canonicalURI,
            "",
            canonicalHeaders,
            signedHeaders,
            payloadHash
        ].joined(separator: "\n")
        let stringToSign = [
            "AWS4-HMAC-SHA256",
            amzDate,
            scope,
            SHA256.hash(data: Data(canonicalRequest.utf8)).hexString
        ].joined(separator: "\n")
        let signingKey = signingKey(secret: profile.accessKeySecret, date: credentialDate, region: region, service: service)
        let signature = HMAC<SHA256>.authenticationCode(for: Data(stringToSign.utf8), using: signingKey).hexString
        let authorization = "AWS4-HMAC-SHA256 Credential=\(profile.accessKeyId)/\(scope), SignedHeaders=\(signedHeaders), Signature=\(signature)"

        var request = URLRequest(url: url)
        request.setValue(variant.contentType, forHTTPHeaderField: "Content-Type")
        request.setValue(payloadHash, forHTTPHeaderField: "x-amz-content-sha256")
        request.setValue(amzDate, forHTTPHeaderField: "x-amz-date")
        request.setValue(authorization, forHTTPHeaderField: "Authorization")
        return request
    }

    private func signingKey(secret: String, date: String, region: String, service: String) -> SymmetricKey {
        let dateKey = hmacSHA256(key: Data("AWS4\(secret)".utf8), message: date)
        let dateRegionKey = hmacSHA256(key: dateKey, message: region)
        let dateRegionServiceKey = hmacSHA256(key: dateRegionKey, message: service)
        let signingKey = hmacSHA256(key: dateRegionServiceKey, message: "aws4_request")
        return SymmetricKey(data: signingKey)
    }

    private func hmacSHA256(key: Data, message: String) -> Data {
        let code = HMAC<SHA256>.authenticationCode(for: Data(message.utf8), using: SymmetricKey(data: key))
        return Data(code)
    }
}

struct AliyunOSSRequestSigner {
    func signedPutRequest(variant: GeneratedImageVariant, objectKey: String, profile: StorageProfile) throws -> URLRequest {
        let url = try profile.objectAPIURL(for: objectKey)
        let date = DateFormatter.httpDate.string(from: Date())
        let canonicalResource = "/\(profile.bucket)/\(objectKey)"
        let stringToSign = [
            "PUT",
            "",
            variant.contentType,
            date,
            canonicalResource
        ].joined(separator: "\n")
        let signature = HMAC<Insecure.SHA1>.authenticationCode(
            for: Data(stringToSign.utf8),
            using: SymmetricKey(data: Data(profile.accessKeySecret.utf8))
        ).base64String

        var request = URLRequest(url: url)
        request.setValue(date, forHTTPHeaderField: "Date")
        request.setValue(variant.contentType, forHTTPHeaderField: "Content-Type")
        request.setValue("OSS \(profile.accessKeyId):\(signature)", forHTTPHeaderField: "Authorization")
        return request
    }
}

struct TencentCOSRequestSigner {
    func signedPutRequest(variant: GeneratedImageVariant, objectKey: String, profile: StorageProfile) throws -> URLRequest {
        let url = try profile.objectAPIURL(for: objectKey)
        let host = try profile.endpointURL().host ?? ""
        let now = Int(Date().timeIntervalSince1970)
        let keyTime = "\(now);\(now + 900)"
        let headerList = "content-type;host"
        let httpString = [
            "put",
            "/" + objectKey.urlPathEncoded,
            "",
            "content-type=\(variant.contentType.urlQueryEncoded)&host=\(host.urlQueryEncoded)",
            ""
        ].joined(separator: "\n")
        let stringToSign = [
            "sha1",
            keyTime,
            Insecure.SHA1.hash(data: Data(httpString.utf8)).hexString,
            ""
        ].joined(separator: "\n")
        let signKey = HMAC<Insecure.SHA1>.authenticationCode(
            for: Data(keyTime.utf8),
            using: SymmetricKey(data: Data(profile.accessKeySecret.utf8))
        )
        let signature = HMAC<Insecure.SHA1>.authenticationCode(
            for: Data(stringToSign.utf8),
            using: SymmetricKey(data: Data(signKey))
        ).hexString
        let authorization = [
            "q-sign-algorithm=sha1",
            "q-ak=\(profile.accessKeyId)",
            "q-sign-time=\(keyTime)",
            "q-key-time=\(keyTime)",
            "q-header-list=\(headerList)",
            "q-url-param-list=",
            "q-signature=\(signature)"
        ].joined(separator: "&")

        var request = URLRequest(url: url)
        request.setValue(variant.contentType, forHTTPHeaderField: "Content-Type")
        request.setValue(authorization, forHTTPHeaderField: "Authorization")
        return request
    }
}

struct QiniuKodoRequestBuilder {
    func uploadRequest(variant: GeneratedImageVariant, objectKey: String, profile: StorageProfile) throws -> URLRequest {
        let endpoint = try profile.endpointURL()
        let uploadURL = endpoint.appending(path: "/")
        let token = uploadToken(objectKey: objectKey, profile: profile)
        let boundary = "VeilPicBoundary\(UUID().uuidString.replacingOccurrences(of: "-", with: ""))"

        var body = Data()
        body.appendMultipartField(name: "token", value: token, boundary: boundary)
        body.appendMultipartField(name: "key", value: objectKey, boundary: boundary)
        body.appendMultipartFile(
            name: "file",
            filename: variant.filename,
            contentType: variant.contentType,
            data: variant.data,
            boundary: boundary
        )
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        var request = URLRequest(url: uploadURL)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        return request
    }

    private func uploadToken(objectKey: String, profile: StorageProfile) -> String {
        let deadline = Int(Date().addingTimeInterval(3600).timeIntervalSince1970)
        let policy = #"{"scope":"\#(profile.bucket):\#(objectKey)","deadline":\#(deadline)}"#
        let encodedPolicy = Data(policy.utf8).base64URLEncodedString
        let signature = HMAC<Insecure.SHA1>.authenticationCode(
            for: Data(encodedPolicy.utf8),
            using: SymmetricKey(data: Data(profile.accessKeySecret.utf8))
        )
        let encodedSignature = Data(signature).base64URLEncodedString
        return "\(profile.accessKeyId):\(encodedSignature):\(encodedPolicy)"
    }
}

extension StorageProfile {
    func validateForUpload() throws {
        if accessKeyId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw UploadError.missingField("Access Key ID")
        }

        if accessKeySecret.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw UploadError.missingField("Access Key Secret")
        }

        if bucket.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, provider != .customS3 {
            throw UploadError.missingField("Bucket")
        }

        if endpoint.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw UploadError.missingField("Endpoint / API 域名")
        }

        if provider == .qiniuKodo, cdnDomain.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw UploadError.missingField("七牛云 Kodo 的 CDN 域名")
        }
    }

    func endpointURL() throws -> URL {
        let raw = endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = raw.hasPrefix("http://") || raw.hasPrefix("https://") ? raw : "https://\(raw)"
        guard let url = URL(string: normalized), url.host != nil else {
            throw UploadError.invalidEndpoint(endpoint)
        }

        return url
    }

    func objectAPIURL(for objectKey: String) throws -> URL {
        let endpoint = try endpointURL()
        let path = objectAPIPath(for: objectKey)
        guard var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false) else {
            throw UploadError.invalidEndpoint(self.endpoint)
        }

        components.percentEncodedPath = path
        guard let url = components.url else {
            throw UploadError.invalidEndpoint(self.endpoint)
        }

        return url
    }

    func publicURL(for objectKey: String) throws -> URL {
        let base = try publicBaseURL()
        guard var components = URLComponents(url: base, resolvingAgainstBaseURL: false) else {
            throw UploadError.invalidEndpoint(cdnDomain.isEmpty ? endpoint : cdnDomain)
        }

        let hasCDN = !cdnDomain.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        if hasCDN {
            components.percentEncodedPath = "/" + objectKey.urlPathEncoded
        } else {
            components.percentEncodedPath = objectAPIPath(for: objectKey)
        }

        guard let url = components.url else {
            throw UploadError.invalidEndpoint(cdnDomain.isEmpty ? endpoint : cdnDomain)
        }

        return url
    }

    func normalizedObjectPrefix(date: Date) -> String {
        let configured = objectPrefix.trimmingCharacters(in: CharacterSet(charactersIn: "/ \n\t"))
        let datePrefix = DateFormatter.objectKeyDate.string(from: date)

        if configured.isEmpty {
            return datePrefix
        }

        return "\(configured)/\(datePrefix)"
    }

    private func publicBaseURL() throws -> URL {
        let rawDomain = cdnDomain.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? endpoint : cdnDomain
        let normalized = rawDomain.hasPrefix("http://") || rawDomain.hasPrefix("https://") ? rawDomain : "https://\(rawDomain)"
        guard let url = URL(string: normalized), url.host != nil else {
            throw UploadError.invalidEndpoint(rawDomain)
        }

        return url
    }

    private func objectAPIPath(for objectKey: String) -> String {
        switch provider {
        case .aliyunOSS, .tencentCOS:
            return "/" + objectKey.urlPathEncoded
        case .qiniuKodo:
            return "/" + objectKey.urlPathEncoded
        case .amazonS3, .cloudflareR2, .customS3:
            if bucket.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return "/" + objectKey.urlPathEncoded
            }

            return "/" + bucket.urlPathEncoded + "/" + objectKey.urlPathEncoded
        }
    }
}

private extension String {
    var urlPathEncoded: String {
        let allowed = CharacterSet.urlPathAllowed.subtracting(CharacterSet(charactersIn: "?#[]@!$&'()*+,;="))
        return addingPercentEncoding(withAllowedCharacters: allowed) ?? self
    }

    var urlQueryEncoded: String {
        let allowed = CharacterSet.urlQueryAllowed.subtracting(CharacterSet(charactersIn: ":#[]@!$&'()*+,;="))
        return addingPercentEncoding(withAllowedCharacters: allowed) ?? self
    }
}

private extension Data {
    var base64URLEncodedString: String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    mutating func appendMultipartField(name: String, value: String, boundary: String) {
        append("--\(boundary)\r\n".data(using: .utf8)!)
        append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
        append("\(value)\r\n".data(using: .utf8)!)
    }

    mutating func appendMultipartFile(name: String, filename: String, contentType: String, data: Data, boundary: String) {
        append("--\(boundary)\r\n".data(using: .utf8)!)
        append("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        append("Content-Type: \(contentType)\r\n\r\n".data(using: .utf8)!)
        append(data)
        append("\r\n".data(using: .utf8)!)
    }
}

private extension Sequence where Element == UInt8 {
    var hexString: String {
        map { String(format: "%02x", $0) }.joined()
    }

    var base64String: String {
        Data(self).base64EncodedString()
    }
}

private extension DateFormatter {
    static let awsDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        return formatter
    }()

    static let awsCredentialDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyyMMdd"
        return formatter
    }()

    static let httpDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss 'GMT'"
        return formatter
    }()
}
