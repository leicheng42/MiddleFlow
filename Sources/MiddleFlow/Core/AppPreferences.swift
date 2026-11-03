import CoreGraphics
import Foundation

enum VoiceShortcut: String, Codable, CaseIterable, Identifiable {
    case rightOption
    case leftOption
    case function

    var id: String { rawValue }

    var title: String {
        switch self {
        case .rightOption: return "右侧 Option"
        case .leftOption: return "左侧 Option"
        case .function: return "Fn"
        }
    }

    var shortTitle: String {
        switch self {
        case .rightOption: return "Right Option"
        case .leftOption: return "Left Option"
        case .function: return "Fn"
        }
    }

    var keyCode: CGKeyCode {
        switch self {
        case .rightOption: return 61
        case .leftOption: return 58
        case .function: return 63
        }
    }
}

enum DoubleClickAction: String, Codable, CaseIterable, Identifiable {
    case returnKey
    case none

    var id: String { rawValue }

    var title: String {
        switch self {
        case .returnKey: return "按下 Return"
        case .none: return "不执行操作"
        }
    }
}

struct AppPreferences: Codable, Equatable {
    var mappingEnabled = true
    var doubleClickEnabled = true
    var doubleClickAction: DoubleClickAction = .returnKey
    var voiceShortcut: VoiceShortcut = .rightOption
    var autoPaste = true
    var pasteThenReturn = false
    var restoreClipboardAfterPaste = true
    var composerBundleIDs: Set<String> = [TargetPolicy.uuRemoteBundleID]
    var launchAtLogin = true
    var onboardingCompleted = false
    var triggerButtonNumber = 2
    var doubleClickInterval = 0.28
    var doubleClickMaxDistance = 90.0

    static let defaults = AppPreferences()
}
