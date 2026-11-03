import AppKit
import ApplicationServices

enum PermissionCenter {
    static var accessibilityGranted: Bool {
        AXIsProcessTrusted()
    }

    static var canPostEvents: Bool {
        CGPreflightPostEventAccess()
    }

    static func requestAccessibility() {
        let options = [
            kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true
        ] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    static func openAccessibilitySettings() {
        openPrivacyPane(anchor: "Privacy_Accessibility")
    }

    static func openInputMonitoringSettings() {
        openPrivacyPane(anchor: "Privacy_ListenEvent")
    }

    private static func openPrivacyPane(anchor: String) {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)"
        ) else { return }
        NSWorkspace.shared.open(url)
    }
}
