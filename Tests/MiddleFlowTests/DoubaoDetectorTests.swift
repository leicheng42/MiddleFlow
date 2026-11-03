import XCTest
@testable import MiddleFlow

final class DoubaoDetectorTests: XCTestCase {
    func testMissingState() {
        let status = DoubaoInstallationStatus()
        XCTAssertEqual(status.readiness, .missing)
        XCTAssertFalse(status.isReady)
    }

    func testInstalledButNotRegistered() {
        let status = DoubaoInstallationStatus(
            installed: true,
            registered: false,
            selected: false
        )
        XCTAssertEqual(status.readiness, .installedNotRegistered)
    }

    func testRegisteredButNotSelected() {
        let status = DoubaoInstallationStatus(
            installed: true,
            registered: true,
            selected: false
        )
        XCTAssertEqual(status.readiness, .registeredNotSelected)
    }

    func testReady() {
        let status = DoubaoInstallationStatus(
            installed: true,
            registered: true,
            selected: true,
            version: "1.0.3"
        )
        XCTAssertEqual(status.readiness, .ready)
        XCTAssertTrue(status.isReady)
    }
}
