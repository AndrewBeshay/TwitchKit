import Foundation
import os
import Security

private let logger = Logger(subsystem: "com.twitchkit", category: "keychain")

enum KeychainError: Error {
    case saveFailed(OSStatus)
    case loadFailed(OSStatus)
}

enum KeychainStore {
    /// Service attribute scoping TwitchKit's keychain items. Without it,
    /// items are only distinguished by account, so any other code writing
    /// generic passwords with the same account string would collide.
    private static let service = "com.twitchkit.oauth-tokens"

    /// Base query matching TwitchKit's item for `key`. `scopedToService`
    /// false yields the legacy shape (no `kSecAttrService`) used by items
    /// written before the service attribute was introduced.
    private static func query(key: String, scopedToService: Bool = true) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
        ]
        if scopedToService {
            query[kSecAttrService as String] = service
        }
        #if os(macOS)
        query[kSecUseDataProtectionKeychain as String] = true
        #endif
        return query
    }

    static func save(key: String, data: Data) throws {
        // Update-then-add, service-scoped. A legacy (no-service) item is
        // deliberately NOT updated here: load(key:) migrates it on first
        // read, and a fresh save while an unmigrated legacy item still
        // exists just creates the service-scoped item alongside it — the
        // legacy copy becomes unreachable garbage that delete(key:)'s
        // legacy pass removes.
        let query = Self.query(key: key)

        let attributes: [String: Any] = [
            kSecValueData as String: data,
        ]

        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecSuccess {
            return
        }

        guard status == errSecItemNotFound else {
            logger.error("Keychain save failed for \(key): OSStatus \(status)")
            throw KeychainError.saveFailed(status)
        }

        var addQuery = query
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            logger.error("Keychain add failed for \(key): OSStatus \(addStatus)")
            throw KeychainError.saveFailed(addStatus)
        }
    }

    static func load(key: String) throws -> Data? {
        if let data = try copyData(matching: query(key: key), key: key) {
            return data
        }

        // Legacy fallback: items written before the service attribute
        // existed carry no kSecAttrService, so the scoped query above
        // misses them. A query without kSecAttrService also matches items
        // that HAVE a service — harmless here, because this path only runs
        // when the service-scoped query already found nothing.
        let legacyQuery = query(key: key, scopedToService: false)
        guard let legacyData = try copyData(matching: legacyQuery, key: key) else {
            return nil
        }

        // Migrate the legacy item in place so future loads hit the
        // service-scoped query directly. A failed migration is only logged:
        // the data was read successfully and the fallback keeps working.
        let migrationAttributes: [String: Any] = [
            kSecAttrService as String: service,
        ]
        let migrationStatus = SecItemUpdate(legacyQuery as CFDictionary, migrationAttributes as CFDictionary)
        if migrationStatus != errSecSuccess {
            logger.warning("Keychain service migration for \(key) returned OSStatus \(migrationStatus)")
        }
        return legacyData
    }

    static func delete(key: String) {
        // Delete both the service-scoped item and any legacy no-service
        // item, so logout can never leave a stale legacy token behind.
        delete(query: query(key: key), key: key)
        delete(query: query(key: key, scopedToService: false), key: key)
    }

    private static func copyData(matching query: [String: Any], key: String) throws -> Data? {
        var query = query
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else {
            logger.error("Keychain load failed for \(key): OSStatus \(status)")
            throw KeychainError.loadFailed(status)
        }
        return result as? Data
    }

    private static func delete(query: [String: Any], key: String) {
        let status = SecItemDelete(query as CFDictionary)
        if status != errSecSuccess && status != errSecItemNotFound {
            logger.warning("Keychain delete for \(key) returned OSStatus \(status)")
        }
    }
}
