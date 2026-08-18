//
//  CameraEngineToggleUITests.swift
//  irodoriUITests
//
//  カメラ画面の解析エンジン切替トグル (DEBUG ビルド限定) の表示・切替を検証する。
//

import XCTest

final class CameraEngineToggleUITests: XCTestCase {

    @MainActor
    func testDebugEngineToggleVisibleAndTogglesOnCameraTab() throws {
        let app = XCUIApplication()
        app.launch()

        // タブバーの「カメラ」をタップ (iOS 18 Tab 構文でボタン解決が変わる場合に備えフォールバック)
        let cameraTab = app.tabBars.buttons["カメラ"]
        if cameraTab.waitForExistence(timeout: 10) {
            cameraTab.tap()
        } else {
            let fallback = app.buttons["カメラ"].firstMatch
            XCTAssertTrue(fallback.waitForExistence(timeout: 10), "カメラタブが見つからない")
            fallback.tap()
        }

        // トグルはカメラの接続状態 (準備中/未接続/接続済み) に関わらず表示される
        let toggle = app.buttons["debug-engine-toggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 10),
                      "カメラ画面に解析エンジントグルが表示されること")

        let before = toggle.label
        let shot1 = XCTAttachment(screenshot: app.screenshot())
        shot1.name = "camera-toggle-before"
        shot1.lifetime = .keepAlways
        add(shot1)

        // タップでラベルが切り替わる (既存 ⇄ v2)
        toggle.tap()
        let flipped = app.buttons["debug-engine-toggle"]
        XCTAssertTrue(flipped.waitForExistence(timeout: 5))
        XCTAssertNotEqual(flipped.label, before, "タップで解析エンジン表示が切り替わること")

        let shot2 = XCTAttachment(screenshot: app.screenshot())
        shot2.name = "camera-toggle-after"
        shot2.lifetime = .keepAlways
        add(shot2)

        // 後続テストの安定化のため元へ戻す
        flipped.tap()
    }
}
