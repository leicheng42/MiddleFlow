import AppKit

@main
struct MiddleFlowMain {
    @MainActor
    static func main() {
        let application = NSApplication.shared
        let controller = AppController()
        application.delegate = controller
        application.run()
    }
}
