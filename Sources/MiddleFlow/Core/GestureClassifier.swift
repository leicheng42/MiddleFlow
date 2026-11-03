import Foundation

enum MiddleClickGesture: Equatable {
    case pendingSingle
    case doubleClick
}

struct GestureClassifier {
    var interval: TimeInterval
    var maxDistance: CGFloat
    private var recentClicks: [TimeInterval] = []
    private var lastPoint: CGPoint?

    var pendingClickCount: Int {
        recentClicks.count
    }

    init(interval: TimeInterval = 0.28, maxDistance: CGFloat = 90) {
        self.interval = interval
        self.maxDistance = maxDistance
    }

    mutating func ingest(
        at timestamp: TimeInterval,
        point: CGPoint = .zero
    ) -> MiddleClickGesture {
        recentClicks.removeAll { timestamp - $0 > interval }
        if let lastPoint,
           hypot(point.x - lastPoint.x, point.y - lastPoint.y) > maxDistance {
            recentClicks.removeAll()
        }
        recentClicks.append(timestamp)
        lastPoint = point
        if recentClicks.count >= 2 {
            recentClicks.removeAll()
            lastPoint = nil
            return .doubleClick
        }
        return .pendingSingle
    }

    mutating func reset() {
        recentClicks.removeAll()
        lastPoint = nil
    }
}
