//
//  RenewalPartnerLoadingView.swift
//  irodori
//
//  コーデを組んでいる間のローディング。相棒のアイコンがゆっくり明滅し、
//  その下にひとことだけ添える (演出は控えめに)。Reduce Motion では静止。
//

import SwiftUI

struct RenewalPartnerLoadingView: View {
    let typeName: String
    /// 主役の服を選んで組み直しているときは、その服の名前
    var pinnedLabel: String? = nil
    var compact = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dim = false

    private var message: String {
        if let pinnedLabel { return "\(pinnedLabel)で組んでいます…" }
        return "相棒がコーデを組んでいます…"
    }

    var body: some View {
        VStack(spacing: compact ? 8 : 12) {
            RenewalPartnerAvatar(typeName: typeName, size: compact ? 44 : 56)
                .opacity(dim ? 0.45 : 1)
            Text(message)
                .font(.system(size: 13))
                .foregroundStyle(RenewalTokens.muted)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, compact ? 16 : 28)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { dim = true }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(message)
    }
}
