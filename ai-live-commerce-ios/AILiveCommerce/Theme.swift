import SwiftUI
import UIKit

/// Web 版(app/static/index.html の :root)と同じ色
enum Theme {
    static let ink = Color(red: 0.114, green: 0.114, blue: 0.122)      // #1D1D1F 文字
    static let blue = Color(red: 0.0, green: 0.443, blue: 0.890)       // #0071E3 ボタン
    static let brand = Color(red: 0.518, green: 0.075, blue: 0.247)    // #84133F 見出し
    static let accent = Color(red: 0.749, green: 0.282, blue: 0.0)     // #BF4800 タグ・割引
    static let live = Color(red: 0.890, green: 0.0, blue: 0.0)         // #E30000 LIVE の点
    static let stage = Color(red: 0.961, green: 0.961, blue: 0.969)    // #F5F5F7 背景
    static let stageDeep = Color(red: 0.914, green: 0.914, blue: 0.929) // ステージのグラデーションの下側
    static let radiusLarge: CGFloat = 28                                // Web 版の --r-lg
    static let radiusCard: CGFloat = 20
    static let line = Color(red: 0.910, green: 0.910, blue: 0.929)     // #E8E8ED 罫線
    static let thumb = Color(red: 0.961, green: 0.961, blue: 0.969)
    /// 画面に出すホストの名前(Web 版と同じ表記)
    static let hostDisplayName = "花奈"
}

extension View {
    /// 白い角丸カード(Web 版の商品カード・コメント欄と同じ見た目)
    func card(radius: CGFloat = Theme.radiusCard) -> some View {
        background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: radius, style: .continuous))
    }
}

/// 2色の大見出し(Web 版の「<b>お買い物ガイド。</b>はじめてでも安心です。」と同じ:前半が濃い色、後半がグレー)
struct TwoToneHeadline: View {
    let lead: String
    let rest: String
    var body: some View {
        (Text(lead).foregroundColor(Theme.brand) + Text(rest).foregroundColor(Color(.secondaryLabel)))
            .font(.system(size: 26, weight: .semibold))
            .lineSpacing(2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
    }
}

/// 商品画像(サーバの image_url を読み込む。無い・失敗した場合は絵文字で代替)
struct ProductThumb: View {
    let product: Product
    let size: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.2).fill(Theme.thumb)
            if let path = product.imageUrl, !path.isEmpty, let url = AppConfig.absolute(path) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFit()
                    } else if phase.error != nil {
                        Text(product.emoji).font(.system(size: size * 0.45))
                    } else {
                        ProgressView().controlSize(.small)
                    }
                }
            } else {
                Text(product.emoji).font(.system(size: size * 0.45))
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.2))
        .accessibilityHidden(true)
    }
}

/// ホストの立ち絵(感情ごとの画像を切り替える)
struct HostPortrait: View {
    let emotion: String
    /// true のとき(キーボード表示中):顔のあたりだけを切り出して見せる
    var compact = false

    var body: some View {
        let image = UIImage(named: "hana_\(emotion)") ?? UIImage(named: "hana_normal")
        Group {
            if let image {
                // 上半身を大きめに見せる(下は字幕に隠れるので切ってよい)。キーボード表示中は顔のあたりだけ
                Color.clear.overlay(alignment: .top) {
                    Image(uiImage: image).resizable().scaledToFit().frame(height: compact ? 190 : 340)
                }
            } else {
                Image(systemName: "person.fill").resizable().scaledToFit().foregroundStyle(.secondary).padding(40)
            }
        }
        .frame(maxWidth: .infinity)
        .clipped()
        .animation(.easeInOut(duration: 0.2), value: emotion)
        .accessibilityLabel("AIアシスタント 花奈")
    }
}
