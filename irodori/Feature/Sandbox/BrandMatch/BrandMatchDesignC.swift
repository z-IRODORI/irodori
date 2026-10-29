//
//  BrandMatchDesignC.swift
//  irodori - Sandbox
//
//  案 C「相棒が紹介」: 相棒がチャットで 1 つずつ紹介し、「気になる / 知ってる / ちょっと違う」で答える。
//  紹介するブランドは一覧と同じ「ロゴ枠 + 2 行」の行で見せ、くわしくは詳細シートへ。
//

import SwiftUI

struct BrandMatchDesignC: View {
    @Bindable var store: BrandMatchStore

    private enum Entry: Identifiable {
        case partner(Int, String)
        case user(Int, String)
        case brand(Int, BMPick)
        var id: Int {
            switch self {
            case .partner(let i, _), .user(let i, _), .brand(let i, _): return i
            }
        }
    }

    @State private var entries: [Entry] = []
    @State private var shown = 0          // 紹介したブランドの数
    @State private var typing = false
    @State private var awaiting = false   // 返事待ち
    @State private var opened: BMPick?
    @State private var seq = 0

    private var picks: [BMPick] { store.persona.picks }
    private var persona: BMPersona { store.persona }

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(entries) { e in
                            switch e {
                            case .partner(let i, let t):
                                BMPartnerBubble(persona: persona, text: t, showsIcon: !isFollowUp(i))
                                    .transition(.opacity)
                            case .user(_, let t):
                                userBubble(t)
                            case .brand(_, let p):
                                brandMessage(p)
                                    .padding(.leading, 40)
                                    .transition(.opacity)
                            }
                        }
                        if typing { typingDots }
                        Color.clear.frame(height: 1).id("end")
                    }
                    .padding(16)
                }
                .onChange(of: entries.count) { _, _ in scrollToEnd(proxy) }
                .onChange(of: typing) { _, _ in scrollToEnd(proxy) }
            }
            replyBar
        }
        .background(BMTokens.ground)
        .sheet(item: $opened) { BMDetailSheet(store: store, pick: $0) }
        .task { await start() }
    }

    // MARK: 流れ

    private func start() async {
        entries = []
        shown = 0
        await say(persona.partnerLine, after: 0.6)
        await say("あなたに合いそうなブランドを 10 個見つけたよ。まずは、ど真ん中の 5 つから。", after: 1.0)
        await showNext()
    }

    private func showNext() async {
        guard shown < picks.count else {
            let liked = picks.filter { store.reaction($0.brandID) == .like }.count
            await say(liked > 0
                      ? "10 個ぜんぶ見てくれてありがとう。「好き」の \(liked) 個は、相棒画面にとっておくね。"
                      : "10 個ぜんぶ見てくれてありがとう。ピンとこなかったら、服を教えてくれるともっと合わせられるよ。",
                      after: 0.9)
            return
        }
        let p = picks[shown]
        if shown > 0, picks[shown - 1].slot != p.slot {
            await say(p.slot == .stretch
                      ? "次は、ちょっと背伸びの 3 つ。1 段上の価格か、少し先の流行だよ。"
                      : "最後は、はじめましての 2 つ。あなたのクローゼットにまだ少ない雰囲気だよ。",
                      after: 0.8)
        }
        typing = true
        try? await Task.sleep(for: .seconds(0.7))
        typing = false
        withAnimation(.easeOut(duration: 0.25)) { append { .brand($0, p) } }
        AccessibilityNotification.Announcement("\(p.slot.title)、\(p.brand.nameEn)").post()
        shown += 1
        awaiting = true
    }

    private func reply(_ r: BMReaction, text: String) {
        guard awaiting, shown > 0 else { return }
        let p = picks[shown - 1]
        awaiting = false
        store.set(r, for: p.brandID)
        Haptic.selection()
        withAnimation { append { .user($0, text) } }
        Task {
            switch r {
            case .like: await say("いいね。好きなブランドにとっておくね。", after: 0.7)
            case .known: await say("知ってたんだね。じゃあ、次。", after: 0.7)
            case .notInterested: await say("了解。似た雰囲気のブランドは減らしておくね。", after: 0.7)
            case .owned: break
            }
            await showNext()
        }
    }

    private func say(_ text: String, after seconds: Double) async {
        typing = true
        try? await Task.sleep(for: .seconds(seconds))
        typing = false
        withAnimation(.easeOut(duration: 0.25)) { append { .partner($0, text) } }
        AccessibilityNotification.Announcement(text).post()   // 新しい発言を読み上げる
    }

    private func append(_ make: (Int) -> Entry) {
        seq += 1
        entries.append(make(seq))
    }

    /// 直前も相棒の発言なら、アイコンを省く
    private func isFollowUp(_ id: Int) -> Bool {
        guard let i = entries.firstIndex(where: { $0.id == id }), i > 0 else { return false }
        switch entries[i - 1] {
        case .partner, .brand: return true
        case .user: return false
        }
    }

    private func scrollToEnd(_ proxy: ScrollViewProxy) {
        Task {
            try? await Task.sleep(for: .milliseconds(200))
            withAnimation(.easeOut(duration: 0.3)) { proxy.scrollTo("end", anchor: .bottom) }
        }
    }

    // MARK: 部品

    /// 紹介するブランド: 枠の名前 / ロゴつきの行 / くわしく
    private func brandMessage(_ p: BMPick) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            BMSlotLabel(slot: p.slot)
                .padding(.horizontal, 16)
                .padding(.top, 12)
            BMBrandRow(pick: p, reaction: store.reaction(p.brandID), showsChevron: false)
            BMRule()
            Button { opened = p } label: {
                HStack {
                    Text("くわしく見る").font(.system(size: 14, weight: .medium))
                    Spacer()
                    Image(systemName: "chevron.right").font(.system(size: 12, weight: .medium))
                        .foregroundStyle(BMTokens.faint)
                }
                .foregroundStyle(BMTokens.ink)
                .padding(.horizontal, 16)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .bmCard()
    }

    private func userBubble(_ text: String) -> some View {
        HStack {
            Spacer(minLength: 64)
            Text(text)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(BMTokens.surface)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(BMTokens.primary, in: UnevenRoundedRectangle(
                    topLeadingRadius: 16, bottomLeadingRadius: 16, bottomTrailingRadius: 4, topTrailingRadius: 16,
                    style: .continuous))
        }
        .padding(.top, 4)
    }

    private var typingDots: some View {
        HStack(spacing: 8) {
            BMPartnerIcon(persona: persona, size: 32)
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { _ in
                    Circle().fill(BMTokens.control).frame(width: 6, height: 6)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(BMTokens.surface, in: Capsule())
            .overlay(Capsule().stroke(BMTokens.border, lineWidth: 1))
            Spacer()
        }
        .accessibilityLabel(Text("入力中"))
    }

    private var replyBar: some View {
        VStack(spacing: 0) {
            BMRule()
            Group {
                if awaiting {
                    HStack(spacing: 8) {
                        // 反応の言葉は全案でそろえる (好き / 知ってた / 興味なし)
                        replyButton("好き", icon: "heart.fill", tint: BMTokens.favorite) { reply(.like, text: "好き") }
                        replyButton("知ってた") { reply(.known, text: "知ってた") }
                        replyButton("興味なし") { reply(.notInterested, text: "興味なし") }
                    }
                } else if shown >= picks.count && !typing {
                    replyButton("最初から紹介してもらう") { Task { await start() } }
                } else {
                    Text("相棒が話しています…")
                        .font(.system(size: 12))
                        .foregroundStyle(BMTokens.muted)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(BMTokens.surface)
    }

    private func replyButton(_ title: String, icon: String? = nil, tint: Color = BMTokens.ink,
                             action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let icon { Image(systemName: icon).foregroundStyle(tint) }
                Text(title)
            }
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(BMTokens.ink)
                .frame(maxWidth: .infinity, minHeight: 44)
                .overlay(RoundedRectangle(cornerRadius: BMTokens.controlRadius).stroke(BMTokens.control, lineWidth: 1))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
