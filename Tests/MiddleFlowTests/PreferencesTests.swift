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
        XCTAssertEqual(preferences.composerDoubleClickInterval, 0.32, accuracy: 0.001)
        XCTAssertFalse(preferences.restoreClipboardAfterPaste)
    }

    func testClipboardRetentionMigrationRunsOnce() {
        var preferences = AppPreferences.defaults
        preferences.restoreClipboardAfterPaste = true
        preferences.clipboardRetentionMigrationCompleted = nil

        XCTAssertTrue(preferences.applyClipboardRetentionMigrationIfNeeded())
        XCTAssertFalse(preferences.restoreClipboardAfterPaste)
        XCTAssertEqual(preferences.clipboardRetentionMigrationCompleted, true)

        preferences.restoreClipboardAfterPaste = true
        XCTAssertFalse(preferences.applyClipboardRetentionMigrationIfNeeded())
        XCTAssertTrue(preferences.restoreClipboardAfterPaste)
    }
}
