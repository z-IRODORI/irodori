//
//  CoachTourTests.swift
//  irodoriTests
//
//  初めてのホームのツアー: 操作を待たずに始まり、画面に無い部品は飛ばし、
//  カメラの案内は「撮ってみる」を選んだときだけ続けて出す (あとで画面を開いたときに急に出さない)。
//

import Foundation
import Testing
@testable import irodori

@MainActor
@Suite(.serialized)
struct CoachTourTests {
    private let center = CoachMarkCenter.shared
    private let box = CGRect(x: 20, y: 200, width: 300, height: 120)

    /// 新しく相棒が生まれた人と同じ状態。ホームの部品の位置は引数で決める
    private func fresh(frames: [CoachTarget]) {
        center.resetForDebug()
        center.frames = [:]
        for t in frames { center.frames[t] = box }
    }

    @Test("ホームが開いたら、操作を待たずに相棒のひとことからツアーが始まる")
    func startsOnHomeReady() {
        fresh(frames: [.partner, .recipes, .growth])
        center.homeReady()
        #expect(center.tourStep == 0)
        #expect(center.current?.target == .partner)
        center.next()
        #expect(center.current?.target == .recipes)
        center.next()
        #expect(center.current?.target == .growth)
        center.next()
        #expect(center.current?.target == .camera)
        #expect(center.isLastTourStep)
        center.skipTour()
    }

    @Test("3案がまだ画面に無ければ、その説明を飛ばして進む")
    func skipsMissingTargets() {
        fresh(frames: [.partner, .growth])
        center.homeReady()
        #expect(center.current?.target == .partner)
        center.next()
        #expect(center.current?.target == .growth)
        center.skipTour()
    }

    @Test("ホームの部品がまだ無ければ始めず、記録もしない (描かれてから呼ばれたら始まる)")
    func waitsUntilHomeIsDrawn() {
        fresh(frames: [])
        center.homeReady()
        #expect(center.current == nil && center.tourStep == nil)
        center.frames[.partner] = box
        center.homeReady()
        #expect(center.current?.target == .partner)
        center.skipTour()
    }

    @Test("ツアーを「あとで」で終えたら、あとでカメラを開いても案内は出ない")
    func cameraTourNotTriggeredLater() {
        fresh(frames: [.partner, .recipes, .growth, .cameraShutter, .cameraPicker])
        center.homeReady()
        center.skipTour()
        center.cameraOpened()
        #expect(center.current == nil)
        // 同じツアーは二度と出ない
        center.homeReady()
        #expect(center.current == nil)
    }

    @Test("最後に「撮ってみる」を選んだら、カメラ画面で撮り方の案内が続く")
    func cameraTourContinuesAfterTakePhoto() {
        fresh(frames: [.partner, .recipes, .growth, .cameraShutter, .cameraPicker])
        center.homeReady()
        center.next(); center.next(); center.next()
        #expect(center.current?.target == .camera)
        center.perform(.openCamera)
        #expect(center.pendingAction == .openCamera)
        center.pendingAction = nil
        center.cameraOpened()
        #expect(center.current?.target == .cameraShutter)
        center.next()
        #expect(center.current?.target == .cameraPicker)
        center.skipTour()
    }
}
