//
//  AudioGainControlViewTests.swift
//  ttaccessibleTests
//
//  The window's global level sliders — output, input, sound effects, media — move
//  through the same MixerLevelMove table the mixer's own keys use, so a level travels
//  the same distance whichever route reaches it. Before that, this view's keyDown had
//  Home going to 0 % and End to 100 %, the opposite of the mixer, and nothing caught it.
//

import XCTest
@testable import ttaccessible

@MainActor
final class AudioGainControlViewTests: XCTestCase {

    private func makeControl() -> AudioGainControlView {
        AudioGainControlView(title: "Output", accessibilityLabel: "Output") { _ in }
    }

    func testHomeGoesToTheTopAndEndToTheBottom() {
        let control = makeControl()
        XCTAssertEqual(control.apply(.toMax), "100%")
        XCTAssertEqual(control.apply(.toMin), "0%")
    }

    func testArrowMovesOnePercentAndPageMovesTen() {
        let control = makeControl()
        control.setValue(0)                       // unity == 50 %
        XCTAssertEqual(control.apply(.step(up: true)), "51%")
        XCTAssertEqual(control.apply(.step(up: false)), "50%")
        XCTAssertEqual(control.apply(.page(up: true)), "60%")
        XCTAssertEqual(control.apply(.page(up: false)), "50%")
    }

    func testMovesClampAtTheEnds() {
        let control = makeControl()
        control.apply(.toMax)
        XCTAssertEqual(control.apply(.step(up: true)), "100%")
        control.apply(.toMin)
        XCTAssertEqual(control.apply(.step(up: false)), "0%")
    }

    func testTheChangeHandlerSeesEveryMove() {
        var seen: [Double] = []
        let control = AudioGainControlView(title: "Output", accessibilityLabel: "Output") { seen.append($0) }
        control.apply(.toMax)
        control.apply(.toMin)
        XCTAssertEqual(seen, [24, -24])           // the ends of the -24…+24 dB scale
    }
}
