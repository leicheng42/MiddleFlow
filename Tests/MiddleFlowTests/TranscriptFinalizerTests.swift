import XCTest
@testable import MiddleFlow

final class TranscriptFinalizerTests: XCTestCase {
    func testWaitsForStableText() {
        XCTAssertEqual(
            TranscriptFinalizer.decide(text: "你好", elapsed: 0.10, stableFor: 0.10),
            .wait
        )
        XCTAssertEqual(
            TranscriptFinalizer.decide(text: "你好", elapsed: 0.21, stableFor: 0.05),
            .wait
        )
    }

    func testFinishesWhenTextIsStableEvenIfIMEMarkedTextPersists() {
        XCTAssertEqual(
            TranscriptFinalizer.decide(text: "你好，世界", elapsed: 0.20, stableFor: 0.12),
            .finish
        )
    }

    func testFallbackFinishesNonEmptyTextAfterShortTimeout() {
        XCTAssertEqual(
            TranscriptFinalizer.decide(text: "持续变化的文字", elapsed: 1.20, stableFor: 0.01),
            .finish
        )
    }

    func testEmptyTranscriptFailsAfterFallback() {
        XCTAssertEqual(
            TranscriptFinalizer.decide(text: "   \n", elapsed: 2.50, stableFor: 2.50),
            .empty
        )
    }

    func testEmptyTextWaitsLongerThanNonEmptyFallback() {
        XCTAssertEqual(
            TranscriptFinalizer.decide(text: "", elapsed: 1.20, stableFor: 1.20),
            .wait
        )
    }
}
