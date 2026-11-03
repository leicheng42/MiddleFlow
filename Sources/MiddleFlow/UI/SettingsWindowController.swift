import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController: NSWindowController {
    init(app: AppController) {
        let root = SettingsRootView(app: app)
        let hosting = NSHostingController(rootView: root)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1080, height: 720),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "MiddleFlow"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.backgroundColor = .clear
        window.minSize = NSSize(width: 940, height: 640)
        window.contentViewController = hosting
        window.center()
        window.setFrameAutosaveName("MiddleFlow.Settings")
        super.init(window: window)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        window?.makeKeyAndOrderFront(nil)
    }
}
