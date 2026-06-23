//
//  PreferencesAndAudioMathTests.swift
//  ttaccessibleTests
//
//  POC unit tests for pure / deterministic logic:
//   - gain dB <-> percent curve (AudioGainControlView, AppPreferences.clampGainDB)
//   - user volume <-> percent piecewise-linear curve (TeamTalkConnectionController)
//   - Codable migrations of preference structs (legacy-key handling)
//
//  These cover regression-prone math and decoding. They do NOT touch AppKit UI,
//  CoreAudio, or the TeamTalk SDK runtime — those stay verified manually.
//

import XCTest
@testable import ttaccessible

// MARK: - Gain dB <-> percent curve

final class GainCurveTests: XCTestCase {

    func testPercentForGainDBAnchors() {
        XCTAssertEqual(AudioGainControlView.percent(forGainDB: -24), 0, accuracy: 0.001)
        XCTAssertEqual(AudioGainControlView.percent(forGainDB: 0), 50, accuracy: 0.001)
        XCTAssertEqual(AudioGainControlView.percent(forGainDB: 24), 100, accuracy: 0.001)
    }

    func testPercentForGainDBClampsOutOfRange() {
        XCTAssertEqual(AudioGainControlView.percent(forGainDB: -100), 0, accuracy: 0.001)
        XCTAssertEqual(AudioGainControlView.percent(forGainDB: 100), 100, accuracy: 0.001)
    }

    func testGainDBForPercentAnchors() {
        XCTAssertEqual(AudioGainControlView.gainDB(forPercent: 0), -24, accuracy: 0.001)
        XCTAssertEqual(AudioGainControlView.gainDB(forPercent: 50), 0, accuracy: 0.001)
        XCTAssertEqual(AudioGainControlView.gainDB(forPercent: 100), 24, accuracy: 0.001)
    }

    func testGainDBForPercentClampsOutOfRange() {
        XCTAssertEqual(AudioGainControlView.gainDB(forPercent: -10), -24, accuracy: 0.001)
        XCTAssertEqual(AudioGainControlView.gainDB(forPercent: 150), 24, accuracy: 0.001)
    }

    func testGainRoundTrip() {
        for percent in stride(from: 0.0, through: 100.0, by: 5.0) {
            let db = AudioGainControlView.gainDB(forPercent: percent)
            let back = AudioGainControlView.percent(forGainDB: db)
            XCTAssertEqual(back, percent, accuracy: 0.5, "round-trip failed at \(percent)%")
        }
    }

    func testFormatPercentClampsAndFormats() {
        XCTAssertEqual(AudioGainControlView.format(percent: 50), "50%")
        XCTAssertEqual(AudioGainControlView.format(percent: -5), "0%")
        XCTAssertEqual(AudioGainControlView.format(percent: 150), "100%")
        XCTAssertEqual(AudioGainControlView.format(percent: 49.6), "50%") // rounds up
    }
}

// MARK: - clampGainDB

final class ClampGainDBTests: XCTestCase {

    func testClampBounds() {
        XCTAssertEqual(AppPreferences.clampGainDB(-100), -24, accuracy: 0.0001)
        XCTAssertEqual(AppPreferences.clampGainDB(100), 24, accuracy: 0.0001)
        XCTAssertEqual(AppPreferences.clampGainDB(-24), -24, accuracy: 0.0001)
        XCTAssertEqual(AppPreferences.clampGainDB(24), 24, accuracy: 0.0001)
    }

    func testClampPassThroughInRange() {
        XCTAssertEqual(AppPreferences.clampGainDB(5), 5, accuracy: 0.0001)
        XCTAssertEqual(AppPreferences.clampGainDB(-12.5), -12.5, accuracy: 0.0001)
        XCTAssertEqual(AppPreferences.clampGainDB(0), 0, accuracy: 0.0001)
    }
}

// MARK: - User volume <-> percent piecewise-linear curve

final class UserVolumeCurveTests: XCTestCase {

    func testMonotonicNonDecreasing() {
        var last = Int32.min
        for p in stride(from: 0.0, through: 100.0, by: 1.0) {
            let v = TeamTalkConnectionController.userVolumeFromPercent(p)
            XCTAssertGreaterThanOrEqual(v, last, "volume curve not monotonic at \(p)%")
            last = v
        }
    }

    func testAnchorsAreOrdered() {
        let v0 = TeamTalkConnectionController.userVolumeFromPercent(0)
        let v50 = TeamTalkConnectionController.userVolumeFromPercent(50)
        let v100 = TeamTalkConnectionController.userVolumeFromPercent(100)
        XCTAssertLessThan(v0, v50, "0% should map below 50% (default)")
        XCTAssertLessThan(v50, v100, "50% (default) should map below 100% (max)")
    }

