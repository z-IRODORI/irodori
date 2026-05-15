//
//  DailyDesignB.swift
//  irodori - Sandbox
//
//  案B: 3×3 グリッド主役 + 直下に「選択カードの理由」パネル。
//       - 見出し右にミニ天気バッジ
//       - 未選択カードのタップ: 選択（枠線+理由パネル更新）
//       - 選択中カードのタップ or 右下「拡大ボタン」: 拡大 (onTap 呼び出し)
//

import SwiftUI
import Kingfisher

struct DailyDesignB: View {
    let response: DailyRecommendationResponse
    var onTap: (DailyRecommendationItem) -> Void = { _ in }

    @State private var selectedIndex: Int = 0

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                headerRow
                if let c = response.partner_comment, !c.isEmpty {
                    SandboxPartnerComment(text: c)
                }
                grid
                reasonPanel
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
        }
        .background(Color.gray.opacity(0.08))
    }

    // 見出し + 右側ミニ天気
    private var headerRow: some View {
        HStack(alignment: .center, spacing: 8) {
            Text("明日のコーデ")
                .font(.system(size: 20, weight: .bold))
            Spacer()
            SandboxMiniWeather(weather: response.weather)
        }
    }

    private var grid: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(Array(response.recommendations.enumerated()), id: \.element.id) { idx, item in
                gridCell(index: idx, item: item)
            }
        }
    }

    private func gridCell(index idx: Int, item: DailyRecommendationItem) -> some View {
        Button {
            handleTap(index: idx, item: item)
        } label: {
            ZStack(alignment: .topTrailing) {
                SandboxCoordImage(source: item.image_url)
                    .scaledToFill()
                    .frame(height: 150)
                    .frame(maxWidth: .infinity)
                    .clipped()
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(idx == selectedIndex ? Color.orange : Color.clear, lineWidth: 3)
                    )
                if idx == 0 {
                    SandboxIchioshiBadge().padding(6)
                }
            }
        }
        .buttonStyle(.plain)
        .overlay(alignment: .bottomTrailing) {
            if idx == selectedIndex {
                Button { onTap(item) } label: {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(8)
                        .background(Color.black.opacity(0.65))
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.25), radius: 3, x: 0, y: 1)
                }
                .buttonStyle(.plain)
                .padding(6)
                .transition(.opacity.combined(with: .scale))
            }
        }
    }

    private func handleTap(index: Int, item: DailyRecommendationItem) {
        if index == selectedIndex {
            // 選択中カードの再タップ → 拡大
            onTap(item)
        } else {
            withAnimation(.easeInOut(duration: 0.18)) { selectedIndex = index }
        }
    }

    private var reasonPanel: some View {
        let item = response.recommendations[selectedIndex]
        let bodyText: String = {
            if let r = item.reason, !r.isEmpty { return r }
            if !item.vibe.isEmpty { return item.vibe }
            return "明日のコンディションに合う一着です。"
        }()
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "lightbulb.fill")
                    .foregroundStyle(.orange)
                    .font(.system(size: 13))
                Text("選んだ理由")
                    .font(.system(size: 13, weight: .bold))
                Spacer()
            }
            Text(bodyText)
                .font(.system(size: 13))
                .foregroundStyle(.primary)
                .lineSpacing(3)
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 6) {
                if !item.style.isEmpty { chip(item.style) }
                if !item.main_colors.isEmpty {
                    chip(item.main_colors.prefix(2).joined(separator: "・"))
                }
            }
        }
        .padding(14)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }

    private func chip(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.gray.opacity(0.1))
            .clipShape(Capsule())
    }
}

#Preview("案B: 理由インライン") {
    DailyDesignB(response: SandboxDaily.mockResponse())
}
