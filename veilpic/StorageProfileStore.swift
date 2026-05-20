//
//  StorageProfileStore.swift
//  veilpic
//
//  Created by Codex on 2026/5/20.
//

import Foundation
import Security

protocol StorageProfileStoring {
    func load() -> StorageProfile
    func save(_ profile: StorageProfile)
}

final class StorageProfileStore: StorageProfileStoring {
    private let defaultsKey = "veilpic.storageProfile.v1"
    private let secretAccount = "storage.accessKeySecret"
    private let sessionTokenAccount = "storage.sessionToken"
    private let keychain = KeychainCredentialStore(service: "com.veilpic.storage")

    func load() -> StorageProfile {
        var profile = StorageProfile()

        if let data = UserDefaults.standard.data(forKey: defaultsKey),
           let snapshot = try? JSONDecoder().decode(StorageProfileSnapshot.self, from: data) {
            profile.provider = snapshot.provider
            profile.credentialMode = snapshot.credentialMode ?? .longTerm
            profile.accessKeyId = snapshot.accessKeyId
            profile.bucket = snapshot.bucket
            profile.region = snapshot.region
            profile.endpoint = snapshot.endpoint
            profile.cdnDomain = snapshot.cdnDomain
            profile.objectPrefix = snapshot.objectPrefix
        }

        profile.accessKeySecret = keychain.read(account: secretAccount) ?? ""
        profile.sessionToken = keychain.read(account: sessionTokenAccount) ?? ""
        return profile
    }

    func save(_ profile: StorageProfile) {
        let snapshot = StorageProfileSnapshot(profile: profile)
        if let data = try? JSONEncoder().encode(snapshot) {
            UserDefaults.standard.set(data, forKey: defaultsKey)
        }

        keychain.save(profile.accessKeySecret, account: secretAccount)
        keychain.save(profile.sessionToken, account: sessionTokenAccount)
    }
}

private struct StorageProfileSnapshot: Codable {
    let provider: StorageProviderKind
    let credentialMode: StorageCredentialMode?
    let accessKeyId: String
    let bucket: String
    let region: String
    let endpoint: String
    let cdnDomain: String
    let objectPrefix: String

    init(profile: StorageProfile) {
        provider = profile.provider
        credentialMode = profile.credentialMode
        accessKeyId = profile.accessKeyId
        bucket = profile.bucket
        region = profile.region
        endpoint = profile.endpoint
        cdnDomain = profile.cdnDomain
        objectPrefix = profile.objectPrefix
    }
}

private final class KeychainCredentialStore {
    private let service: String

    init(service: String) {
        self.service = service
    }

    func read(account: String) -> String? {
        var query = baseQuery(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data
        else {
            return nil
        }

        return String(data: data, encoding: .utf8)
    }

    func save(_ value: String, account: String) {
        guard !value.isEmpty, let data = value.data(using: .utf8) else {
            delete(account: account)
            return
        }

        let query = baseQuery(account: account)
        let attributes = [kSecValueData as String: data]
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)

        if status == errSecItemNotFound {
            var item = query
            item[kSecValueData as String] = data
            SecItemAdd(item as CFDictionary, nil)
        }
    }

    private func delete(account: String) {
        SecItemDelete(baseQuery(account: account) as CFDictionary)
    }

    private func baseQuery(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}
