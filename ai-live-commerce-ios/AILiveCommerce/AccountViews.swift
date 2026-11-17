import SwiftUI

/// ログイン / 新規登録(シートで表示)
struct LoginView: View {
    @EnvironmentObject var state: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var isRegister = false
    @State private var username = ""
    @State private var password = ""
    @State private var error: String?
    @State private var busy = false

    /// パスワード欄。UI テストのときだけ普通の入力欄にする:
    /// 隠し入力欄(SecureField)には iOS のパスワード自動入力が付き、シミュレータでは XCUITest が
    /// 「アプリが静止するまで待つ」ところで止まり続けることがあった(アプリ自体は止まっていないことを診断ログで確認)。
    /// ふだんの利用では、これまでどおり隠し入力欄
    @ViewBuilder private var passwordField: some View {
        if AppConfig.isUITesting {
            TextField("パスワード(6文字以上)", text: $password)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        } else {
            SecureField("パスワード(6文字以上)", text: $password)
                .textContentType(.password)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Picker("", selection: $isRegister) {
                    Text("ログイン").tag(false)
                    Text("新規登録").tag(true)
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("authMode")
                Section {
                    TextField("ユーザー名(2〜20文字)", text: $username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .textContentType(AppConfig.isUITesting ? nil : .username)
                        .accessibilityIdentifier("usernameField")
                    // .newPassword だと「強力なパスワード」の自動入力が割り込み、入力内容が変わることがあるため .password に統一
                    passwordField
                        .accessibilityIdentifier("passwordField")
                }
                if let error {
                    Text(error).foregroundStyle(.red).font(.footnote)
                        .accessibilityIdentifier("authError")
                }
                Section {
                Button {
                    Task {
                        busy = true
                        error = await state.login(username: username, password: password, register: isRegister)
                        busy = false
                    }
                } label: {
                    if busy { ProgressView().frame(maxWidth: .infinity) }
                    else { Text(isRegister ? "登録して利用を開始" : "ログイン").bold().frame(maxWidth: .infinity) }
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .controlSize(.large)
                .disabled(busy || username.isEmpty || password.isEmpty)
                .accessibilityIdentifier("authSubmit")
                } footer: {
                    Text("コメントの投稿とお買い物にはログインが必要です。")
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }
            .tint(Theme.blue)
            .navigationTitle(isRegister ? "新規登録" : "ログイン")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("閉じる") { dismiss() } }
            }
        }
    }
}

/// アカウント:注文履歴・ログアウト・アプリの情報
struct AccountView: View {
    @EnvironmentObject var state: AppState

    private var appVersion: String {
        let info = Bundle.main.infoDictionary
        let v = info?["CFBundleShortVersionString"] as? String ?? "-"
        let b = info?["CFBundleVersion"] as? String ?? "-"
        return "\(v)(\(b))"
    }

    var body: some View {
        NavigationStack {
            List {
                Section("アカウント") {
                    if let name = state.username {
                        LabeledContent("ユーザー名", value: name)
                            .accessibilityIdentifier("accountUsername")
                        Button("ログアウト", role: .destructive) { Task { await state.logout() } }
                            .accessibilityIdentifier("logoutButton")
                    } else {
                        Button("ログイン / 新規登録") { state.showLogin = true }
                            .accessibilityIdentifier("openLogin")
                    }
                }
                if state.isLoggedIn {
                    Section("注文履歴") {
                        if state.orders.isEmpty {
                            Text("まだ注文はありません").foregroundStyle(.secondary)
                        }
                        ForEach(state.orders) { o in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text("#\(o.id)").bold()
                                    Spacer()
                                    Text(yen(o.total))
                                }
                                Text(o.items.map { "\($0.productName)×\($0.quantity)" }.joined(separator: "、"))
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                Section("このアプリについて") {
                    LabeledContent("バージョン", value: appVersion)
                    // 接続先サーバの設定は開発・デモの準備用。ふだんの画面に出さず、1段下の画面に置く
                    NavigationLink("開発者向け設定") { DeveloperSettingsView() }
                        .accessibilityIdentifier("developerSettings")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.stage)
            .navigationTitle("アカウント")
            .navigationBarTitleDisplayMode(.inline)
            .task(id: state.username) { await state.loadOrders() }
            .refreshable { await state.loadOrders() }
        }
    }
}


/// 開発者向け設定:接続先サーバ(開発用の Mac、テスト用サーバなど)を切り替える
struct DeveloperSettingsView: View {
    @EnvironmentObject var state: AppState
    @AppStorage(AppConfig.baseURLKey) private var baseURL = AppConfig.defaultBaseURL

    var body: some View {
        List {
            Section {
                TextField("http://127.0.0.1:8000", text: $baseURL)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Button("再接続") {
                    Task { await state.switchServer() }
                }
            } header: {
                Text("接続先サーバ")
            } footer: {
                Text("シミュレータは 127.0.0.1、実機は Mac の LAN の IP アドレスを指定します。ログインは接続先ごとに保存されます。")
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.stage)
        .navigationTitle("開発者向け設定")
        .navigationBarTitleDisplayMode(.inline)
    }
}
