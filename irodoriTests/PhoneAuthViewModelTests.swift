//
//  PhoneAuthViewModelTests.swift
//  irodoriTests
//
//  電話番号入力の整形 (+81 ペースト正規化・3-4-4 ハイフン) の回帰テスト。
//  正規化は 11 桁への切り詰めより前に行う必要がある (順序を崩すと 81 判定が不成立になる)。
//

import Testing
@testable import irodori

@MainActor
struct PhoneAuthViewModelTests {

    private func format(_ input: String) -> String {
        let viewModel = PhoneAuthViewModel()
        viewModel.formatPhoneNumberText(input)
        return viewModel.phoneNumberText
    }

    @Test("+81 形式のペーストは 0 始まりの国内形式に正規化される")
    func normalizesPastedInternationalFormat() {
        #expect(format("+819012345678") == "090-1234-5678")
        #expect(format("+81 90-1234-5678") == "090-1234-5678")
        #expect(format("81 80 9876 5432") == "080-9876-5432")
    }

    @Test("トランクの 0 を残した +81 表記でも 0 を重ねない")
    func normalizesInternationalFormatKeepingTrunkZero() {
        #expect(format("+81 090-1234-5678") == "090-1234-5678")
        #expect(format("8109012345678") == "090-1234-5678")
    }

    @Test("通常の国内形式はそのまま 3-4-4 に整形される")
    func formatsDomesticNumber() {
        #expect(format("09012345678") == "090-1234-5678")
        #expect(format("090-1234-5678") == "090-1234-5678")
    }

    @Test("入力途中は入力分だけ整形される")
    func formatsPartialInput() {
        #expect(format("090") == "090")
        #expect(format("0901234") == "090-1234")
    }

    @Test("81 始まりでも 11 桁以下は国内番号として扱い正規化しない")
    func keepsElevenDigitNumbersStartingWith81() {
        #expect(format("81123456789") == "811-2345-6789")
    }

    @Test("11 桁を超える入力は切り詰められる")
    func truncatesOverlongInput() {
        #expect(format("090123456789999") == "090-1234-5678")
    }

    @Test("+81 ペースト後の番号はバリデーションを通る")
    func pastedNumberPassesValidation() {
        let viewModel = PhoneAuthViewModel()
        viewModel.formatPhoneNumberText("+819012345678")
        #expect(viewModel.isPhoneNumberValid)
    }
}
