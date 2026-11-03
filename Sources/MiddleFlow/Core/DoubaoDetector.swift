import Carbon
import Foundation

enum DoubaoReadiness: Equatable {
    case missing
    case installedNotRegistered
    case registeredNotSelected
    case ready

    var title: String {
        switch self {
        case .missing: return "未安装"
        case .installedNotRegistered: return "已安装，未注册"
        case .registeredNotSelected: return "已安装，未选中"
        case .ready: return "已安装并启用"
        }
    }
}

struct DoubaoInstallationStatus: Equatable {
    var installed = false
    var registered = false
    var selected = false
    var version = ""
    var bundlePath = ""
    var currentInputSourceID = "unknown"
    var checkedAt = Date()

    var readiness: DoubaoReadiness {
        if !installed { return .missing }
        if !registered { return .installedNotRegistered }
        if !selected { return .registeredNotSelected }
        return .ready
    }

    var isReady: Bool {
        readiness == .ready
    }
}

enum DoubaoDetector {
    static let bundleID = "com.bytedance.inputmethod.doubaoime"
    static let inputSourceID = "com.bytedance.inputmethod.doubaoime.pinyin"
    static let downloadURL = URL(string: "https://shurufa.doubao.com/")!

    static func detect(fileManager: FileManager = .default) -> DoubaoInstallationStatus {
        let candidates = [
            "/Library/Input Methods/DoubaoIme.app",
            NSHomeDirectory() + "/Library/Input Methods/DoubaoIme.app"
        ]
        let bundlePath = candidates.first(where: { fileManager.fileExists(atPath: $0) }) ?? ""
        let installed = !bundlePath.isEmpty
        let source = inputSource()
        let current = currentInputSourceID()
        let version: String
        if installed {
            version = Bundle(path: bundlePath)?
                .object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        } else {
            version = ""
        }
        return DoubaoInstallationStatus(
            installed: installed,
            registered: source != nil,
            selected: current == inputSourceID,
            version: version,
            bundlePath: bundlePath,
            currentInputSourceID: current,
            checkedAt: Date()
        )
    }

    static func currentInputSourceID() -> String {
        guard let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue(),
              let property = TISGetInputSourceProperty(source, kTISPropertyInputSourceID)
        else { return "unknown" }
        return unsafeBitCast(property, to: CFString.self) as String
    }

    static func inputSource() -> TISInputSource? {
        let query = [kTISPropertyInputSourceID: inputSourceID] as CFDictionary
        guard let list = TISCreateInputSourceList(query, false)?
            .takeRetainedValue() as? [TISInputSource]
        else { return nil }
        return list.first
    }
}
