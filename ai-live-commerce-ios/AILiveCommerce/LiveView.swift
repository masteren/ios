import SwiftUI

/// ライブ画面:ステージ(ホスト+字幕)・紹介中の商品・コメント・入力欄
/// Web 版(app/static/index.html)と同じ構成:明るいグレーの地に、角の丸い白いカードを重ねる
struct LiveView: View {
    @EnvironmentObject var state: AppState
    @State private var input = ""
    @FocusState private var inputFocused: Bool   // キーボードの表示状態(閉じる操作に使う)

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                stage
                // 入力中は商品カードを隠す。小さい画面+背の高いキーボードだと、コメントが1行しか見えなくなるため(実機で確認)
                if let p = state.featured, !inputFocused { featuredCard(p) }
                commentCard
                inputBar
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, 8)
            .background(Theme.stage)
            .animation(.easeInOut(duration: 0.2), value: inputFocused)
            .navigationTitle("HANA")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    // ツールバーの中では幅が詰められるため fixedSize で潰れないようにする
                    HStack(spacing: 6) {
                        Circle().fill(state.connected ? Theme.live : Color.gray).frame(width: 7, height: 7)
                        Text("LIVE").font(.caption.weight(.semibold)).kerning(1.5)
                        Text("視聴者 \(state.viewers)人").font(.caption).monospacedDigit()
                            .accessibilityIdentifier("viewers")
                    }
                    .fixedSize()
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { state.soundOn.toggle() } label: {
                        Image(systemName: state.soundOn ? "speaker.wave.2.fill" : "speaker.slash")
                    }
                    .accessibilityLabel(state.soundOn ? "音声オン" : "音声オフ")
                    .accessibilityValue("再生済み \(state.audioPlayedCount)")
                    .accessibilityIdentifier("soundButton")
                }
            }
        }
    }

    // MARK: ステージ(ホストの立ち絵に、字幕を下から重ねる。Web 版の lower-third と同じ)
    private var stage: some View {
        ZStack(alignment: .bottom) {
            LinearGradient(colors: [.white, Theme.stageDeep], startPoint: .top, endPoint: .bottom)
            // Web 版の 3D アバターを表情ごとに書き出した立ち絵(Resources/hana_*.png)
            // キーボード表示中は全身を縮めず、顔のあたりを切り出して見せる
            HostPortrait(emotion: state.hostEmotion, compact: inputFocused)
                .padding(.top, inputFocused ? 8 : 14)
                .frame(maxHeight: .infinity, alignment: .top)
            subtitle
        }
        .frame(height: inputFocused ? 156 : 264)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusLarge, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture { inputFocused = false }       // ステージをタップするとキーボードを閉じる
    }

    private var subtitle: some View {
        HStack(alignment: .center, spacing: 0) {
            VStack(alignment: .leading, spacing: 1) {
                Text(Theme.hostDisplayName).font(.subheadline.weight(.semibold))
                Text("AIアシスタント").font(.system(size: 9)).foregroundStyle(.secondary)
            }
            .padding(.trailing, 12)
            Divider()
            Text(state.hostText)
                .font(.subheadline)
                .lineLimit(inputFocused ? 2 : 4)
                .minimumScaleFactor(0.85)
                .padding(.leading, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, 14).padding(.vertical, 11)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(10)
    }

    // MARK: 紹介中の商品
    private func featuredCard(_ p: Product) -> some View {
        HStack(spacing: 12) {
            ProductThumb(product: p, size: 60)
            VStack(alignment: .leading, spacing: 2) {
                // 1行目:タグと在庫。価格の行に在庫まで入れると、幅が足りず数字が折り返す
                HStack(spacing: 6) {
                    if !p.tag.isEmpty {
                        Text(p.tag).font(.caption2.weight(.semibold)).foregroundStyle(Theme.accent)
                    }
                    Text(p.stock > 0 ? "残り\(p.stock)点" : "在庫切れ").font(.caption2).foregroundStyle(.secondary)
                }
                .lineLimit(1)
                Text(p.name).font(.subheadline.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.85)
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(yen(p.price)).font(.subheadline)
                    if let off = offText(p) { Text(off).font(.caption.weight(.semibold)).foregroundStyle(Theme.accent) }
                }
                .lineLimit(1)
                .minimumScaleFactor(0.75)                       // 文字を大きくしている端末でも折り返さない
            }
            .frame(maxWidth: .infinity, alignment: .leading)   // 余った幅は商品名に使う(Spacer に取られると名前が省略される)
            Button("カートへ") { Task { await state.addToCart(p) } }
                .buttonStyle(.borderedProminent)
                .disabled(p.stock <= 0)
                .accessibilityIdentifier("featuredAddToCart")
        }
        .padding(12)
        .card()
    }

    // MARK: コメント
    private var commentCard: some View {
        VStack(spacing: 0) {
            // 入力中は見出しを省いて、コメントの行数を確保する(実機+背の高いキーボードでは2行目が切れていた)
            if !inputFocused {
                HStack(alignment: .firstTextBaseline) {
                    Text("コメント").font(.headline)
                    Spacer()
                    Text(state.connected ? "ライブ接続中" : "接続しています…").font(.caption).foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 6)
            }
            commentList
                .padding(.top, inputFocused ? 8 : 0)
        }
        .card()
    }

    private var commentList: some View {
        ScrollViewReader { proxy in
            List(state.comments) { line in
                commentRow(line).id(line.id)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .overlay {
                if state.comments.isEmpty {
                    Text("コメントはまだありません。\n気になることを花奈に質問してみましょう。")
                        .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                        .accessibilityIdentifier("emptyComments")
                }
            }
            .scrollDismissesKeyboard(.interactively)      // コメント欄をスクロールするとキーボードが閉じる
            .onChange(of: state.comments.count) {
                if let last = state.comments.last { withAnimation { proxy.scrollTo(last.id, anchor: .bottom) } }
            }
        }
    }

    @ViewBuilder
    private func commentRow(_ line: ChatLine) -> some View {
        switch line.kind {
        case .host:
            (Text(line.nickname + " ").fontWeight(.semibold).foregroundColor(Theme.brand) + Text(line.text))
                .font(.subheadline)
                .padding(.leading, 10)
                .overlay(alignment: .leading) { Capsule().fill(Theme.brand).frame(width: 2) }
                .accessibilityIdentifier("hostComment")
        case .system:
            Text(line.text).font(.caption).foregroundStyle(.secondary)
                .accessibilityIdentifier("systemComment")
        case .mine, .user:
            (Text(line.nickname + " ").bold().foregroundColor(line.kind == .mine ? Theme.blue : .secondary) + Text(line.text))
                .font(.subheadline)
        }
    }

    // MARK: 入力欄(丸い入力欄+丸い送信ボタン)
    private var inputBar: some View {
        let empty = input.trimmingCharacters(in: .whitespaces).isEmpty
        return HStack(spacing: 8) {
            TextField("質問・コメントを入力", text: $input)
                .submitLabel(.send)
                .onSubmit(send)
                .focused($inputFocused)
                .padding(.horizontal, 16).padding(.vertical, 10)
                .background(Color(.systemBackground), in: Capsule())
                .overlay(Capsule().stroke(Theme.line))
                .accessibilityIdentifier("commentField")
            Button(action: send) {
                Image(systemName: "arrow.up")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(empty ? Color(.systemGray3) : Theme.blue, in: Circle())
            }
            .disabled(empty)
            .accessibilityLabel("送信")
            .accessibilityIdentifier("sendButton")
        }
    }

    private func send() {
        let text = input
        input = ""
        // キーボードの送信キーで送ると、既定では入力欄からフォーカスが外れてキーボードが閉じる。
        // 続けてコメントを書けるよう、キーボードが出ていたときは開いたままにする
        if inputFocused { DispatchQueue.main.async { inputFocused = true } }
        Task {
            // 送れなかったとき(切断中)は入力内容を戻す。その間に別の文字を打っていたら上書きしない
            if await !state.sendComment(text), input.isEmpty { input = text }
        }
    }
}
