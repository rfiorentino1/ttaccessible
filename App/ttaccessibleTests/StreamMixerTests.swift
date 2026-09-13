//
//  StreamMixerTests.swift
//  ttaccessibleTests
//
//  Streaming devices and applications together mixes captures that each run on their own
//  clock. StreamMixer holds a cushion per source and follows each clock by nudging its
//  rate, instead of dropping or padding audio. These pin that: a source at the mix's own
//  rate passes through bit for bit, sources add and clip rather than wrap, a source
//  running fast or slow is followed without a single dropout, bursts are ridden out, a big
//  burst is cut back once, and a stalled source goes silent and is picked up again.
//

import XCTest
@testable import ttaccessible

final class StreamMixerTests: XCTestCase {

    /// A capture that grows by hand, one beat at a time.
    private final class FakeInput: StreamMixerInput {
        private(set) var samples: [Int16] = []
        var liveEdge: UInt64 { UInt64(samples.count / StreamMixer.channels) }

        func append(frames: Int, _ value: (Int) -> Int16) {
            let start = Int(liveEdge)
            for frame in start ..< start + frames {
                let sample = value(frame)
                samples.append(sample)
                samples.append(sample)
            }
        }

        func read(from cursor: UInt64, maxFrames: Int) -> ([Int16], Int, UInt64) {
            let edge = liveEdge
            guard edge > cursor, maxFrames > 0 else { return ([], 0, cursor) }
            let frames = min(maxFrames, Int(edge - cursor))
            let start = Int(cursor) * StreamMixer.channels
            return (Array(samples[start ..< start + frames * StreamMixer.channels]),
                    frames, cursor + UInt64(frames))
        }
    }

    private let beat = 480  // 10 ms at 48 kHz

    /// Runs `beats` mixes, calling `feed` before each; returns every mixed frame's left sample.
    private func run(_ mixer: StreamMixer, beats: Int, feed: (Int) -> Void) -> [Int16] {
        var left: [Int16] = []
        var block: [Int16] = []
        for index in 0 ..< beats {
            feed(index)
            mixer.mix(frames: beat, into: &block)
            for frame in 0 ..< beat {
                left.append(block[frame * StreamMixer.channels])
            }
        }
        return left
    }

    func testASourceAtTheMixRatePassesThroughBitForBit() {
        let input = FakeInput()
        let mixer = StreamMixer(inputs: [input])
        let out = run(mixer, beats: 50) { _ in input.append(frames: self.beat) { Int16($0 % 30_000) } }
        // Once the cushion is built, each frame is the next input frame: a ramp stays a ramp.
        let playing = Array(out.drop(while: { $0 == 0 }))
        XCTAssertGreaterThan(playing.count, 30 * beat)
        let breaks = zip(playing, playing.dropFirst()).filter { Int($1) != Int($0) + 1 }.count
        XCTAssertEqual(breaks, 0)
        XCTAssertEqual(mixer.stats(ofSource: 0).ratio, 1)
    }

    func testSourcesAddUp() {
        let a = FakeInput(), b = FakeInput()
        let mixer = StreamMixer(inputs: [a, b])
        let out = run(mixer, beats: 20) { _ in
            a.append(frames: self.beat) { _ in 1_000 }
            b.append(frames: self.beat) { _ in 2_000 }
        }
        XCTAssertEqual(out.last, 3_000)
    }

    func testAFullScaleSumClipsInsteadOfWrapping() {
        let a = FakeInput(), b = FakeInput()
        let mixer = StreamMixer(inputs: [a, b])
        let out = run(mixer, beats: 20) { _ in
            a.append(frames: self.beat) { _ in 30_000 }
            b.append(frames: self.beat) { _ in 30_000 }
        }
        XCTAssertEqual(out.last, 32_767)
    }

    func testASourceRunningFastIsFollowedWithoutADropout() {
        let input = FakeInput()
        let mixer = StreamMixer(inputs: [input])
        // One extra frame per beat: about 2 000 ppm fast, far worse than any real device.
        let out = run(mixer, beats: 3_000) { _ in input.append(frames: self.beat + 1) { _ in 1_000 } }
        let stats = mixer.stats(ofSource: 0)
        XCTAssertEqual(stats.underruns, 0)
        XCTAssertEqual(stats.skips, 0)
        XCTAssertGreaterThan(stats.ratio, 1.001)
        XCTAssertLessThan(stats.fill, Double(StreamMixer.overrunFrames))
        XCTAssertTrue(out.suffix(2_000 * beat).allSatisfy { $0 == 1_000 }, "no frame lost or padded")
    }

    func testASourceRunningSlowIsFollowedWithoutADropout() {
        let input = FakeInput()
        let mixer = StreamMixer(inputs: [input])
        let out = run(mixer, beats: 3_000) { _ in input.append(frames: self.beat - 1) { _ in 1_000 } }
        let stats = mixer.stats(ofSource: 0)
        XCTAssertEqual(stats.underruns, 0)
        XCTAssertEqual(stats.skips, 0)
        XCTAssertLessThan(stats.ratio, 0.999)
        XCTAssertTrue(out.suffix(2_000 * beat).allSatisfy { $0 == 1_000 }, "no frame lost or padded")
    }

    func testBurstsAreRiddenOut() {
        let input = FakeInput()
        let mixer = StreamMixer(inputs: [input])
        // 30 ms at a time, every third beat — how a bursty backend delivers.
        let out = run(mixer, beats: 600) { index in
            if index % 3 == 0 { input.append(frames: 3 * self.beat) { _ in 1_000 } }
        }
        XCTAssertEqual(mixer.stats(ofSource: 0).underruns, 0)
        XCTAssertTrue(out.suffix(500 * beat).allSatisfy { $0 == 1_000 })
    }

    func testABigBurstIsCutBackToTheCushionOnce() {
        let input = FakeInput()
        let mixer = StreamMixer(inputs: [input])
        let out = run(mixer, beats: 200) { index in
            input.append(frames: self.beat + (index == 50 ? 20_000 : 0)) { _ in 1_000 }
        }
        let stats = mixer.stats(ofSource: 0)
        XCTAssertEqual(stats.skips, 1)
        XCTAssertEqual(stats.underruns, 0)
        XCTAssertTrue(out.suffix(100 * beat).allSatisfy { $0 == 1_000 })
    }

    func testAStalledSourceGoesSilentAndComesBack() {
        let input = FakeInput()
        let mixer = StreamMixer(inputs: [input])
        let out = run(mixer, beats: 100) { index in
            if (40 ..< 60).contains(index) == false {
                input.append(frames: self.beat) { _ in 1_000 }
            }
        }
        XCTAssertEqual(mixer.stats(ofSource: 0).underruns, 1)
        XCTAssertTrue(out[(50 * beat) ..< (60 * beat)].allSatisfy { $0 == 0 }, "silent while stalled")
        XCTAssertTrue(out.suffix(20 * beat).allSatisfy { $0 == 1_000 }, "playing again")
    }
}
