import XCTest
@testable import MiddleFlow

final class TargetPolicyTests: XCTestCase {
    func testUUUsesComposer() {
        XCTAssertEqual(
            TargetPolicy.behavior(
                for: TargetPolicy.uuRemoteBundleID,
                composerBundleIDs: [TargetPolicy.uuRemoteBundleID]
            ),
            .composer
        )
    }

    func testUnknownBundleUsesDirectShortcut() {
        XCTAssertEqual(
            TargetPolicy.behavior(
                for: "com.example.editor",
                composerBundleIDs: [TargetPolicy.uuRemoteBundleID]
            ),
            .directShortcut
        )
    }

    func testMissingBundleUsesDirectShortcut() {
        XCTAssertEqual(
            TargetPolicy.behavior(for: nil, composerBundleIDs: []),
            .directShortcut
        )
    }
}
