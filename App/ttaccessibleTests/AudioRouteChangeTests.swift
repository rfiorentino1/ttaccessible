//
//  AudioRouteChangeTests.swift
//  ttaccessibleTests
//
//  After coreaudiod restarted, every device came back with the same UID but a new
//  object ID (measured: the input went from 93 to 728), the snapshot compared only
//  UIDs, and the output stayed silent. The same held for unplugging and replugging
//  the chosen output: the check meant for it read an emptied catalog as "still there".
//

import XCTest
@testable import ttaccessible

final class AudioRouteChangeTests: XCTestCase {

    private let audient = "AppleUSBAudioEngine:Audient:Audient iD44:100000:1,2"
    private let speakers = "BuiltInSpeakerDevice"

    private func snapshot(
        input: String? = "BlackHole_UID", inputID: UInt32? = 93,
        output: String?, outputID: UInt32?
    ) -> AudioRoutingSnapshot {
        AudioRoutingSnapshot(
            resolvedInputUID: input,
            defaultInputUID: input,
            defaultOutputUID: output,
            preferredOutputPersistentID: audient,
            outputPersistentIDInCatalog: true,
            activeInputSampleRate: 48_000,
            inputDeviceObjectID: inputID,
            outputEngineDeviceUID: output,
            outputEngineDeviceObjectID: outputID
        )
    }

    private func wentAway(_ a: AudioRoutingSnapshot, _ b: AudioRoutingSnapshot,
                          outputOpen: Bool = true, inputOpen: Bool = true) -> Bool {
        TeamTalkConnectionController.openDeviceWentAway(
            previous: a, current: b, outputOpen: outputOpen, inputOpen: inputOpen
        )
    }

    func testNothingChangedIsNotARouteChange() {
        let s = snapshot(output: audient, outputID: 120)
        XCTAssertFalse(wentAway(s, s))
    }

    func testCoreAudioRestartReopensTheOutput() {
        XCTAssertTrue(wentAway(
            snapshot(output: audient, outputID: 120),
            snapshot(output: audient, outputID: 731)
        ))
    }

    func testCoreAudioRestartReopensALiveMicrophone() {
        XCTAssertTrue(wentAway(
            snapshot(inputID: 93, output: audient, outputID: 120),
            snapshot(inputID: 728, output: audient, outputID: 120)
        ))
    }

    func testUnpluggingTheChosenOutputMovesToTheFallback() {
        XCTAssertTrue(wentAway(
            snapshot(output: audient, outputID: 120),
            snapshot(output: speakers, outputID: 45)
        ))
    }

    func testPluggingItBackMovesBack() {
        XCTAssertTrue(wentAway(
            snapshot(output: speakers, outputID: 45),
            snapshot(output: audient, outputID: 740)
        ))
    }

    func testAClosedOutputIsNotReopened() {
        XCTAssertFalse(wentAway(
            snapshot(output: audient, outputID: 120),
            snapshot(output: audient, outputID: 731),
            outputOpen: false, inputOpen: false
        ))
    }

    func testAnIdleMicrophoneDeviceIsNotAReason() {
        XCTAssertFalse(wentAway(
            snapshot(inputID: 93, output: audient, outputID: 120),
            snapshot(inputID: 728, output: audient, outputID: 120),
            inputOpen: false
        ))
    }

    func testNoOutputChosenIgnoresOutputDevices() {
        let s = snapshot(output: nil, outputID: nil)
        XCTAssertFalse(wentAway(s, s))
    }
}
