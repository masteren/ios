import XCTest

/// iOS アプリの主要フローを実際にタップ・入力して確認する UI テスト
/// 前提:Mac 上でサーバ(http://127.0.0.1:8000)が起動していること。他の視聴者(開いたままのブラウザなど)がいると視聴者数の確認で失敗するので、
/// テスト用サーバを別ポートで起動して API_BASE で指定するのが確実
///   未ログインでコメント → ログインシート → 新規登録 → コメント送信・AI 回答
///   → カート追加 → 注文 → 購入告知 → 注文履歴 → ログアウト
final class LiveCommerceFlowUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        // --reset-session:前回のテストのログイン状態(Keychain)を消して開始
        // --ui-testing:iOS のパスワード自動入力を止める(OS の確認画面がテストの操作を横取りするため)。
        //   パスワード欄も普通の入力欄になるので、テストでは app.textFields["passwordField"] で探す
        app.launchArguments = ["--reset-session", "--ui-testing"]
        // 接続先を変える:TEST_RUNNER_API_BASE=http://127.0.0.1:8011 xcodebuild test ...
        // (開発サーバとは別の、空の DB で起動したテスト用サーバに向けるため。「-キー 値」の引数は UserDefaults を上書きする)
        if let base = ProcessInfo.processInfo.environment["API_BASE"] {
            app.launchArguments += ["-apiBaseURL", base]
        }
        app.launch()
    }

    /// スクリーンショットを結果に添付(環境変数 SHOTS_DIR があれば PNG も保存)
    func snap(_ name: String) {
        let shot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        if let dir = ProcessInfo.processInfo.environment["SHOTS_DIR"] {
            try? shot.pngRepresentation.write(to: URL(fileURLWithPath: dir).appendingPathComponent("\(name).png"))
        }
    }

    /// キーボードが出ていれば、ホスト部分をタップして閉じる(キーボードはタブバーや一覧の一部を隠す)
    func dismissKeyboard() {
        // 他社製のキーボードはアプリの外にあり app.keyboards では見えないので、出ているかどうかに関わらずタップする
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2)).tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5), "キーボードが閉じない")
        // 入力中は隠れている商品カードが戻るまで待つ
        XCTAssertTrue(app.buttons["featuredAddToCart"].waitForExistence(timeout: 5), "キーボードを閉じても商品カードが戻らない")
    }

    /// 入力欄をタップして文字を打つ。実機ではタップしてもすぐにはフォーカスが移らないことがあるので、移るまで待ち、だめならもう一度タップする
    func type(_ string: String, into element: XCUIElement) {
        for _ in 0..<3 {
            element.tap()
            let focused = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hasKeyboardFocus == true"), object: element)
            if XCTWaiter().wait(for: [focused], timeout: 2) == .completed { break }
        }
        element.typeText(string)
    }

    func text(containing s: String) -> XCUIElement {
        app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", s)).firstMatch
    }

    /// タブを切り替える(バッジが付くとラベルが「カート, 1件」のように変わることがあるので前方一致で探す)
    func tab(_ name: String) {
        let pred = NSPredicate(format: "label == %@ OR label BEGINSWITH %@", name, name + ",")
        let inTabBar = app.tabBars.buttons.matching(pred).firstMatch
        if inTabBar.waitForExistence(timeout: 3) {
            // ログイン直後は iOS の「パスワードを保存しますか?」の確認が画面を覆っていて、1回目のタップはそれを閉じるだけになる。
            // (アプリの不具合ではなく OS の機能。調査して確認済み)選択されるまで繰り返す
            for attempt in 1...4 {
                inTabBar.tap()
                let selected = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isSelected == true"), object: inTabBar)
                if XCTWaiter().wait(for: [selected], timeout: 2) == .completed {
                    if attempt > 1 { print("EDGE tab-retry: \(name) は \(attempt) 回目で切り替わった") }
                    return
                }
            }
            XCTFail("タブ「\(name)」に切り替わらない")
            return
        }
        app.buttons.matching(pred).firstMatch.tap()
    }

    /// 失敗調査用:画面の要素ツリーを SHOTS_DIR に保存
    func dumpTree(_ name: String) {
        if let dir = ProcessInfo.processInfo.environment["SHOTS_DIR"] {
            try? app.debugDescription.write(toFile: dir + "/\(name).txt", atomically: true, encoding: .utf8)
        }
    }

    func testRegisterCommentAndPurchaseFlow() throws {
        let user = "ios_\(Int(Date().timeIntervalSince1970) % 1_000_000)"
        let question = "送料はいくらですか?"

        // 1. ライブ画面:WebSocket で視聴者数が届く
        let viewers = app.staticTexts["viewers"]
        XCTAssertTrue(viewers.waitForExistence(timeout: 15))
        XCTAssertTrue(app.wait(for: viewers, labelContains: "1人", timeout: 10), "視聴者数: \(viewers.label)")
        snap("01_live")
        let soundButton = app.buttons["soundButton"]       // 音声は既定でオン。オフになっていたらオンにする
        if soundButton.label == "音声オフ" { soundButton.tap() }
        XCTAssertEqual(soundButton.label, "音声オン")

        // 2. 未ログインでコメント → ログインシートが開く
        let field = app.textFields["commentField"]
        type(question, into: field)
        app.buttons["sendButton"].tap()
        let username = app.textFields["usernameField"]
        XCTAssertTrue(username.waitForExistence(timeout: 5), "ログインシートが開かない")

        // 3. 新規登録
        app.buttons["新規登録"].firstMatch.tap()
        type(user, into: username)
        let password = app.textFields["passwordField"]
        type("pass1234", into: password)
        snap("02_register")
        app.buttons["authSubmit"].tap()
        XCTAssertTrue(app.textFields["usernameField"].waitForNonExistence(timeout: 10), "登録に失敗(シートが閉じない)")

        // 4. ログイン後、保留していたコメントが送信され、AI ホストが回答する
        XCTAssertTrue(app.descendants(matching: .any)["hostComment"].firstMatch.waitForExistence(timeout: 20), "ホストの回答がない")
        snap("03a_typing")
        // キーボードを閉じてから自分のコメントを確認する(画面が小さい端末では、キーボード表示中は一覧の上の行が画面外になる)
        dismissKeyboard()
        if !text(containing: question).waitForExistence(timeout: 10) { snap("zz_comment_debug"); dumpTree("zz_comment_tree") }
        XCTAssertTrue(text(containing: question).exists, "自分のコメントが表示されない")
        // 音声(VOICEVOX)が最後まで再生される。サーバ側で VOICEVOX が動いていない場合はこの確認を飛ばす
        if ProcessInfo.processInfo.environment["EXPECT_AUDIO"] == "1" {
            let sound = app.buttons["soundButton"]
            let played = XCTNSPredicateExpectation(
                predicate: NSPredicate(format: "value != %@", "再生済み 0"), object: sound)
            XCTAssertEqual(XCTWaiter().wait(for: [played], timeout: 30), .completed, "音声が再生されない: \(sound.value ?? "")")
        }
        snap("03_comment_reply")

        // 5. 紹介中の商品をカートへ
        app.buttons["featuredAddToCart"].tap()
        XCTAssertTrue(text(containing: "カートに追加しました").waitForExistence(timeout: 5))

        // 6. カート → 注文確定
        dismissKeyboard()
        tab("カート")
        let checkout = app.buttons["checkoutButton"]
        if !checkout.waitForExistence(timeout: 8) { snap("zz_cart_debug"); dumpTree("zz_cart_tree") }
        XCTAssertTrue(checkout.exists, "注文ボタンが見つからない")
        snap("04_cart")
        checkout.tap()
        let alert = app.alerts.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 10))
        XCTAssertTrue(alert.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "ご注文ありがとうございます")).firstMatch.exists,
                      "注文が成功しない")
        snap("05_ordered")
        alert.buttons["OK"].tap()

        // 7. ライブ画面に購入告知
        tab("ライブ")
        XCTAssertTrue(app.descendants(matching: .any)["systemComment"].firstMatch.waitForExistence(timeout: 10), "購入告知がない")
        snap("06_purchase_notice")

        // 商品一覧(見た目の確認用にスクリーンショットを残す)
        tab("商品")
        XCTAssertTrue(text(containing: "本日の商品").waitForExistence(timeout: 5))
        snap("06b_products")
        app.swipeUp(); app.swipeUp()
        snap("06c_guide")

        // 8. アカウント:注文履歴 → ログアウト
        tab("アカウント")
        XCTAssertTrue(app.staticTexts["#1"].waitForExistence(timeout: 10) || text(containing: "#").exists, "注文履歴がない")
        snap("07_account")
        // 接続先の設定は「開発者向け設定」の中にあり、アカウント画面には直接出ていない
        XCTAssertFalse(app.buttons["再接続"].exists, "開発者向けの設定がアカウント画面に出ている")
        app.buttons["developerSettings"].tap()
        XCTAssertTrue(app.buttons["再接続"].waitForExistence(timeout: 5), "開発者向け設定が開けない")
        snap("07b_developer")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["logoutButton"].tap()
        XCTAssertTrue(app.buttons["openLogin"].waitForExistence(timeout: 10), "ログアウトできない")
    }

    /// ホーム画面に出てから戻っても、接続が回復してコメントを送れる
    func testReturnFromBackgroundKeepsWorking() throws {
        let viewers = app.staticTexts["viewers"]
        XCTAssertTrue(viewers.waitForExistence(timeout: 15))
        XCTAssertTrue(app.wait(for: viewers, labelContains: "1人", timeout: 15), "視聴者数: \(viewers.label)")

        XCUIDevice.shared.press(.home)
        sleep(40)                                          // バックグラウンドに置く(この間に接続が切れることがある)
        app.activate()
        XCTAssertTrue(app.wait(for: viewers, labelContains: "1人", timeout: 20), "戻ったあと再接続されない: \(viewers.label)")

        let user = "bg_\(Int(Date().timeIntervalSince1970) % 1_000_000)"
        let field = app.textFields["commentField"]
        type("戻ってきました。送料は?", into: field)
        app.buttons["sendButton"].tap()
        let username = app.textFields["usernameField"]
        XCTAssertTrue(username.waitForExistence(timeout: 5))
        app.buttons["新規登録"].firstMatch.tap()
        type(user, into: username)
        let password = app.textFields["passwordField"]
        type("pass1234", into: password)
        app.buttons["authSubmit"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["hostComment"].firstMatch.waitForExistence(timeout: 20), "戻ったあとコメントが送れない(ホストの回答がない)")
        dismissKeyboard()
        XCTAssertTrue(text(containing: "戻ってきました").waitForExistence(timeout: 10), "自分のコメントが表示されない")
        snap("10_after_background")
    }

    /// 利用中にセッションが切れた場合:ログイン画面が出て、ログインし直すと直前のコメントが送り直される
    /// サーバ側でセッションを失効させる操作が必要なので、普段は実行しない。手順:
    ///   1. テスト用サーバを SQLite で起動  2. TEST_RUNNER_EXPIRE_SESSION_TEST=1 を付けて実行
    ///   3. 画面に「1つ目」が出たあとの 12 秒の間に、DB で UPDATE auth_sessions SET expires_at='2000-01-01 00:00:00'
    func testExpiredSessionAsksToLoginAgain() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["EXPIRE_SESSION_TEST"] == "1", "セッション失効の操作が必要なため通常は実行しない")
        let user = "exp_\(Int(Date().timeIntervalSince1970) % 1_000_000)"
        let field = app.textFields["commentField"]
        type("1つ目の質問です", into: field)
        app.buttons["sendButton"].tap()
        let username = app.textFields["usernameField"]
        XCTAssertTrue(username.waitForExistence(timeout: 5))
        app.buttons["新規登録"].firstMatch.tap()
        type(user, into: username)
        let password = app.textFields["passwordField"]
        type("pass1234", into: password)
        app.buttons["authSubmit"].tap()
        XCTAssertTrue(text(containing: "1つ目の質問です").waitForExistence(timeout: 15), "登録後のコメントが出ない")

        sleep(12)                                          // この間にサーバ側でセッションを失効させる

        type("2つ目は届きますか?", into: field)
        app.buttons["sendButton"].tap()
        XCTAssertTrue(username.waitForExistence(timeout: 15), "セッション切れなのにログイン画面が出ない")
        snap("08_session_expired")
        type(user, into: username)
        type("pass1234", into: password)
        app.buttons["authSubmit"].tap()
        XCTAssertTrue(text(containing: "2つ目は届きますか?").waitForExistence(timeout: 15), "再ログイン後にコメントが送り直されない")
        snap("09_resent_after_login")
    }
}

extension XCUIApplication {
    /// 要素のラベルが指定の文字列を含むまで待つ
    func wait(for element: XCUIElement, labelContains s: String, timeout: TimeInterval) -> Bool {
        let exp = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label CONTAINS %@", s), object: element)
        return XCTWaiter().wait(for: [exp], timeout: timeout) == .completed
    }
}
