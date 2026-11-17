import Foundation

struct APIError: LocalizedError {
    let status: Int
    let message: String
    var errorDescription: String? { message }
}

/// REST API クライアント(async/await)
/// - 認証は `Authorization: Bearer <token>`(Cookie は使わない → ephemeral セッション)
/// - Bearer はブラウザが自動送信しないので CSRF 対策は不要(サーバ側もそう判定する)
final class APIClient {
    static let shared = APIClient()

    /// トークン付きのリクエストが 401 で拒否されたとき(期限切れ・他でログアウト)に呼ばれる
    var onUnauthorized: (@MainActor () -> Void)?

    private let session = URLSession(configuration: .ephemeral)
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()

    // MARK: 認証
    func register(username: String, password: String) async throws -> TokenResponse {
        // サーバの /register は Web 用(Cookie を返す)なので、登録後に /token で Bearer を取得する
        let _: MeResponse = try await request("POST", "/api/auth/register",
                                              body: ["username": username, "password": password], auth: false)
        return try await login(username: username, password: password)
    }

    func login(username: String, password: String) async throws -> TokenResponse {
        let res: TokenResponse = try await request("POST", "/api/auth/token",
                                                   body: ["username": username, "password": password], auth: false)
        Keychain.save(res.accessToken)
        return res
    }

    func me() async throws -> MeResponse { try await request("GET", "/api/auth/me") }

    func logout() async {
        _ = try? await send("POST", "/api/auth/logout", body: nil, auth: true)
        Keychain.delete()
    }

    // MARK: 商品・カート・注文
    func products() async throws -> [Product] { try await request("GET", "/api/products", auth: false) }
    func cart() async throws -> [CartItem] { try await request("GET", "/api/cart") }

    func addToCart(productId: Int, quantity: Int = 1) async throws -> [CartItem] {
        try await request("POST", "/api/cart", body: ["product_id": productId, "quantity": quantity])
    }

    func removeCartItem(id: Int) async throws {
        _ = try await send("DELETE", "/api/cart/\(id)", body: nil, auth: true)
    }

    func checkout(method: PaymentMethod) async throws -> Order {
        try await request("POST", "/api/orders/checkout", body: ["payment_method": method.rawValue])
    }

    func orders() async throws -> [Order] { try await request("GET", "/api/orders") }

    // MARK: 共通処理
    private func request<T: Decodable>(_ method: String, _ path: String,
                                       body: [String: Any]? = nil, auth: Bool = true) async throws -> T {
        let data = try await send(method, path, body: body, auth: auth)
        return try decoder.decode(T.self, from: data)
    }

    private func send(_ method: String, _ path: String, body: [String: Any]?, auth: Bool) async throws -> Data {
        var req = URLRequest(url: AppConfig.baseURL.appendingPathComponent(path))
        req.httpMethod = method
        req.timeoutInterval = 15
        if let body {
            req.httpBody = try JSONSerialization.data(withJSONObject: body)
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        var sentToken = false
        if auth, let token = Keychain.load() {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            sentToken = true
        }
        let (data, res) = try await session.data(for: req)
        let status = (res as? HTTPURLResponse)?.statusCode ?? 0
        if status == 401, sentToken, let handler = onUnauthorized { await handler() }
        guard (200..<300).contains(status) else {
            throw APIError(status: status, message: Self.errorMessage(from: data, status: status))
        }
        return data
    }

    /// サーバのエラー形式:{"detail": "日本語のメッセージ"}(入力チェックのエラーもサーバ側で1文にしている)
    private static func errorMessage(from data: Data, status: Int) -> String {
        if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let s = obj["detail"] as? String { return s }
        }
        return "通信エラー(\(status))"
    }
}
