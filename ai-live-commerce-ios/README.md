# AI Live Commerce — iOS アプリ(SwiftUI)

Web 版と **同じ API** を使う iOS クライアントです(サーバ側の変更なし)。

| 画面 | 内容 |
|---|---|
| ライブ | ホストの表情(感情に応じて変化)と字幕、紹介中の商品、コメント欄、コメント送信、音声 ON/OFF |
| 商品 | 商品一覧。「質問する」でライブにコメントを送信、「カートへ」 |
| カート | 削除(スワイプ)、支払方法の選択、注文確定(モック決済) |
| アカウント | ログイン/新規登録、注文履歴、ログアウト、接続先サーバの設定 |

## 設計
- **認証**:`POST /api/auth/token` で Bearer トークンを取得し **Keychain** に保存(UserDefaults は暗号化されないため使わない)。REST と WebSocket の握手の両方で `Authorization: Bearer` を送る。Cookie は使わない(`URLSession(configuration: .ephemeral)`)ので CSRF 対策は不要。
- **リアルタイム**:`URLSessionWebSocketTask`。切断時は 2 秒後に自動再接続。
- **状態管理**:`AppState`(`ObservableObject`, `@MainActor`)にまとめ、各画面は `@EnvironmentObject` で参照。
- **iOS 17 以上**、外部ライブラリなし。

## 実行方法
1. サーバを起動(リポジトリのルートで):`uvicorn app.main:app --reload`
2. `ios/AILiveCommerce.xcodeproj` を Xcode で開き、iPhone シミュレータを選んで ▶︎(Run)
3. シミュレータからは `http://127.0.0.1:8000` で Mac 上のサーバに接続できる

### UI テスト(XCUITest)
サーバを起動した状態で、Xcode の ⌘U、またはコマンドで実行:
```bash
xcodebuild test -project ios/AILiveCommerce.xcodeproj -scheme AILiveCommerce \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro'
```
未ログインでコメント → ログインシート → 新規登録 → コメントが送信され AI ホストが回答 → カート追加 → 注文 → ライブで購入告知 → 注文履歴 → ログアウト、を実際にタップ・入力して確認します。起動引数 `--reset-session` で毎回未ログインから開始します。

サーバ側で VOICEVOX が動いているときは、`TEST_RUNNER_EXPECT_AUDIO=1` を付けると「ホストの音声が最後まで再生されたか」も確認します(音声ボタンの accessibilityValue に再生完了数を出している)。

### 実機で動かす場合
- サーバを `uvicorn app.main:app --host 0.0.0.0` で起動し、アプリの「アカウント → 接続先サーバ」に Mac の LAN の IP(例 `http://192.168.0.10:8000`)を入力
- Xcode の Signing & Capabilities で自分の Apple ID(Team)を選択

## 今後
- 3D アバター(VRM)の表示(SceneKit/RealityKit への VRM 読み込みが必要なため Ver1.0 では絵文字の表情で代替)
