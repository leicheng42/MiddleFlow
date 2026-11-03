import Foundation

struct ComposerTarget: Codable, Identifiable, Equatable {
    var bundleID: String
    var name: String

    var id: String { bundleID }
}

enum TargetBehavior: Equatable {
    case composer
    case directShortcut
}

enum TargetPolicy {
    static let uuRemoteBundleID = "com.netease.uuremote"
    static let knownComposerTargets: [ComposerTarget] = [
        ComposerTarget(bundleID: uuRemoteBundleID, name: "UU Remote")
    ]

    static func behavior(
        for bundleID: String?,
        composerBundleIDs: Set<String>
    ) -> TargetBehavior {
        guard let bundleID, !bundleID.isEmpty else { return .directShortcut }
        return composerBundleIDs.contains(bundleID) ? .composer : .directShortcut
    }

    static func displayName(for bundleID: String) -> String {
        knownComposerTargets.first(where: { $0.bundleID == bundleID })?.name ?? bundleID
    }
}
