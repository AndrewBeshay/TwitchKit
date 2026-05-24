import Foundation
import os
import Security

private let logger = Logger(subsystem: "com.twitchkit", category: "keychain")

enum KeychainError: Error {
    case saveFailed(OSStatus)
    case loadFailed(OSStatus)
}

enum KeychainStore {
    static func save(key: String, data: Data) throws {
        // Delete existing item first (update = delete + add)
        delete(key: key)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            logger.error("Keychain save failed for \(key): OSStatus \(status)")
            throw KeychainError.saveFailed(status)
        }
    }

    static func load(key: String) throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else {
            logger.error("Keychain load failed for \(key): OSStatus \(status)")
            throw KeychainError.loadFailed(status)
        }
        return result as? Data
    }

    static func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
        ]
        let status = SecItemDelete(query as CFDictionary)
        if status != errSecSuccess && status != errSecItemNotFound {
            logger.warning("Keychain delete for \(key) returned OSStatus \(status)")
        }
    }
}
