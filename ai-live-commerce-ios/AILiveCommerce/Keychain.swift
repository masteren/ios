import Foundation
import Security

/// ログイントークンを Keychain に保存する。
/// UserDefaults は暗号化されないファイルなので、秘密情報(トークン・パスワード)は Keychain に置くのが iOS の作法。
/// (Web 版で localStorage をやめて HttpOnly Cookie にしたのと同じ考え方)
///
/// トークンは「接続先サーバごと」に保存する。トークンは発行したサーバでしか通用しないので、
/// 接続先を切り替えても(開発用 ↔ テスト用など)、元のサーバのログインが消えないようにするため。
enum Keychain {
    private static let service = "jp.portfolio.AILiveCommerce"
    private static var account: String { "accessToken@" + AppConfig.baseURL.absoluteString }

    private static func query(_ account: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: account]
    }
    private static var baseQuery: [String: Any] { query(account) }

    static func save(_ token: String) {
        delete()
        var q = baseQuery
        q[kSecValueData as String] = Data(token.utf8)
        q[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(q as CFDictionary, nil)
    }

    static func load() -> String? { read(baseQuery) }

    private static func read(_ base: [String: Any]) -> String? {
        var q = base
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var out: AnyObject?
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess,
              let data = out as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete() {
        SecItemDelete(baseQuery as CFDictionary)
    }
}
