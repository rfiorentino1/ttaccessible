//
//  DeviceStreamCaptureSpecTests.swift
//  ttaccessibleTests
//
//  The stream-source picker saves what you picked as one token and rebuilds the
//  selection from it next time. Several applications — VoiceOver counts as one —
//  fuse into a single "multi:" token; a device or all-system audio never fuses.
//  None of that had a test, and it is the whole of "your last choice is ticked
//  again next time".
//

import XCTest
@testable import ttaccessible

final class DeviceStreamCaptureSpecTests: XCTestCase {

    private let music = DeviceStreamCaptureSpec.application(bundleID: "com.apple.Music", displayName: "Music")
    private let safari = DeviceStreamCaptureSpec.application(bundleID: "com.apple.Safari", displayName: "Safari")

    func testNothingToStreamMergesToNil() {
        XCTAssertNil(DeviceStreamCaptureSpec.merging([]))
    }

    func testASingleApplicationIsReturnedUnchanged() {
        XCTAssertEqual(DeviceStreamCaptureSpec.merging([music]), music)
    }

    func testSeveralApplicationsFuseIntoOneMultiToken() {
        let merged = DeviceStreamCaptureSpec.merging([music, .voiceOver()])
        XCTAssertEqual(merged?.persistenceToken, "multi:app:com.apple.Music+voiceover")
    }

    func testAFusedSelectionCapturesEachPrefixOnce() {
        guard case .processes(let selection)? = DeviceStreamCaptureSpec.merging([music, safari, music]) else {
            return XCTFail("expected a process selection")
        }
        XCTAssertEqual(selection.bundleIDPrefixes, ["com.apple.Music", "com.apple.Safari"])
    }

    func testAllSystemAudioNeverFuses() {
        XCTAssertNil(DeviceStreamCaptureSpec.merging([.systemAudio()]))
        XCTAssertEqual(DeviceStreamCaptureSpec.merging([.systemAudio(), music]), music)
    }

    func testAMultiTokenSplitsBackIntoItsParts() {
        XCTAssertEqual(DeviceStreamCaptureSpec.componentTokens(of: "multi:app:com.apple.Music+voiceover"),
                       ["app:com.apple.Music", "voiceover"])
    }

    func testAPlainTokenIsItsOwnOnlyPart() {
        XCTAssertEqual(DeviceStreamCaptureSpec.componentTokens(of: "voiceover"), ["voiceover"])
        XCTAssertEqual(DeviceStreamCaptureSpec.componentTokens(of: "device:BuiltInMic"), ["device:BuiltInMic"])
        XCTAssertEqual(DeviceStreamCaptureSpec.componentTokens(of: "system"), ["system"])
    }

    func testFusingThenSplittingGivesBackEverySourceInOrder() {
        let picked = [music, .voiceOver(), safari]
        let token = DeviceStreamCaptureSpec.merging(picked)?.persistenceToken ?? ""
        XCTAssertEqual(DeviceStreamCaptureSpec.componentTokens(of: token), picked.map(\.persistenceToken))
    }
}
