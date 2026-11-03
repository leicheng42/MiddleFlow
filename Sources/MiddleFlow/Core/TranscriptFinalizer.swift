import Foundation

enum TranscriptFinalizationDecision: Equatable {
    case wait
    case finish
    case empty
}

enum TranscriptFinalizer {
    static let minimumElapsed: TimeInterval = 0.20
    static let stabilityWindow: TimeInterval = 0.12
    static let fallbackTimeout: TimeInterval = 1.20
    static let emptyTimeout: TimeInterval = 2.50

    static func decide(
        text: String,
        elapsed: TimeInterval,
        stableFor: TimeInterval
    ) -> TranscriptFinalizationDecision {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty,
           elapsed >= minimumElapsed,
           stableFor >= stabilityWindow {
            return .finish
        }
        if elapsed >= fallbackTimeout {
            if !trimmed.isEmpty { return .finish }
        }
        if elapsed >= emptyTimeout {
            return .empty
        }
        return .wait
    }
}
