import Foundation

/// ライブ配信の WebSocket クライアント
/// - 接続時のリクエストヘッダに Authorization: Bearer を付ける(サーバは握手時にユーザーを判定)
/// - 切断されたら 2 秒後に自動再接続(Web 版の ws.onclose → setTimeout(connect) と同じ)
@MainActor
final class LiveSocket {
    var onEvent: ((LiveEvent) -> Void)?
    var onStatus: ((Bool) -> Void)?

    private let session = URLSession(configuration: .ephemeral)
    private var task: URLSessionWebSocketTask?
    private var shouldRun = false

    func connect() {
        disconnect()
        shouldRun = true
        var req = URLRequest(url: AppConfig.webSocketURL)
        if let token = Keychain.load() {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let t = session.webSocketTask(with: req)
        task = t
        t.resume()
        receive(on: t)
    }

    func disconnect() {
        shouldRun = false
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
        onStatus?(false)
    }

    func sendComment(_ text: String) async throws {
        // 接続が無いときは、黙って捨てずにエラーにする(呼び出し側が入力内容を戻して知らせる)
        guard let task else { throw URLError(.notConnectedToInternet) }
        let payload = try JSONSerialization.data(withJSONObject: ["type": "comment", "text": text])
        try await task.send(.string(String(decoding: payload, as: UTF8.self)))
    }

    private func receive(on t: URLSessionWebSocketTask) {
        t.receive { [weak self] result in
            Task { @MainActor in
                guard let self, self.task === t else { return }   // 古い接続のコールバックは無視
                switch result {
                case .success(let message):
                    self.onStatus?(true)
                    if case .string(let s) = message, let ev = LiveEvent.decode(s) {
                        self.onEvent?(ev)
                    }
                    self.receive(on: t)
                case .failure:
                    self.onStatus?(false)
                    guard self.shouldRun else { return }
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                    if self.shouldRun && self.task === t { self.connect() }
                }
            }
        }
    }
}
