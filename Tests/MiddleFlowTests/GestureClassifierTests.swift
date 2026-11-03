import XCTest
@testable import MiddleFlow

final class GestureClassifierTests: XCTestCase {
    func testSingleClick() {
        var classifier = GestureClassifier(interval: 0.28)
        XCTAssertEqual(classifier.ingest(at: 10), .pendingSingle)
    }

    func testDoubleClickInsideWindow() {
        var classifier = GestureClassifier(interval: 0.28)
        XCTAssertEqual(classifier.ingest(at: 10), .pendingSingle)
        XCTAssertEqual(classifier.ingest(at: 10.12), .doubleClick)
    }

    func testTwoClicksOutsideWindowAreTwoSingles() {
        var classifier = GestureClassifier(interval: 0.28)
        XCTAssertEqual(classifier.ingest(at: 10), .pendingSingle)
        XCTAssertEqual(classifier.ingest(at: 10.4), .pendingSingle)
    }

    func testTwoClicksFarApartAreTwoSingles() {
        var classifier = GestureClassifier(interval: 0.28, maxDistance: 50)
        XCTAssertEqual(
            classifier.ingest(at: 10, point: CGPoint(x: 10, y: 10)),
            .pendingSingle
        )
        XCTAssertEqual(
            classifier.ingest(at: 10.1, point: CGPoint(x: 120, y: 120)),
            .pendingSingle
        )
    }

    func testResetDropsPendingClick() {
        var classifier = GestureClassifier(interval: 0.28)
        _ = classifier.ingest(at: 10)
        classifier.reset()
        XCTAssertEqual(classifier.ingest(at: 10.1), .pendingSingle)
    }
}