    func testPercentRoundTripAtAnchors() {
        let v0 = TeamTalkConnectionController.userVolumeFromPercent(0)
        let v50 = TeamTalkConnectionController.userVolumeFromPercent(50)
        let v100 = TeamTalkConnectionController.userVolumeFromPercent(100)
        XCTAssertEqual(TeamTalkConnectionController.percentFromUserVolume(v0), 0)
        XCTAssertEqual(TeamTalkConnectionController.percentFromUserVolume(v50), 50)
        XCTAssertEqual(TeamTalkConnectionController.percentFromUserVolume(v100), 100)
    }

    func testPercentClampsOutOfRange() {
        XCTAssertEqual(
            TeamTalkConnectionController.userVolumeFromPercent(-10),
            TeamTalkConnectionController.userVolumeFromPercent(0)
        )
        XCTAssertEqual(
            TeamTalkConnectionController.userVolumeFromPercent(150),
            TeamTalkConnectionController.userVolumeFromPercent(100)
        )
    }

    func testRoundTripApprox() {
        for p in stride(from: 0.0, through: 100.0, by: 5.0) {
            let v = TeamTalkConnectionController.userVolumeFromPercent(p)
            let back = TeamTalkConnectionController.percentFromUserVolume(v)
            XCTAssertEqual(Double(back), p, accuracy: 1.5, "volume round-trip failed at \(p)%")
        }
    }
}

// MARK: - Preference Codable migrations

@MainActor
final class PreferencesCodableTests: XCTestCase {

    private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        try JSONDecoder().decode(type, from: Data(json.utf8))
    }

    // VoiceOverAnnouncementPreferences: legacy `sessionHistoryEnabled` Bool -> disabledSessionHistoryKinds

    func testVoiceOverLegacyEnabledFalseDisablesAllAnnounceable() throws {
        let prefs = try decode(VoiceOverAnnouncementPreferences.self, #"{"sessionHistoryEnabled": false}"#)
        XCTAssertEqual(prefs.disabledSessionHistoryKinds, Set(SessionHistoryEntry.Kind.announceable))
        XCTAssertFalse(prefs.sessionHistoryEnabled)
    }

    func testVoiceOverLegacyEnabledTrueLeavesAllEnabled() throws {
        let prefs = try decode(VoiceOverAnnouncementPreferences.self, #"{"sessionHistoryEnabled": true}"#)
        XCTAssertTrue(prefs.disabledSessionHistoryKinds.isEmpty)
        XCTAssertTrue(prefs.sessionHistoryEnabled)
    }

    func testVoiceOverModernKeyRespected() throws {
        let prefs = try decode(VoiceOverAnnouncementPreferences.self,
                               #"{"disabledSessionHistoryKinds": ["connected","disconnected"]}"#)
        XCTAssertEqual(prefs.disabledSessionHistoryKinds, [.connected, .disconnected])
    }

    func testVoiceOverEmptyJSONUsesDefaults() throws {
        let prefs = try decode(VoiceOverAnnouncementPreferences.self, "{}")
        XCTAssertTrue(prefs.disabledSessionHistoryKinds.isEmpty)
        XCTAssertTrue(prefs.channelMessagesEnabled)
        XCTAssertTrue(prefs.privateMessagesEnabled)
        XCTAssertTrue(prefs.broadcastMessagesEnabled)
    }

    // AdvancedInputAudioPreferences: removed keys (gate/expander/limiter/isEnabled) must decode without crashing

    func testAdvancedInputAudioIgnoresRemovedLegacyKeys() throws {
        // Old saved prefs carried gate/expander/limiter/isEnabled keys (since removed).
        // Decoding must ignore them without throwing, keep modern keys, and fall back
        // to the default preset (.auto) when no preset is present.
        let json = #"{"isEnabled": true, "gate": {"threshold": -40}, "limiter": {"enabled": true}, "echoCancellationEnabled": true}"#
        let prefs = try decode(AdvancedInputAudioPreferences.self, json)
        XCTAssertTrue(prefs.echoCancellationEnabled)
        XCTAssertEqual(prefs.preset, .auto)
    }

    func testAdvancedInputAudioEmptyJSONUsesDefaults() throws {
        let prefs = try decode(AdvancedInputAudioPreferences.self, "{}")
        XCTAssertEqual(prefs.preset, .auto)
        XCTAssertFalse(prefs.echoCancellationEnabled)
    }
}
