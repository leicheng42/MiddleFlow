import Foundation
import os

final class Diagnostics {
    private let logURL: URL
    private let queue = DispatchQueue(label: "com.leicheng.middleflow.diagnostics")
    private let logger = Logger(subsystem: "com.leicheng.middleflow", category: "runtime")
    private let formatter: ISO8601DateFormatter

    init(logURL: URL = AppPaths.live.logURL) {
        self.logURL = logURL
        formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    }

    func write(_ message: String) {
        logger.info("\(message, privacy: .public)")
        queue.async { [logURL, formatter] in
            let line = "\(formatter.string(from: Date())) \(message)\n"
            if !FileManager.default.fileExists(atPath: logURL.path) {
                FileManager.default.createFile(atPath: logURL.path, contents: nil)
            }
            guard let handle = try? FileHandle(forWritingTo: logURL) else { return }
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: Data(line.utf8))
        }
    }

    func tail(maxLines: Int = 120) -> String {
        guard let text = try? String(contentsOf: logURL, encoding: .utf8) else { return "" }
        return text.split(separator: "\n", omittingEmptySubsequences: false)
            .suffix(maxLines)
            .joined(separator: "\n")
    }
}
