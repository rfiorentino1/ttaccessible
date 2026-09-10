//
//  PressActionTextFieldTests.swift
//  ttaccessibleTests
//
//  The channel tree sets each row's tooltip to its full accessibility label, so a
//  truncated row can be read with the mouse. VoiceOver reads a tooltip as help, so
//  every row was spoken twice — a long channel topic most noticeably. Tree rows now
//  keep the tooltip for the eye and drop it for VoiceOver; everything else that uses
//  the field keeps the default.
//

import XCTest
@testable import ttaccessible

@MainActor
final class PressActionTextFieldTests: XCTestCase {

    private let rowText = "The lazy Lounge (3/3), current channel, Topic: come in and relax"

    /// Proves the override sits on the path VoiceOver uses: by default the tooltip
    /// really does come back as help. If this ever fails, the fix below is inert.
    func testATooltipIsSpokenAsHelpByDefault() {
        let field = PressActionTextField(labelWithString: "Lounge")
        field.toolTip = rowText
        XCTAssertEqual(field.accessibilityHelp(), rowText)
    }

    func testATreeRowIsNotSpokenTwice() {
        let field = PressActionTextField(labelWithString: "Lounge")
        field.toolTip = rowText
        field.speaksToolTipAsHelp = false
        field.setAccessibilityLabel(rowText)
        XCTAssertNil(field.accessibilityHelp())
        XCTAssertEqual(field.accessibilityLabel(), rowText)
    }

    func testTheMouseKeepsItsTooltip() {
        let field = PressActionTextField(labelWithString: "Lounge")
        field.toolTip = rowText
        field.speaksToolTipAsHelp = false
        XCTAssertEqual(field.toolTip, rowText)
    }
}
