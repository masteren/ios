import Foundation

// サーバ(FastAPI)の JSON に対応するモデル。
// JSON は snake_case(original_price)なので、デコーダ側で camelCase に自動変換している(APIClient 参照)

struct Product: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    let description: String
    let emoji: String
    let imageUrl: String?      // 商品画像(/static/products/xxx.png)。空なら絵文字で代替
    let price: Int
    let originalPrice: Int
    var stock: Int
    let tag: String
    let isActive: Bool
}

struct CartItem: Codable, Identifiable {
    let id: Int
    let product: Product
    let quantity: Int
}

struct OrderItem: Codable, Hashable {
    let productName: String
    let unitPrice: Int
    let quantity: Int
}

struct Order: Codable, Identifiable {
    let id: Int
    let nickname: String
    let total: Int
    let paymentMethod: String
    let status: String
    let createdAt: String
    let items: [OrderItem]
}

struct TokenResponse: Codable {
    let username: String
    let accessToken: String
    let tokenType: String
    let expiresAt: String
}

struct MeResponse: Codable {
    let username: String
}

enum PaymentMethod: String, CaseIterable, Identifiable {
    case creditCard = "credit_card"
    case convenienceStore = "convenience_store"
    case paypay = "paypay"
    var id: String { rawValue }
    var label: String {
        switch self {
        case .creditCard: return "クレジット"
        case .convenienceStore: return "コンビニ"
        case .paypay: return "PayPay"
        }
    }
}

// MARK: - WebSocket で届くイベント

struct PurchaseItem: Codable, Hashable {
    let name: String
    let quantity: Int
}

struct HostReply {
    let id: String?            // あとから届く音声(hostAudio)と対応づける番号
    let nickname: String
    let text: String
    let productId: Int?
    let emotion: String
}

enum LiveEvent {
    case viewers(Int)
    case comment(nickname: String, text: String)
    case hostReply(HostReply)
    /// 発言の音声。文字(hostReply)より後に、合成が終わってから届く
    case hostAudio(id: String, audioUrl: String)
    case purchase(nickname: String, items: [PurchaseItem], stocks: [String: Int])
    case productsChanged
    case error(String)

    /// {"type": ...} を見て種類を判定する
    private struct Raw: Decodable {
        let type: String
        let id: String?
        let count: Int?
        let nickname: String?
        let text: String?
        let productId: Int?
        let emotion: String?
        let audioUrl: String?
        let items: [PurchaseItem]?
        let stocks: [String: Int]?
        let message: String?
    }

    static func decode(_ json: String) -> LiveEvent? {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        guard let data = json.data(using: .utf8), let r = try? d.decode(Raw.self, from: data) else { return nil }
        switch r.type {
        case "viewers": return .viewers(r.count ?? 0)
        case "comment": return .comment(nickname: r.nickname ?? "", text: r.text ?? "")
        case "host_reply":
            return .hostReply(HostReply(id: r.id, nickname: r.nickname ?? "", text: r.text ?? "", productId: r.productId,
                                        emotion: r.emotion ?? "normal"))
        case "host_audio":
            guard let id = r.id, let url = r.audioUrl else { return nil }
            return .hostAudio(id: id, audioUrl: url)
        case "purchase": return .purchase(nickname: r.nickname ?? "", items: r.items ?? [], stocks: r.stocks ?? [:])
        case "products_changed": return .productsChanged
        case "error": return .error(r.message ?? "エラーが発生しました")
        default: return nil
        }
    }
}

/// コメント欄の1行
struct ChatLine: Identifiable {
    enum Kind { case user, mine, host, system }
    let id = UUID()
    let nickname: String
    let text: String
    let kind: Kind
}
