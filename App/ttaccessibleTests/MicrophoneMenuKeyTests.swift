//
//  MicrophoneMenuKeyTests.swift
//  ttaccessibleTests
//
//  ⌘⇧A toggles the microphone from a key monitor instead of through the menu, because a
//  menu key equivalent makes VoiceOver say the item's title ("Toggle microphone") first.
//  The monitor must fire on exactly the chord the menu item carries and nothing else, or it
//  would steal a neighbouring shortcut (⌘A, ⌥⌘A) or miss the real one.
//

import AppKit
import XCTest
@testable import ttaccessible

@MainActor
final class MicrophoneMenuKeyTests: XCTestCase {

    private func key(_ characters: String, _ modifiers: NSEvent.ModifierFlags) -> NSEvent {
        NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: modifiers,
                         timestamp: 0, windowNumber: 0, context: nil,
                         characters: characters, charactersIgnoringModifiers: characters,
                         isARepeat: false, keyCode: 0)!
    }

    private func item(_ equivalent: String, _ mask: NSEvent.ModifierFlags) -> NSMenuItem {
        let item = NSMenuItem(title: "Toggle microphone", action: nil, keyEquivalent: equivalent)
        item.keyEquivalentModifierMask = mask
        return item
    }

    func testCommandShiftAMatchesALowercaseEquivalentWithShift() {
        XCTAssertTrue(AppDelegate.event(key("A", [.command, .shift]),
                                        matchesKeyEquivalentOf: item("a", [.command, .shift])))
    }

    func testAnUppercaseEquivalentImpliesShift() {
        XCTAssertTrue(AppDelegate.event(key("A", [.command, .shift]),
                                        matchesKeyEquivalentOf: item("A", [.command])))
    }

    func testNeighbouringChordsAreLeftAlone() {
        let menu = item("a", [.command, .shift])
        XCTAssertFalse(AppDelegate.event(key("a", [.command]), matchesKeyEquivalentOf: menu), "⌘A is Select All")
        XCTAssertFalse(AppDelegate.event(key("a", [.command, .option]), matchesKeyEquivalentOf: menu), "⌥⌘A streams audio")
        XCTAssertFalse(AppDelegate.event(key("A", [.command, .shift, .option]), matchesKeyEquivalentOf: menu))
        XCTAssertFalse(AppDelegate.event(key("B", [.command, .shift]), matchesKeyEquivalentOf: menu))
    }

    func testCapsLockDoesNotChangeTheChord() {
        XCTAssertTrue(AppDelegate.event(key("A", [.command, .shift, .capsLock]),
                                        matchesKeyEquivalentOf: item("a", [.command, .shift])))
    }

    func testAnItemWithoutAShortcutMatchesNothing() {
        XCTAssertFalse(AppDelegate.event(key("A", [.command, .shift]),
                                         matchesKeyEquivalentOf: item("", [])))
    }

    // The AppKit item can carry the global hotkey's chord (measured: ⌥⌘M in the test host)
    // while SwiftUI still fires it on ⌘⇧A. Matching only the item's chord is what let the
    // menu speak "Toggle microphone" anyway.

    func testCommandShiftAStillMatchesWhenTheItemWasRebound() {
        XCTAssertTrue(AppDelegate.isMicrophoneToggleChord(key("A", [.command, .shift]),
                                                          menuItem: item("m", [.command, .option])))
    }

    func testCommandShiftAMatchesEvenWithoutTheItem() {
        XCTAssertTrue(AppDelegate.isMicrophoneToggleChord(key("A", [.command, .shift]), menuItem: nil))
    }

    func testTheReboundChordMatchesToo() {
        XCTAssertTrue(AppDelegate.isMicrophoneToggleChord(key("m", [.command, .option]),
                                                          menuItem: item("m", [.command, .option])))
    }

    func testOtherChordsStayWithTheirOwners() {
        let rebound = item("m", [.command, .option])
        XCTAssertFalse(AppDelegate.isMicrophoneToggleChord(key("a", [.command]), menuItem: rebound))
        XCTAssertFalse(AppDelegate.isMicrophoneToggleChord(key("a", [.command, .option]), menuItem: rebound))
        XCTAssertFalse(AppDelegate.isMicrophoneToggleChord(key("m", [.command]), menuItem: rebound))
    }
}
