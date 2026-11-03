import AppKit
import SwiftUI

@MainActor
final class VoiceTestWindowController: NSWindowController {
    init(app: AppController) {
        let hosting = NSHostingController(rootView: VoiceTestView(app: app))
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 430),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "MiddleFlow · 语音测试"
        window.contentViewController = hosting
        window.minSize = NSSize(width: 580, height: 360)
        window.center()
        super.init(window: window)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private struct VoiceTestView: View {
    @ObservedObject var app: AppController
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(FlowTheme.accentGradient)
                    Image(systemName: "waveform")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.white)
                }
                .frame(width: 48, height: 48)

                VStack(alignment: .leading, spacing: 5) {
                    Text("语音输入测试")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                    Text("把光标放进下面输入框，单击中键开始，再单击结束。双击中键应发送 Return。")
                        .font(.system(size: 12.5))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                StatusPill(
                    title: app.runtime.microphoneActive ? "麦克风活跃" : "等待输入",
                    color: app.runtime.microphoneActive ? FlowTheme.mint : .secondary,
                    pulse: app.runtime.microphoneActive
                )
            }
            .padding(24)

            Divider().opacity(0.55)

            TextEditor(text: $text)
                .font(.system(size: 18))
                .scrollContentBackground(.hidden)
                .padding(16)
                .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 14))
                .overlay {
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(FlowTheme.subtleBorder, lineWidth: 1)
                }
                .focused($focused)
                .padding(24)

            HStack {
                Label(
                    "输入法快捷键：\(app.preferences.voiceShortcut.shortTitle)",
                    systemImage: "keyboard"
                )
                .font(.system(size: 11.5))
                .foregroundStyle(.secondary)
                Spacer()
                Button("清空") { text = "" }
                    .buttonStyle(FlowButtonStyle(kind: .secondary))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear { focused = true }
    }
}
