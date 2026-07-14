import Foundation
import Security

@MainActor
protocol XomoFigmaCredentialStoring {
    func load() throws -> XomoFigmaPersonalAccessToken?
    func save(_ credential: XomoFigmaPersonalAccessToken) throws
    func delete() throws
}

@MainActor
final class XomoFigmaKeychainCredentialStore: XomoFigmaCredentialStoring {
    static let defaultService = "im.some.xomo.figma"
    static let defaultAccount = "personal-access-token"

    private let service: String
    private let account: String

    convenience init() {
        self.init(service: Self.defaultService, account: Self.defaultAccount)
    }

    init(service: String, account: String) {
        self.service = service
        self.account = account
    }

    func load() throws -> XomoFigmaPersonalAccessToken? {
        var query = baseQuery
        query[kSecReturnData] = kCFBooleanTrue
        query[kSecMatchLimit] = kSecMatchLimitOne
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess, let data = item as? Data,
              let value = String(data: data, encoding: .utf8)
        else {
            throw XomoFigmaCredentialStoreSystemError(status: status)
        }
        return try XomoFigmaPersonalAccessToken(validating: value)
    }

    func save(_ credential: XomoFigmaPersonalAccessToken) throws {
        let data = Data(credential.rawValue.utf8)
        let updateStatus = SecItemUpdate(
            baseQuery as CFDictionary,
            [kSecValueData: data] as CFDictionary
        )
        if updateStatus == errSecSuccess {
            return
        }
        guard updateStatus == errSecItemNotFound else {
            throw XomoFigmaCredentialStoreSystemError(status: updateStatus)
        }

        var attributes = baseQuery
        attributes[kSecValueData] = data
        attributes[kSecAttrAccessible] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        attributes[kSecAttrLabel] = "Xomo Figma Personal Access Token"
        let addStatus = SecItemAdd(attributes as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw XomoFigmaCredentialStoreSystemError(status: addStatus)
        }
    }

    func delete() throws {
        let status = SecItemDelete(baseQuery as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw XomoFigmaCredentialStoreSystemError(status: status)
        }
    }

    private var baseQuery: [CFString: Any] {
        [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecAttrSynchronizable: kCFBooleanFalse as Any
        ]
    }
}

private struct XomoFigmaCredentialStoreSystemError: Error {
    var status: OSStatus
}
