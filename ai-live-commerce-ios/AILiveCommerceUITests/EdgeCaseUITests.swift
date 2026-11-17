import XCTest

/// 「ふつうでない使い方」の確認。テスト用サーバ(空の DB、ADMIN_TOKEN=test-token)に対して実行する
/// 結果の文言は print("EDGE ...") で出力し、xcodebuild のログから確認できるようにしている
extension LiveCommerceFlowUITests {

    // MARK: 補助
    private var apiBase: String { ProcessInfo.processInfo.environment["API_BASE"] ?? "http://127.0.0.1:8000" }

    /// 管理 API を呼ぶ(在庫を変えるなど、アプリの外から状況を作るため)
    @discardableResult
    private func admin(_ method: String, _ path: String, _ body: [String: Any]? = nil) -> Int {
        var req = URLRequest(url: URL(string: apiBase + path)!)
        req.httpMethod = method
        req.setValue("test-token", forHTTPHeaderField: "X-Admin-Token")
        if let body {
            req.httpBody = try? JSONSerialization.data(withJSONObject: body)
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        var status = 0
        let done = DispatchSemaphore(value: 0)
        URLSession.shared.dataTask(with: req) { _, res, _ in
            status = (res as? HTTPURLResponse)?.statusCode ?? 0
            done.signal()
        }.resume()
        _ = done.wait(timeout: .now() + 10)
        return status
    }

    private func relaunch(extra: [String]) {
        app.terminate()
        app.launchArguments += extra
        app.launch()
    }

    /// アカウント画面からログインシートを開く
    private func openLoginSheet() {
        tab("アカウント")
        app.buttons["openLogin"].tap()
        XCTAssertTrue(app.textFields["usernameField"].waitForExistence(timeout: 5))
    }

    private func register(_ user: String) {
        openLoginSheet()
        app.buttons["新規登録"].firstMatch.tap()
        type(user, into: app.textFields["usernameField"])
        type("pass1234", into: app.textFields["passwordField"])
        app.buttons["authSubmit"].tap()
        XCTAssertTrue(app.buttons["logoutButton"].waitForExistence(timeout: 10), "登録できない")
        // シートが閉じきる前に次の操作をすると、タップが空振りする
        XCTAssertTrue(app.textFields["usernameField"].waitForNonExistence(timeout: 5))
        sleep(1)
    }

    private func uniqueUser(_ prefix: String) -> String { "\(prefix)\(Int(Date().timeIntervalSince1970) % 1_000_000)" }

    // MARK: 1. ログイン・登録の失敗が、利用者に分かる言葉で表示される
    func testEdgeAuthErrorsAreReadable() throws {
        openLoginSheet()
        let error = app.staticTexts["authError"]

        // 存在しないユーザーでログイン
        type("nobody_\(Int.random(in: 1000...9999))", into: app.textFields["usernameField"])
        type("wrongpass", into: app.textFields["passwordField"])
        app.buttons["authSubmit"].tap()
        XCTAssertTrue(error.waitForExistence(timeout: 10), "ログイン失敗の理由が表示されない")
        print("EDGE login-unknown-user: \(error.label)")
        snap("e1_login_error")

        // 短すぎるパスワードで登録
        app.buttons["新規登録"].firstMatch.tap()
        let pw = app.textFields["passwordField"]
        pw.tap()
        pw.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 12))
        pw.typeText("123")
        app.buttons["authSubmit"].tap()
        let shown = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == true"), object: error)
        _ = XCTWaiter().wait(for: [shown], timeout: 10)
        sleep(1)
        print("EDGE register-short-password: \(error.exists ? error.label : "(表示なし)")")
        snap("e1_register_error")
        XCTAssertTrue(error.exists, "登録失敗の理由が表示されない")
        XCTAssertTrue(error.label.contains("パスワードは6"), "何を直せばよいか分からない: \(error.label)")
    }

    // MARK: 2. カートに入れたあとで在庫がなくなった
    func testEdgeCheckoutFailsWhenStockRunsOut() throws {
        // 実機ではテスト実行アプリから Mac のサーバへ直接は届かない(ローカルネットワークの許可がない)ので、その場合は飛ばす
        try XCTSkipUnless(admin("PATCH", "/api/admin/products/1", ["stock": 1]) == 200, "テストから管理 API に届かない環境(実機など)")
        register(uniqueUser("so_"))
        tab("ライブ")
        let add = app.buttons["featuredAddToCart"]
        XCTAssertTrue(add.waitForExistence(timeout: 10))
        add.tap()
        XCTAssertTrue(text(containing: "カートに追加しました").waitForExistence(timeout: 5))

        XCTAssertEqual(admin("PATCH", "/api/admin/products/1", ["stock": 0]), 200)   // 他の人が先に買った、という状況

        tab("カート")
        let checkout = app.buttons["checkoutButton"]
        XCTAssertTrue(checkout.waitForExistence(timeout: 8))
        checkout.tap()
        let alert = app.alerts.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 10))
        let message = alert.staticTexts.allElementsBoundByIndex.map(\.label).joined(separator: " / ")
        print("EDGE checkout-sold-out: \(message)")
        snap("e2_checkout_failed")
        XCTAssertTrue(message.contains("決済に失敗しました"), "失敗が伝わらない: \(message)")
        alert.buttons["OK"].tap()
        XCTAssertTrue(checkout.exists, "失敗したのにカートが消えた")

        tab("ライブ")
        XCTAssertTrue(text(containing: "在庫切れ").waitForExistence(timeout: 8), "ライブ画面に在庫切れが出ない")
        XCTAssertFalse(app.buttons["featuredAddToCart"].isEnabled, "在庫切れなのにカートへ入れられる")
        snap("e2_live_sold_out")
        tab("商品")
        snap("e2_products_sold_out")
        admin("PATCH", "/api/admin/products/1", ["stock": 30])
    }

    // MARK: 3. コメントを連打した(レート制限)
    func testEdgeRapidCommentsAreLimitedWithoutLogout() throws {
        register(uniqueUser("rp_"))
        tab("ライブ")
        let field = app.textFields["commentField"]
        type("れんだ1\n", into: field)                      // 改行(送信キー)で送る。ボタンを押すより速く連打できる
        for i in 2...9 { field.typeText("れんだ\(i)\n") }       // サーバの上限は 10 秒に 5 件
        let limited = text(containing: "早すぎます")
        XCTAssertTrue(limited.waitForExistence(timeout: 3), "レート制限の案内が出ない")
        print("EDGE rate-limit: \(limited.label)")
        snap("e3_rate_limited")
        XCTAssertFalse(app.textFields["usernameField"].exists, "レート制限でログイン画面が出てしまう")
        dismissKeyboard()                                  // キーボードがタブバーを隠している
        tab("アカウント")
        XCTAssertTrue(app.buttons["logoutButton"].waitForExistence(timeout: 5), "レート制限でログアウトされた")
    }

    // MARK: 4. 接続先サーバの設定がでたらめ
    func testEdgeInvalidServerURLDoesNotCrash() throws {
        for bad in ["not a url", "ftp://example", "http://", "192.168.0.1:99999"] {
            app.terminate()
            app.launchArguments = ["--reset-session", "--ui-testing", "-apiBaseURL", bad]
            app.launch()
            sleep(4)
            XCTAssertEqual(app.state, .runningForeground, "接続先「\(bad)」でアプリが落ちた")
            XCTAssertTrue(app.staticTexts["viewers"].exists, "接続先「\(bad)」で画面が出ない")
            tab("商品"); tab("カート"); tab("アカウント"); tab("ライブ")
            XCTAssertEqual(app.state, .runningForeground, "接続先「\(bad)」でタブ切り替え中に落ちた")
        }
        snap("e4_invalid_url")
    }

    // MARK: 5. ダークモード・大きな文字(見た目はスクリーンショットで確認)
    func testEdgeAppearanceVariants() throws {
        XCUIDevice.shared.appearance = .dark
        addTeardownBlock { XCUIDevice.shared.appearance = .light }
        relaunch(extra: [])
        XCTAssertTrue(app.staticTexts["viewers"].waitForExistence(timeout: 15))
        sleep(2)
        snap("e5_dark_live")
        tab("商品"); sleep(1); snap("e5_dark_products")
        tab("カート"); sleep(1); snap("e5_dark_cart")
        tab("アカウント"); app.buttons["openLogin"].tap(); sleep(1); snap("e5_dark_login")

        XCUIDevice.shared.appearance = .light
        relaunch(extra: ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])   // 最大の文字サイズ
        XCTAssertTrue(app.staticTexts["viewers"].waitForExistence(timeout: 15))
        sleep(2)
        snap("e5_large_live")
        tab("商品"); sleep(1); snap("e5_large_products")
        tab("カート"); sleep(1); snap("e5_large_cart")
    }

    // MARK: 自動ログイン:アプリを終了して起動し直しても同じアカウントのまま
    func testEdgeStaysLoggedInAfterRelaunch() throws {
        let user = uniqueUser("keep_")
        register(user)
        tab("ライブ")
        app.buttons["featuredAddToCart"].tap()             // カートの中身も引き継がれることを見る
        XCTAssertTrue(text(containing: "カートに追加しました").waitForExistence(timeout: 5))

        // 1. ふつうに終了 → 起動(--reset-session を付けない)
        app.terminate()
        app.launchArguments.removeAll { $0 == "--reset-session" }
        app.launch()
        tab("アカウント")
        let name = app.staticTexts["accountUsername"]
        XCTAssertTrue(name.waitForExistence(timeout: 10), "起動し直したらログアウトされていた")
        XCTAssertTrue(name.label.contains(user), "別のアカウントになっている: \(name.label)")
        tab("カート")
        XCTAssertTrue(app.buttons["checkoutButton"].waitForExistence(timeout: 8), "カートの中身が引き継がれていない")
        snap("e7_relaunched")

        // 2. サーバに届かない状態で起動しても、前回のアカウントのまま開ける(ログアウト扱いにしない)
        app.terminate()
        app.launchArguments += ["-apiBaseURL", "http://127.0.0.1:9"]      // 誰も待ち受けていないポート
        app.launch()
        tab("アカウント")
        XCTAssertTrue(app.buttons["openLogin"].waitForExistence(timeout: 8), "別のサーバなのにログイン済みになっている")
        // (↑接続先が違えばログインも別。元の接続先に戻すと元のアカウントに戻る ↓)
        app.terminate()
        app.launchArguments.removeLast(2)
        app.launch()
        tab("アカウント")
        XCTAssertTrue(name.waitForExistence(timeout: 10), "接続先を戻したらログインが消えていた")
        XCTAssertTrue(name.label.contains(user))

        // 3. ログアウトしたら、次の起動ではログインしていない
        app.buttons["logoutButton"].tap()
        XCTAssertTrue(app.buttons["openLogin"].waitForExistence(timeout: 10))
        app.terminate()
        app.launch()
        tab("アカウント")
        XCTAssertTrue(app.buttons["openLogin"].waitForExistence(timeout: 10), "ログアウトしたのに次の起動でログイン済みになっている")
    }

    // MARK: 自動ログイン:サーバが止まっているときに起動しても、前回のアカウントのまま
    /// サーバを外から止めて再起動する操作が必要(SERVER_RESTART_TEST=1 のときだけ)。
    /// 手順:ユーザー名が off_ で始まる登録を見つけたら 8 秒後に止め、30 秒後に同じ DB で起動し直す
    func testEdgeOfflineLaunchKeepsLogin() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["SERVER_RESTART_TEST"] == "1", "サーバの再起動が必要なため通常は実行しない")
        let user = uniqueUser("off_")
        register(user)
        sleep(14)                                          // この間にサーバが止まる
        app.terminate()
        app.launchArguments.removeAll { $0 == "--reset-session" }
        app.launch()
        tab("アカウント")
        let name = app.staticTexts["accountUsername"]
        XCTAssertTrue(name.waitForExistence(timeout: 20), "サーバに届かないだけでログアウト扱いになった")
        XCTAssertTrue(name.label.contains(user))
        snap("e8_offline_launch")
        tab("ライブ")
        XCTAssertTrue(text(containing: "ライブ接続中").waitForExistence(timeout: 60), "サーバが戻っても再接続しない")
        type("もどったあとのコメントです?", into: app.textFields["commentField"])
        app.buttons["sendButton"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["hostComment"].firstMatch.waitForExistence(timeout: 20), "サーバ復帰後、ログインし直さないとコメントできない")
        XCTAssertFalse(app.textFields["usernameField"].exists, "ログイン画面が出てしまった")
    }

    // MARK: 6. 利用中にサーバが落ちて、しばらくして戻る
    /// サーバを外から止めて再起動する操作が必要なので、普段は実行しない(SERVER_RESTART_TEST=1 のときだけ)。
    /// 手順:ユーザー名が down_ で始まる登録を見つけたら、数秒後にサーバを止め、12 秒後に同じ DB で起動し直す
    func testEdgeServerRestartRecovers() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["SERVER_RESTART_TEST"] == "1", "サーバの再起動が必要なため通常は実行しない")
        register(uniqueUser("down_"))
        tab("ライブ")
        XCTAssertTrue(text(containing: "ライブ接続中").waitForExistence(timeout: 10))

        XCTAssertTrue(text(containing: "接続しています").waitForExistence(timeout: 30), "サーバが止まったのに接続中の表示のまま")
        snap("e6_disconnected")
        let field = app.textFields["commentField"]
        type("とまっているあいだのコメント", into: field)
        app.buttons["sendButton"].tap()
        sleep(3)
        let toast = text(containing: "接続が切れています")
        print("EDGE send-while-down: toast=\(toast.exists) field=\(String(describing: field.value))")
        snap("e6_send_while_down")
        XCTAssertEqual(field.value as? String, "とまっているあいだのコメント", "送れなかったコメントが入力欄に残っていない")
        dismissKeyboard()                                  // 入力中は「ライブ接続中」の表示が隠れるので、閉じてから確認する

        XCTAssertTrue(text(containing: "ライブ接続中").waitForExistence(timeout: 40), "サーバが戻っても再接続しない")
        if let v = field.value as? String, v.contains("とまっている") {
            app.buttons["sendButton"].tap()                // 戻された入力内容をそのまま送る
        } else {
            type("もどりましたか?", into: field)
            app.buttons["sendButton"].tap()
            dismissKeyboard()
        }
        let delivered = text(containing: "とまっている").waitForExistence(timeout: 10) || text(containing: "もどりましたか").waitForExistence(timeout: 5)
        snap("e6_recovered")
        XCTAssertTrue(delivered, "再接続後にコメントが送れない")
    }
}
