//
//  PartnerDesignB.swift
//  irodori - Sandbox
//
//  案B: チャット (LINE風) シーケンス. 相棒の短文吹き出しが順次フェードイン.
//  スコアは棒グラフが伸びるアニメで同期.
//

import SwiftUI

struct PartnerDesignB: View {
    let insight: UserInsightResponse
    @State private var visibleMessageCount: Int = 0
    @State private var scoresAnimated: Bool = false

    private var messages: [String] {
        let text = insight.insight
            .replacingOccurrences(of: "\n", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = text
            .components(separatedBy: CharacterSet(charactersIn: "。！"))
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        var msgs = ["やっほー！今のあなたを観察してきたよ。"]
        msgs += parts.prefix(3).map { $0 + "。" }
        msgs.append("もっと知りたかったらタイプ詳細も見てみてね👀")
        return msgs
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    header
                    headerRow

                    ForEach(0..<min(visibleMessageCount, messages.count), id: \.self) { i in
                        chatBubble(messages[i])
                            .id("msg-\(i)")
                            .transition(.opacity.combined(with: .move(edge: .leading)))
                    }

                    if visibleMessageCount >= messages.count {
                        scoreSection
                            .padding(.top, 16)
                            .transition(.opacity)
                    }

                    Spacer(minLength: 32)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 100)
                .padding(.top, 12)
                .onChange(of: visibleMessageCount) { _, newValue in
                    if newValue > 0 {
                        withAnimation(.easeOut(duration: 0.3)) {
                            proxy.scrollTo("msg-\(newValue - 1)", anchor: .bottom)
                        }
                    }
                }
            }
            .background(Color.gray.opacity(0.06))
            .onTapGesture {
                // タップで早送り
                if visibleMessageCount < messages.count {
                    withAnimation(.easeOut(duration: 0.25)) {
                        visibleMessageCount = messages.count
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        withAnimation(.spring(response: 0.7)) { scoresAnimated = true }
                    }
                }
            }
            .task {
                await playSequence()
            }
        }
    }

    private func playSequence() async {
        for i in 1...messages.count {
            try? await Task.sleep(nanoseconds: 600_000_000)
            withAnimation(.easeOut(duration: 0.3)) {
                visibleMessageCount = i
            }
        }
        try? await Task.sleep(nanoseconds: 400_000_000)
        withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
            scoresAnimated = true
        }
    }

    private var header: some View {
        Text("相棒")
            .font(.system(size: 18, weight: .semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(.white)
    }

    private var headerRow: some View {
        HStack(spacing: 10) {
            if let ft = insight.fashion_type {
                Image(PartnerSandboxImage.name(for: ft.type_name))
                    .resizable()
                    .scaledToFill()
                    .frame(width: 36, height: 36)
                    .clipShape(Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(ft.type_name)
                        .font(.system(size: 13, weight: .semibold))
                    Text("相棒 · \(ft.type_code)")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
    }

    private func chatBubble(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            if let ft = insight.fashion_type {
                Image(PartnerSandboxImage.name(for: ft.type_name))
                    .resizable()
                    .scaledToFill()
                    .frame(width: 28, height: 28)
                    .clipShape(Circle())
            }
            Text(text)
                .font(.system(size: 14))
                .foregroundStyle(.primary)
                .lineSpacing(3)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(.white)
                .clipShape(BubbleShape())
                .overlay(BubbleShape().stroke(Color.black.opacity(0.05), lineWidth: 1))
                .shadow(color: .black.opacity(0.04), radius: 3, x: 0, y: 1)
            Spacer(minLength: 24)
        }
    }

    private var scoreSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("ファッションタイプスコア")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)
            if let s = insight.fashion_type?.scores {
                scoreRow("流行感度", s.trend_score, color: .purple)
                scoreRow("自己起点", s.self_score, color: .blue)
                scoreRow("社会起点", s.social_score, color: .green)
                scoreRow("機能性", s.function_score, color: .orange)
                scoreRow("経済性", s.economy_score, color: .pink)
            }
        }
        .padding(14)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
    }

    private func scoreRow(_ title: String, _ value: Double, color: Color) -> some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .frame(width: 60, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.gray.opacity(0.12))
                    Capsule()
                        .fill(color)
                        .frame(width: scoresAnimated ? geo.size.width * CGFloat(min(value, 5) / 5) : 0)
                }
            }
            .frame(height: 8)
            Text(String(format: "%.1f", value))
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 28, alignment: .trailing)
        }
    }
}

// 左に小さな尻尾を出した吹き出し
private struct BubbleShape: Shape {
    func path(in rect: CGRect) -> Path {
        let radius: CGFloat = 12
        let tail: CGFloat = 6
        var p = Path()
        p.addRoundedRect(in: rect, cornerSize: CGSize(width: radius, height: radius))
        // 左に小さな尻尾
        p.move(to: CGPoint(x: rect.minX + 4, y: rect.minY + 14))
        p.addQuadCurve(to: CGPoint(x: rect.minX + 4, y: rect.minY + 14 + tail * 2),
                       control: CGPoint(x: rect.minX - tail, y: rect.minY + 14 + tail))
        return p
    }
}

#Preview("案B: チャット") {
    PartnerDesignB(insight: PartnerSandbox.mockInsight())
}
