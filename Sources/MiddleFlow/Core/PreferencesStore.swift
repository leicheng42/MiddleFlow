import Foundation

struct AppPaths {
    let supportDirectory: URL
    let preferencesURL: URL
    let statusURL: URL
    let logURL: URL

    static let live: AppPaths = {
        let base = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/MiddleFlow", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return AppPaths(
            supportDirectory: base,
            preferencesURL: base.appendingPathComponent("preferences.json"),
            statusURL: base.appendingPathComponent("status.json"),
            logURL: base.appendingPathComponent("diagnostics.log")
        )
    }()
}

final class PreferencesStore {
    private let url: URL
    private let queue = DispatchQueue(label: "com.leicheng.middleflow.preferences")

    init(url: URL = AppPaths.live.preferencesURL) {
        self.url = url
    }

    func load() -> AppPreferences {
        guard let data = try? Data(contentsOf: url),
              let preferences = try? JSONDecoder().decode(AppPreferences.self, from: data)
        else {
            return .defaults
        }
        return preferences
    }

    func save(_ preferences: AppPreferences) {
        queue.async { [url] in
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            guard let data = try? encoder.encode(preferences) else { return }
            try? data.write(to: url, options: .atomic)
        }
    }
}
