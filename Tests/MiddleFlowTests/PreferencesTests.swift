import XCTest
@testable import MiddleFlow

final class PreferencesTests: XCTestCase {
    func testPreferencesRoundTrip() throws {
        var preferences = AppPreferences.defaults
        preferences.voiceShortcut = .function
        preferences.composerBundleIDs = ["com.example.remote"]
        preferences.pasteThenReturn = true

        let data = try JSONEncoder().encode(preferences)
        let decoded = try JSONDecoder().decode(AppPreferences.self, from: data)

        XCTAssertEqual(decoded, preferences)
    }

    func testDefaultsUseUUAndRightOption() {
        let preferences = AppPreferences.defaults
        XCTAssertEqual(preferences.voiceShortcut, .rightOption)
        XCTAssertTrue(preferences.composerBundleIDs.contains(TargetPolicy.uuRemoteBundleID))
    }
}
