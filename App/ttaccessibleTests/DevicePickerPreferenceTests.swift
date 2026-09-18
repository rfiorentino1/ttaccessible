//
//  DevicePickerPreferenceTests.swift
//  ttaccessibleTests
//
//  With the Audio pane open, unplugging the chosen output left its picker with no
//  row for it, so the picker showed System Default and saved that as the choice.
//  Plugged back in, the Audient stayed unused: the app no longer wanted it.
//

import XCTest
@testable import ttaccessible

final class DevicePickerPreferenceTests: XCTestCase {

    private let audient = AudioDeviceOption(id: "audient", persistentID: "audient", displayName: "Audient iD44")
    private let speakers = AudioDeviceOption(id: "speakers", persistentID: "speakers", displayName: "Mac Studio Speakers")
    private let savedAudient = AudioDevicePreference(persistentID: "audient", displayName: "Audient iD44")
    private let defaultTag = "__system_default__"

    private func resolve(_ pickerID: String, saved: AudioDevicePreference, devices: [AudioDeviceOption]) -> AudioDevicePreference {
        AudioPreferencesStore.preference(forPickerID: pickerID, saved: saved, devices: devices)
    }

    /// The case that lost the choice: device gone, picker falls back to System Default.
    func testAMissingDeviceKeepsItsSavedChoice() {
        XCTAssertEqual(AudioPreferencesStore.selectionID(for: savedAudient, devices: [speakers]), defaultTag)
        XCTAssertEqual(resolve(defaultTag, saved: savedAudient, devices: [speakers]), savedAudient)
    }

    func testPickingSystemDefaultOnPurposeStillSavesIt() {
        XCTAssertEqual(resolve(defaultTag, saved: savedAudient, devices: [audient, speakers]), .systemDefault)
    }

    func testPickingAnotherDeviceSavesIt() {
        XCTAssertEqual(
            resolve("speakers", saved: savedAudient, devices: [audient, speakers]),
            AudioDevicePreference(persistentID: "speakers", displayName: "Mac Studio Speakers")
        )
    }

    func testAnUnchangedPickerKeepsItsChoice() {
        XCTAssertEqual(resolve("audient", saved: savedAudient, devices: [audient, speakers]), savedAudient)
    }
}
