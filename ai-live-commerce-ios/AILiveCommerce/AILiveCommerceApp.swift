import SwiftUI

@main
struct AILiveCommerceApp: App {
    @StateObject private var state = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(state)
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var state: AppState
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TabView(selection: $state.tab) {
            LiveView()
                .tabItem { Label("ライブ", systemImage: "dot.radiowaves.left.and.right") }
                .tag(AppState.Tab.live)
            ProductsView()
                .tabItem { Label("商品", systemImage: "bag") }
                .tag(AppState.Tab.products)
            CartView()
                .tabItem { Label("カート", systemImage: "cart") }
                .badge(state.cartCount)
                .tag(AppState.Tab.cart)
            AccountView()
                .tabItem { Label("アカウント", systemImage: "person.crop.circle") }
                .tag(AppState.Tab.account)
        }
        .tint(Theme.blue)
        .buttonBorderShape(.capsule)
        // 配色は Web 版と同じ明るい画面だけを用意しているので、端末がダークモードでも明るい表示に固定する
        .preferredColorScheme(.light)
        // 文字サイズは「特大」まで追従する。それ以上(アクセシビリティ用の大きさ)は横にはみ出して操作できなくなるため上限を設ける
        .dynamicTypeSize(...DynamicTypeSize.xxLarge)
        .sheet(isPresented: $state.showLogin) { LoginView() }
        .overlay(alignment: .top) {
            if let t = state.toast {
                Text(t)
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(.black.opacity(0.8), in: Capsule())
                    .padding(.top, 54)                // ナビゲーションバー(LIVE・視聴者数・音声ボタン)に重ならない位置
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .allowsHitTesting(false)          // お知らせの表示中も、下にあるボタンを押せるようにする
            }
        }
        .animation(.easeInOut, value: state.toast)
        .task { await state.bootstrap() }
        .onChange(of: scenePhase) { old, new in
            // バックグラウンドから戻ったら接続と表示を回復する(初回起動は bootstrap が担当)
            if new == .active, old == .background { Task { await state.becameActive() } }
        }
    }
}
