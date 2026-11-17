import SwiftUI

/// 商品一覧:Web 版の「商品の棚」と同じ大きなカード。カートに入れる / 花奈に質問する(ライブにコメント)
struct ProductsView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 16) {
                    TwoToneHeadline(lead: "本日の商品。", rest: "気になるものは、その場で花奈に聞いてみよう。")
                        .padding(.horizontal, 4).padding(.bottom, 4)
                    ForEach(state.products) { p in productCard(p) }
                    TwoToneHeadline(lead: "お買い物ガイド。", rest: "はじめてでも安心です。")
                        .padding(.horizontal, 4).padding(.top, 20).padding(.bottom, 4)
                    guideCard("shippingbox", "送料無料でお届け", "全国どこでも送料無料。ご注文から3〜5日ほどでお届けします。")
                    guideCard("arrow.uturn.backward.circle", "7日以内は返品OK", "未開封であれば、到着から7日以内の返品を承ります。")
                    guideCard("creditcard", "お支払い方法を選べる", "クレジットカード、コンビニ払い、PayPay からお選びいただけます。")
                }
                .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 24)
            }
            .background(Theme.stage)
            .navigationTitle("商品")
            .navigationBarTitleDisplayMode(.inline)
            .refreshable { await state.loadProducts() }
        }
    }

    private func productCard(_ p: Product) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if !p.tag.isEmpty {
                Text(p.tag).font(.caption.weight(.semibold)).foregroundStyle(Theme.accent)
            }
            Text(p.name).font(.title2.weight(.semibold))
            Text(p.description).font(.subheadline).foregroundStyle(.secondary)
            ProductThumb(product: p, size: 190)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(yen(p.price)).font(.title3.weight(.semibold))
                if p.originalPrice > p.price {
                    Text(yen(p.originalPrice)).font(.subheadline).strikethrough().foregroundStyle(.secondary)
                }
                if let off = offText(p) { Text(off).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.accent) }
                Spacer()
                Text(p.stock > 0 ? "残り\(p.stock)点" : "在庫切れ").font(.caption).foregroundStyle(.secondary)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.7)                            // 文字を大きくしている端末でも金額を折り返さない
            HStack(spacing: 18) {
                Button(p.stock > 0 ? "カートに入れる" : "在庫切れ") { Task { await state.addToCart(p) } }
                    .buttonStyle(.borderedProminent)
                    .disabled(p.stock <= 0)
                Button { Task { await state.ask(about: p) } } label: {
                    Text("花奈に質問する ›")
                }
            }
            .font(.subheadline)
            .padding(.top, 6)
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(radius: Theme.radiusLarge)
    }

    private func guideCard(_ icon: String, _ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon).font(.title).foregroundStyle(Theme.brand)
            Text(title).font(.title3.weight(.semibold))
            Text(body).font(.subheadline).foregroundStyle(.secondary)
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(radius: Theme.radiusLarge)
    }
}

/// カート → 支払方法の選択 → 注文確定(決済はモック)
struct CartView: View {
    @EnvironmentObject var state: AppState
    @State private var method: PaymentMethod = .creditCard
    @State private var processing = false
    @State private var resultMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if !state.isLoggedIn {
                    ContentUnavailableView {
                        Label("ログインが必要です", systemImage: "person.crop.circle.badge.exclamationmark")
                    } actions: {
                        Button("ログイン") { state.showLogin = true }.buttonStyle(.borderedProminent)
                    }
                } else if state.cart.isEmpty {
                    ContentUnavailableView {
                        Label("カートは空です", systemImage: "cart")
                    } description: {
                        Text("気になる商品を、ライブや商品一覧から追加できます。")
                    } actions: {
                        Button("商品を見る") { state.tab = .products }.buttonStyle(.borderedProminent)
                    }
                } else {
                    cartList
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.stage)
            .navigationTitle("カート")
            .navigationBarTitleDisplayMode(.inline)
            .task { await state.refreshCart() }
            .alert("お知らせ", isPresented: Binding(get: { resultMessage != nil }, set: { if !$0 { resultMessage = nil } })) {
                Button("OK") {}
            } message: {
                Text(resultMessage ?? "")
            }
        }
    }

    private var cartList: some View {
        List {
            Section {
                ForEach(state.cart) { item in
                    HStack {
                        ProductThumb(product: item.product, size: 36)
                        Text(item.product.name).lineLimit(1)
                        Spacer()
                        Text("×\(item.quantity)").foregroundStyle(.secondary)
                        Text(yen(item.product.price * item.quantity))
                    }
                }
                .onDelete { idx in
                    let items = idx.map { state.cart[$0] }
                    Task { for i in items { await state.removeFromCart(i) } }
                }
            } footer: {
                Text("左にスワイプで削除")
            }
            Section("お支払い方法") {
                Picker("お支払い方法", selection: $method) {
                    ForEach(PaymentMethod.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                Text("※デモのため実際の決済は行われません").font(.caption).foregroundStyle(.secondary)
            }
            Section {
                HStack {
                    Text("合計(送料無料)")
                    Spacer()
                    Text(yen(state.cartTotal)).font(.title3.bold())
                }
                Button {
                    Task { await placeOrder() }
                } label: {
                    if processing { ProgressView().frame(maxWidth: .infinity) }
                    else { Text("注文を確定する").bold().frame(maxWidth: .infinity) }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(processing)
                .accessibilityIdentifier("checkoutButton")
            }
        }
    }

    private func placeOrder() async {
        processing = true
        defer { processing = false }
        switch await state.checkout(method: method) {
        case .success(let order):
            resultMessage = "ご注文ありがとうございます\n注文番号 #\(order.id) / \(yen(order.total))"
        case .failure(let e):
            resultMessage = "決済に失敗しました\n\(e.message)"
        }
    }
}
