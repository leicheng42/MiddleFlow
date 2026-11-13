import AppKit
import SwiftUI

private enum SettingsPage: String, CaseIterable, Identifiable {
    case overview
    case gestures
    case voice
    case inputMethod
    case apps
    case permissions
    case diagnostics
    case about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overview: return "概览"
        case .gestures: return "手势"
        case .voice: return "语音"
        case .inputMethod: return "豆包输入法"
        case .apps: return "应用"
        case .permissions: return "权限"
        case .diagnostics: return "诊断"
        case .about: return "关于"
        }
    }

    var icon: String {
        switch self {
        case .overview: return "rectangle.grid.2x2.fill"
        case .gestures: return "cursorarrow.click"
        case .voice: return "waveform"
        case .inputMethod: return "keyboard.fill"
        case .apps: return "square.stack.fill"
        case .permissions: return "lock.shield.fill"
        case .diagnostics: return "waveform.path.ecg"
        case .about: return "info.circle.fill"
        }
    }
}

struct SettingsRootView: View {
    @ObservedObject var app: AppController
    @State private var page: SettingsPage = .overview

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
            content
        }
        .background(background)
        .frame(minWidth: 940, minHeight: 640)
    }

    private var background: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
            LinearGradient(
                colors: [
                    FlowTheme.ember.opacity(0.035),
                    Color.clear,
                    FlowTheme.mint.opacity(0.018)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 11) {
                AppMark(size: 38)
                VStack(alignment: .leading, spacing: 1) {
                    Text("MiddleFlow")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("Voice at your fingertip")
                        .font(.system(size: 9.5, weight: .medium, design: .rounded))
                        .tracking(0.3)
                        .foregroundStyle(.white.opacity(0.42))
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 28)
            .padding(.bottom, 26)

            VStack(spacing: 4) {
                ForEach(SettingsPage.allCases) { item in
                    Button {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            page = item
                        }
                        if item == .diagnostics {
                            app.refreshLogTail()
                        }
                    } label: {
                        HStack(spacing: 11) {
                            Image(systemName: item.icon)
                                .font(.system(size: 13, weight: .semibold))
                                .frame(width: 24, alignment: .leading)
                            Text(item.title)
                                .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                            Spacer()
                            if item == .permissions,
                               !app.runtime.accessibility {
                                Circle()
                                    .fill(FlowTheme.ember)
                                    .frame(width: 6, height: 6)
                            }
                        }
                        .foregroundStyle(
                            page == item ? .white : .white.opacity(0.52)
                        )
                        .padding(.horizontal, 13)
                        .padding(.vertical, 9)
                        .background {
                            if page == item {
                                RoundedRectangle(cornerRadius: 11, style: .continuous)
                                    .fill(.white.opacity(0.10))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                                            .stroke(.white.opacity(0.075), lineWidth: 1)
                                    }
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)

            Spacer()

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(app.runtime.mappingActive ? FlowTheme.mint : Color.orange)
                        .frame(width: 7, height: 7)
                    Text(app.runtime.mappingActive ? "映射运行中" : "映射已暂停")
                        .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.58))
                }
                Text("v\(AppController.version)")
                    .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.28))
            }
            .padding(20)
        }
        .frame(width: 218)
        .background(FlowTheme.sidebarGradient)
    }

    private var content: some View {
        VStack(spacing: 0) {
            topBar
            Divider().opacity(0.48)
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    switch page {
                    case .overview:
                        overviewPage
                    case .gestures:
                        gesturesPage
                    case .voice:
                        voicePage
                    case .inputMethod:
                        inputMethodPage
                    case .apps:
                        appsPage
                    case .permissions:
                        permissionsPage
                    case .diagnostics:
                        diagnosticsPage
                    case .about:
                        aboutPage
                    }
                }
                .padding(.horizontal, 34)
                .padding(.top, 24)
                .padding(.bottom, 36)
                .frame(maxWidth: 860, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollIndicators(.hidden)
        }
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            Image(systemName: page.icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(FlowTheme.ember)
                .frame(width: 31, height: 31)
                .background(
                    FlowTheme.ember.opacity(0.10),
                    in: RoundedRectangle(cornerRadius: 9, style: .continuous)
                )

            VStack(alignment: .leading, spacing: 1) {
                Text(page.title)
                    .font(.system(size: 13.5, weight: .bold, design: .rounded))
                Text("MiddleFlow · 本地语音桥接")
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 16)

            StatusPill(
                title: mappingStatusTitle,
                color: mappingStatusColor,
                pulse: app.runtime.mappingActive
            )

            Button {
                app.refreshDoubaoStatus()
                page = .inputMethod
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: "keyboard")
                        .font(.system(size: 11.5, weight: .semibold))
                    Text("豆包 · \(app.doubaoStatus.readiness.title)")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 8.5, weight: .bold))
                        .opacity(0.48)
                }
                .foregroundStyle(app.doubaoStatus.isReady ? FlowTheme.mint : Color.orange)
                .padding(.horizontal, 11)
                .padding(.vertical, 6)
                .background(
                    (app.doubaoStatus.isReady ? FlowTheme.mint : Color.orange).opacity(0.10),
                    in: Capsule()
                )
            }
            .buttonStyle(.plain)
            .help("检查豆包输入法安装和输入源状态")
        }
        .padding(.horizontal, 24)
        .frame(height: 56)
        .background(.ultraThinMaterial)
    }

    private var mappingStatusTitle: String {
        if app.runtime.mappingActive { return "监听中" }
        return app.preferences.mappingEnabled ? "待授权" : "已暂停"
    }

    private var mappingStatusColor: Color {
        if app.runtime.mappingActive { return FlowTheme.mint }
        return app.preferences.mappingEnabled ? .orange : .secondary
    }

    private var overviewPage: some View {
        VStack(alignment: .leading, spacing: 20) {
            SectionHeader(
                eyebrow: "Control center",
                title: "把声音变成动作",
                subtitle: "中键唤起豆包语音输入；在 UU Remote 等画布应用中，MiddleFlow 会把转写结果自动送回原来的输入位置。"
            )

            overviewHero

            HStack(spacing: 14) {
                MetricCard(
                    title: "中键次数",
                    value: "\(app.runtime.mappedClicks)",
                    detail: "本次运行",
                    icon: "cursorarrow.click"
                )
                MetricCard(
                    title: "双击发送",
                    value: "\(app.runtime.doubleClickSends)",
                    detail: "Return 动作",
                    icon: "return"
                )
                MetricCard(
                    title: "语音快捷键",
                    value: app.preferences.voiceShortcut.shortTitle,
                    detail: "豆包触发键",
                    icon: "keyboard"
                )
            }

            FlowCard {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("快速设置")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                            Text("常用开关集中在这里")
                                .font(.system(size: 11.5))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        StatusPill(
                            title: app.preferences.mappingEnabled ? "已启用" : "已暂停",
                            color: app.preferences.mappingEnabled ? FlowTheme.mint : .orange
                        )
                    }
                    Divider().opacity(0.55)
                    PreferenceRow(
                        icon: "cursorarrow.click.2",
                        title: "中键映射",
                        detail: "关闭后恢复普通中键，不触发语音输入"
                    ) {
                        FlowToggle(
                            isOn: Binding(
                                get: { app.preferences.mappingEnabled },
                                set: { app.setMappingEnabled($0) }
                            )
                        )
                    }
                    PreferenceRow(
                        icon: "return",
                        title: "双击中键发送",
                        detail: "双击时发送 Return；在语音流程中会等待转写粘贴完成"
                    ) {
                        FlowToggle(
                            isOn: Binding(
                                get: { app.preferences.doubleClickEnabled },
                                set: { app.setDoubleClickEnabled($0) }
                            )
                        )
                    }
                    PreferenceRow(
                        icon: "doc.on.clipboard",
                        title: "自动粘贴",
                        detail: "把转写写入剪贴板，并向前台目标应用发送 Cmd+V"
                    ) {
                        FlowToggle(
                            isOn: Binding(
                                get: { app.preferences.autoPaste },
                                set: { app.setAutoPaste($0) }
                            )
                        )
                    }
                }
            }
        }
    }

    private var overviewHero: some View {
        HStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(FlowTheme.ember.opacity(0.11))
                    .frame(width: 128, height: 128)
                Circle()
                    .stroke(FlowTheme.ember.opacity(0.15), lineWidth: 1)
                    .frame(width: 98, height: 98)
                Image(systemName: app.runtime.microphoneActive ? "waveform" : "waveform.circle.fill")
                    .font(.system(size: 46, weight: .light))
                    .foregroundStyle(FlowTheme.accentGradient)
            }
            .frame(width: 140, height: 140)

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 9) {
                    Text(app.runtime.microphoneActive ? "正在聆听" : "随时可以开口")
                        .font(.system(size: 25, weight: .bold, design: .rounded))
                    StatusPill(
                        title: app.runtime.mappingActive ? "监听中" : "未监听",
                        color: app.runtime.mappingActive ? FlowTheme.mint : .secondary,
                        pulse: app.runtime.mappingActive
                    )
                }
                Text(
                    app.runtime.microphoneActive
                        ? "豆包麦克风已启动。单击中键结束，双击结束并发送。"
                        : "把光标放进输入框，单击鼠标中键开始语音输入。"
                )
                .font(.system(size: 13.5))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 10) {
                    Button {
                        app.showTestWindow()
                    } label: {
                        Label("打开测试窗口", systemImage: "play.fill")
                    }
                    .buttonStyle(FlowButtonStyle(kind: .primary))

                    Button {
                        app.setMappingEnabled(!app.preferences.mappingEnabled)
                    } label: {
                        Label(
                            app.preferences.mappingEnabled ? "暂停映射" : "开启映射",
                            systemImage: app.preferences.mappingEnabled ? "pause.fill" : "play.fill"
                        )
                    }
                    .buttonStyle(FlowButtonStyle(kind: .secondary))
                }
                .padding(.top, 4)
            }
            Spacer(minLength: 8)
        }
        .padding(26)
        .background {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            FlowTheme.ember.opacity(0.09),
                            Color(nsColor: .controlBackgroundColor),
                            FlowTheme.mint.opacity(0.035)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .stroke(FlowTheme.ember.opacity(0.13), lineWidth: 1)
                }
                .shadow(color: FlowTheme.ember.opacity(0.06), radius: 26, y: 10)
        }
    }

    private var gesturesPage: some View {
        VStack(alignment: .leading, spacing: 20) {
            SectionHeader(
                eyebrow: "Gestures",
                title: "一个中键，两种节奏",
                subtitle: "单击负责语音，双击负责确认。所有动作都在本地完成，不读取你的输入内容。"
            )

            HStack(alignment: .top, spacing: 14) {
                GestureCard(
                    accent: FlowTheme.ember,
                    icon: "cursorarrow.click",
                    badge: "单击",
                    title: "开始或结束语音",
                    detail: "向豆包发送 \(app.preferences.voiceShortcut.shortTitle)。在画布应用中先打开 MiddleFlow 浮层，再开始录音。"
                )
                GestureCard(
                    accent: FlowTheme.mint,
                    icon: "cursorarrow.click.2",
                    badge: "双击",
                    title: "停止并发送",
                    detail: "录音中双击会停止录音，等待转写粘贴完成后发送 Return。普通应用中双击直接发送 Return。"
                )
            }

            FlowCard {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("双击行为")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                            Text("普通应用 \(Int(app.preferences.doubleClickInterval * 1000)) ms · UU Remote \(Int(app.preferences.composerDoubleClickInterval * 1000)) ms · 位移阈值 \(Int(app.preferences.doubleClickMaxDistance)) pt")
                                .font(.system(size: 11.5))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        FlowToggle(
                            isOn: Binding(
                                get: { app.preferences.doubleClickEnabled },
                                set: { app.setDoubleClickEnabled($0) }
                            )
                        )
                    }
                    Divider().opacity(0.55)
                    PreferenceRow(
                        icon: "return",
                        title: "双击动作",
                        detail: "选择双击中键时发送的按键"
                    ) {
                        Picker(
                            "",
                            selection: Binding(
                                get: { app.preferences.doubleClickAction },
                                set: { app.setDoubleClickAction($0) }
                            )
                        ) {
                            ForEach(DoubleClickAction.allCases) { action in
                                Text(action.title).tag(action)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 130)
                    }
                }
            }

            HStack(spacing: 14) {
                InfoCard(
                    icon: "hand.tap",
                    title: "全局映射",
                    text: "MiddleFlow 拦截所有鼠标的 CG button 2。需要普通中键时，从菜单栏暂停即可。"
                )
                InfoCard(
                    icon: "lock.shield",
                    title: "隐私优先",
                    text: "不录音、不保存转写正文，只记录事件类型、字符数和状态。"
                )
            }
        }
    }

    private var voicePage: some View {
        VStack(alignment: .leading, spacing: 20) {
            SectionHeader(
                eyebrow: "Voice",
                title: "对齐你的输入法",
                subtitle: "MiddleFlow 发送的是输入法快捷键，不直接控制豆包。先确认豆包的“免按模式”快捷键与此处一致。"
            )

            FlowCard {
                VStack(alignment: .leading, spacing: 15) {
                    Text("语音快捷键")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                    HStack(spacing: 10) {
                        ForEach(VoiceShortcut.allCases) { shortcut in
                            ShortcutChoice(
                                shortcut: shortcut,
                                selected: app.preferences.voiceShortcut == shortcut
                            ) {
                                app.setVoiceShortcut(shortcut)
                            }
                        }
                    }
                    Text("推荐：豆包语音输入设置中选择“右侧 Option”，MiddleFlow 默认发送 keycode 61 和右侧 Option 标志位。")
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            FlowCard {
                VStack(alignment: .leading, spacing: 3) {
                    PreferenceRow(
                        icon: "doc.on.clipboard",
                        title: "自动粘贴到目标应用",
                        detail: "转写完成后恢复目标窗口并发送 Cmd+V"
                    ) {
                        FlowToggle(
                            isOn: Binding(
                                get: { app.preferences.autoPaste },
                                set: { app.setAutoPaste($0) }
                            )
                        )
                    }
                    Divider().opacity(0.55)
                    PreferenceRow(
                        icon: "return",
                        title: "粘贴后按 Return",
                        detail: "每次自动粘贴完成后发送 Return"
                    ) {
                        FlowToggle(
                            isOn: Binding(
                                get: { app.preferences.pasteThenReturn },
                                set: { app.setPasteThenReturn($0) }
                            )
                        )
                    }
                    Divider().opacity(0.55)
                    PreferenceRow(
                        icon: "arrow.uturn.backward.circle",
                        title: "成功后恢复剪贴板",
                        detail: "粘贴发送成功后，若剪贴板未被修改则恢复原内容"
                    ) {
                        FlowToggle(
                            isOn: Binding(
                                get: { app.preferences.restoreClipboardAfterPaste },
                                set: { app.setRestoreClipboard($0) }
                            )
                        )
                    }
                }
            }

            FlowCard {
                HStack(spacing: 16) {
                    Image(systemName: "waveform.and.mic")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(FlowTheme.ember)
                        .frame(width: 48, height: 48)
                        .background(FlowTheme.ember.opacity(0.10), in: RoundedRectangle(cornerRadius: 14))
                    VStack(alignment: .leading, spacing: 3) {
                        Text("先做一次完整测试")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                        Text("测试窗口会自动聚焦输入框，方便验证中键、豆包和麦克风链路。")
                            .font(.system(size: 11.5))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("打开测试窗口") { app.showTestWindow() }
                        .buttonStyle(FlowButtonStyle(kind: .primary))
                }
            }
        }
    }

    private var inputMethodPage: some View {
        VStack(alignment: .leading, spacing: 20) {
            SectionHeader(
                eyebrow: "Input method",
                title: "先让豆包准备好",
                subtitle: "MiddleFlow 通过豆包输入法完成语音识别。这里会检查安装、系统注册和当前输入源，并给出对应的处理步骤。"
            )

            FlowCard {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(alignment: .top, spacing: 17) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 17, style: .continuous)
                                .fill(doubaoTint.opacity(0.10))
                            Image(systemName: "keyboard.fill")
                                .font(.system(size: 26, weight: .medium))
                                .foregroundStyle(doubaoTint)
                        }
                        .frame(width: 62, height: 62)

                        VStack(alignment: .leading, spacing: 5) {
                            HStack(spacing: 9) {
                                Text(doubaoHeadline)
                                    .font(.system(size: 19, weight: .bold, design: .rounded))
                                StatusPill(
                                    title: app.doubaoStatus.readiness.title,
                                    color: doubaoTint,
                                    pulse: app.doubaoStatus.isReady
                                )
                            }
                            Text(doubaoDetail)
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer(minLength: 8)

                        Button {
                            app.refreshDoubaoStatus()
                        } label: {
                            Label("重新检测", systemImage: "arrow.clockwise")
                        }
                        .buttonStyle(FlowButtonStyle(kind: .secondary))
                    }

                    Divider().opacity(0.55)

                    HStack(spacing: 10) {
                        DoubaoCheckCell(
                            title: "安装包",
                            value: app.doubaoStatus.installed ? "已安装" : "未找到",
                            detail: app.doubaoStatus.version.isEmpty
                                ? "DoubaoIme.app"
                                : "版本 \(app.doubaoStatus.version)",
                            ready: app.doubaoStatus.installed
                        )
                        DoubaoCheckCell(
                            title: "系统注册",
                            value: app.doubaoStatus.registered ? "已注册" : "未注册",
                            detail: "Input source",
                            ready: app.doubaoStatus.registered
                        )
                        DoubaoCheckCell(
                            title: "当前输入源",
                            value: app.doubaoStatus.selected ? "豆包" : "其他输入法",
                            detail: app.doubaoStatus.selected ? "可以直接开始" : "请切换到豆包",
                            ready: app.doubaoStatus.selected
                        )
                    }

                    HStack(spacing: 10) {
                        Button {
                            app.openDoubaoDownload()
                        } label: {
                            Label("打开豆包官网", systemImage: "arrow.up.right")
                        }
                        .buttonStyle(FlowButtonStyle(kind: .primary))

                        Button {
                            app.openKeyboardInputSettings()
                        } label: {
                            Label("打开键盘设置", systemImage: "keyboard")
                        }
                        .buttonStyle(FlowButtonStyle(kind: .secondary))

                        if app.doubaoStatus.isReady {
                            Button {
                                app.showTestWindow()
                            } label: {
                                Label("打开测试窗口", systemImage: "play.fill")
                            }
                            .buttonStyle(FlowButtonStyle(kind: .secondary))
                        }

                        Spacer()

                        Text("检测于 \(app.doubaoStatus.checkedAt.formatted(date: .omitted, time: .shortened))")
                            .font(.system(size: 9.5, design: .monospaced))
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            if !app.doubaoStatus.isReady {
                PermissionCallout(
                    title: doubaoNeedsActionTitle,
                    detail: doubaoNeedsActionDetail,
                    action: app.doubaoStatus.installed ? "打开键盘设置" : "下载豆包"
                ) {
                    if app.doubaoStatus.installed {
                        app.openKeyboardInputSettings()
                    } else {
                        app.openDoubaoDownload()
                    }
                }
            }

            FlowCard {
                VStack(alignment: .leading, spacing: 15) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("从安装到可用")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                        Text("按顺序完成一次，之后 MiddleFlow 会在每次打开设置时自动检测。")
                            .font(.system(size: 11.5))
                            .foregroundStyle(.secondary)
                    }

                    DoubaoStepRow(
                        number: "01",
                        title: "安装豆包输入法",
                        detail: "从豆包输入法官网下载 macOS 版本，完成安装并打开一次。"
                    )
                    DoubaoStepRow(
                        number: "02",
                        title: "添加到系统输入法",
                        detail: "打开“系统设置 → 键盘 → 输入法”，添加“豆包输入法”。"
                    )
                    DoubaoStepRow(
                        number: "03",
                        title: "切换到豆包输入源",
                        detail: "从菜单栏输入法列表选择豆包，并确认可以正常输入中文。"
                    )
                    DoubaoStepRow(
                        number: "04",
                        title: "设置右侧 Option",
                        detail: "在豆包语音输入设置中，把“免按模式”的快捷键设为“右侧 Option”。"
                    )
                    DoubaoStepRow(
                        number: "05",
                        title: "回到 MiddleFlow 验证",
                        detail: "点击“重新检测”，状态变为“已安装并启用”后，打开测试窗口走一次完整流程。"
                    )
                }
            }

            HStack(spacing: 14) {
                InfoCard(
                    icon: "lock.shield",
                    title: "只读取状态",
                    text: "检测只读取输入法安装路径、版本和系统输入源 ID，不读取按键内容或转写正文。"
                )
                InfoCard(
                    icon: "keyboard.badge.ellipsis",
                    title: "快捷键要一致",
                    text: "豆包的语音快捷键必须与 MiddleFlow 的“语音”页面一致。默认是右侧 Option。"
                )
            }
        }
    }

    private var doubaoTint: Color {
        switch app.doubaoStatus.readiness {
        case .ready: return FlowTheme.mint
        case .missing: return FlowTheme.ember
        case .installedNotRegistered, .registeredNotSelected: return .orange
        }
    }

    private var doubaoHeadline: String {
        switch app.doubaoStatus.readiness {
        case .ready: return "豆包输入法已经就绪"
        case .missing: return "还没有安装豆包输入法"
        case .installedNotRegistered: return "安装完成，还差系统注册"
        case .registeredNotSelected: return "切换到豆包输入源"
        }
    }

    private var doubaoDetail: String {
        switch app.doubaoStatus.readiness {
        case .ready:
            return "安装、系统注册和当前输入源都正确。现在可以把光标放进输入框，按鼠标中键开始语音。"
        case .missing:
            return "MiddleFlow 需要使用豆包输入法完成语音转写。下载安装后，按下方步骤添加输入源。"
        case .installedNotRegistered:
            return "已经在 \(app.doubaoStatus.bundlePath) 找到安装包，但系统还没有注册豆包输入源。"
        case .registeredNotSelected:
            return "豆包输入法已经注册，但当前使用的是 \(app.doubaoStatus.currentInputSourceID)。切换后再重新检测。"
        }
    }

    private var doubaoNeedsActionTitle: String {
        switch app.doubaoStatus.readiness {
        case .ready: return ""
        case .missing: return "需要先安装豆包输入法"
        case .installedNotRegistered: return "需要把豆包添加到系统输入法"
        case .registeredNotSelected: return "需要切换到豆包输入源"
        }
    }

    private var doubaoNeedsActionDetail: String {
        switch app.doubaoStatus.readiness {
        case .ready:
            return ""
        case .missing:
            return "打开豆包输入法官网下载 macOS 版本。安装后回到这里重新检测。"
        case .installedNotRegistered:
            return "打开键盘设置，在输入法列表中添加豆包，然后回到这里重新检测。"
        case .registeredNotSelected:
            return "从菜单栏输入法菜单选择豆包，或打开键盘设置调整输入源顺序。"
        }
    }

    private var appsPage: some View {
        VStack(alignment: .leading, spacing: 20) {
            SectionHeader(
                eyebrow: "Targets",
                title: "让画布应用也能输入",
                subtitle: "远程桌面和游戏画布无法直接读取输入框，MiddleFlow 会在本地浮层接住转写，再通过剪贴板送回目标位置。"
            )

            FlowCard {
                VStack(alignment: .leading, spacing: 15) {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("浮层应用")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                            Text("这些应用中的单击会打开语音浮层")
                                .font(.system(size: 11.5))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Menu {
                            ForEach(runningApps, id: \.bundleIdentifier) { application in
                                if let bundleID = application.bundleIdentifier {
                                    Button {
                                        app.addRunningComposerTarget(application)
                                    } label: {
                                        Label(
                                            application.localizedName ?? bundleID,
                                            systemImage: "plus.circle"
                                        )
                                    }
                                }
                            }
                        } label: {
                            Label("添加运行中的应用", systemImage: "plus")
                        }
                        .menuStyle(.borderlessButton)
                        .buttonStyle(FlowButtonStyle(kind: .secondary))
                    }
                    Divider().opacity(0.55)

                    ForEach(Array(app.preferences.composerBundleIDs).sorted(), id: \.self) { bundleID in
                        ComposerTargetRow(
                            bundleID: bundleID,
                            name: TargetPolicy.displayName(for: bundleID),
                            canRemove: bundleID != TargetPolicy.uuRemoteBundleID
                        ) {
                            app.removeComposerTarget(bundleID: bundleID)
                        }
                    }
                }
            }

            HStack(spacing: 14) {
                InfoCard(
                    icon: "video",
                    title: "UU Remote",
                    text: "默认开启。语音浮层打开后，转写会写入剪贴板并发送 Cmd+V，失败时保留剪贴板供手动粘贴。"
                )
                InfoCard(
                    icon: "square.stack.3d.up",
                    title: "其他应用",
                    text: "所有未加入浮层列表的应用仍使用普通“单击发送快捷键”模式，不会被强行改写。"
                )
            }
        }
    }

    private var permissionsPage: some View {
        VStack(alignment: .leading, spacing: 20) {
            SectionHeader(
                eyebrow: "Permissions",
                title: "只申请必要的系统能力",
                subtitle: "MiddleFlow 需要辅助功能权限来拦截中键和投递键盘事件；它不读取屏幕内容，也不上传数据。"
            )

            if !app.runtime.accessibility {
                PermissionCallout(
                    title: "还需要辅助功能权限",
                    detail: "打开系统设置，在“隐私与安全性 → 辅助功能”中启用 MiddleFlow。授权后无需重启，应用会自动重试。",
                    action: "打开系统设置"
                ) {
                    app.requestAccessibilityPermission()
                }
            }

            FlowCard {
                VStack(spacing: 0) {
                    PermissionRow(
                        icon: "accessibility",
                        title: "辅助功能",
                        detail: "拦截鼠标中键、投递语音快捷键和 Return",
                        granted: app.runtime.accessibility,
                        action: app.openAccessibilitySettings
                    )
                    Divider().opacity(0.55)
                    PermissionRow(
                        icon: "keyboard",
                        title: "事件投递",
                        detail: "向当前输入框发送 Right Option 和 Cmd+V",
                        granted: app.runtime.canPostEvents,
                        action: app.openAccessibilitySettings
                    )
                    Divider().opacity(0.55)
                    PermissionRow(
                        icon: "power",
                        title: "登录时启动",
                        detail: app.usesLegacyLoginItem
                            ? "沿用原 MiddleOptionBridge 登录服务"
                            : "使用 macOS 官方 SMAppService 注册，不写固定用户路径",
                        granted: app.preferences.launchAtLogin,
                        action: {
                            app.setLaunchAtLogin(!app.preferences.launchAtLogin)
                        }
                    )
                }
            }

            if !app.loginItemError.isEmpty {
                Text(app.loginItemError)
                    .font(.system(size: 11.5))
                    .foregroundStyle(.orange)
            }
        }
    }

    private var diagnosticsPage: some View {
        VStack(alignment: .leading, spacing: 20) {
            SectionHeader(
                eyebrow: "Diagnostics",
                title: "看得见的运行状态",
                subtitle: "这里只显示事件类型、状态和字符数。诊断日志不记录转写正文。"
            )

            HStack(spacing: 14) {
                MetricCard(
                    title: "辅助功能",
                    value: app.runtime.accessibility ? "正常" : "缺失",
                    detail: "Accessibility",
                    icon: "accessibility"
                )
                MetricCard(
                    title: "麦克风",
                    value: app.runtime.microphoneActive ? "活跃" : "空闲",
                    detail: "Audio device state",
                    icon: "mic.fill"
                )
                MetricCard(
                    title: "映射",
                    value: app.runtime.mappingActive ? "运行" : "暂停",
                    detail: "Event tap",
                    icon: "cursorarrow.motionlines"
                )
            }

            FlowCard(padding: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text("最近日志")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                        Spacer()
                        Button("刷新") {
                            app.refreshLogTail()
                        }
                        .buttonStyle(FlowButtonStyle(kind: .quiet))
                        Button("打开日志") {
                            app.openDiagnosticLog()
                        }
                        .buttonStyle(FlowButtonStyle(kind: .quiet))
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 16)
                    .padding(.bottom, 10)

                    ScrollView {
                        Text(app.logTail.isEmpty ? "暂无日志。点击刷新或先打开一次测试窗口。" : app.logTail)
                            .font(.system(size: 10.5, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)
                    }
                    .frame(height: 230)
                    .background(Color.primary.opacity(0.035))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .padding(12)
                }
            }

            HStack {
                Button {
                    app.copyDiagnosticsSummary()
                } label: {
                    Label("复制诊断摘要", systemImage: "doc.on.doc")
                }
                .buttonStyle(FlowButtonStyle(kind: .secondary))

                Button {
                    app.refreshLogTail()
                } label: {
                    Label("刷新日志", systemImage: "arrow.clockwise")
                }
                .buttonStyle(FlowButtonStyle(kind: .secondary))
            }
        }
    }

    private var aboutPage: some View {
        VStack(alignment: .leading, spacing: 20) {
            SectionHeader(
                eyebrow: "About",
                title: "MiddleFlow",
                subtitle: "把鼠标中键变成语音入口。一个本地优先、可配置、面向画布应用的 macOS 语音桥接器。"
            )

            FlowCard {
                HStack(spacing: 22) {
                    AppMark(size: 92)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("MiddleFlow")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                        Text("版本 \(AppController.version) · macOS 13+")
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundStyle(.secondary)
                        Text("MIT License · 本地运行 · 不收集转写内容")
                            .font(.system(size: 11.5))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
            }

            HStack(spacing: 14) {
                LinkCard(
                    icon: "chevron.left.forwardslash.chevron.right",
                    title: "GitHub",
                    text: "源码、问题反馈和版本发布",
                    action: app.openGitHub
                )
                LinkCard(
                    icon: "hand.raised.fill",
                    title: "隐私说明",
                    text: "不录音、不记录正文、不上传",
                    action: app.openPrivacy
                )
            }

            FlowCard {
                VStack(alignment: .leading, spacing: 10) {
                    Text("兼容性说明")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                    Text("MiddleFlow 不隶属于豆包、UU Remote 或 Logitech。它通过系统级输入事件与这些应用配合工作；不同版本的快捷键和远端剪贴板同步行为可能需要调整。")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var runningApps: [NSRunningApplication] {
        NSWorkspace.shared.runningApplications
            .filter {
                $0.activationPolicy == .regular &&
                $0.bundleIdentifier != nil &&
                !($0.bundleIdentifier?.hasPrefix("com.apple.") ?? false) &&
                !app.preferences.composerBundleIDs.contains($0.bundleIdentifier ?? "")
            }
            .sorted { ($0.localizedName ?? "") < ($1.localizedName ?? "") }
    }
}

private struct AppMark: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.27, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.16, green: 0.16, blue: 0.15),
                            Color(red: 0.045, green: 0.045, blue: 0.043)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    RoundedRectangle(cornerRadius: size * 0.27, style: .continuous)
                        .stroke(.white.opacity(0.16), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.28), radius: size * 0.12, y: size * 0.07)

            HStack(spacing: size * 0.055) {
                ForEach([0.38, 0.72, 0.52, 0.92, 0.46], id: \.self) { value in
                    Capsule()
                        .fill(FlowTheme.accentGradient)
                        .frame(width: size * 0.055, height: size * value * 0.56)
                }
            }
        }
        .frame(width: size, height: size)
    }
}

private struct MetricCard: View {
    let title: String
    let value: String
    let detail: String
    let icon: String

    var body: some View {
        HStack(spacing: 13) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(FlowTheme.ember)
                .frame(width: 34, height: 34)
                .background(FlowTheme.ember.opacity(0.10), in: RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .lineLimit(1)
                Text(detail)
                    .font(.system(size: 9.5, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
            Spacer(minLength: 0)
        }
        .padding(15)
        .background(.background, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(FlowTheme.subtleBorder, lineWidth: 1)
        }
    }
}

private struct GestureCard: View {
    let accent: Color
    let icon: String
    let badge: String
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(accent)
                    .frame(width: 38, height: 38)
                    .background(accent.opacity(0.10), in: RoundedRectangle(cornerRadius: 11))
                Spacer()
                Text(badge)
                    .font(.system(size: 10.5, weight: .bold, design: .rounded))
                    .foregroundStyle(accent)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(accent.opacity(0.10), in: Capsule())
            }
            Text(title)
                .font(.system(size: 17, weight: .bold, design: .rounded))
            Text(detail)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: 170, alignment: .topLeading)
        .padding(20)
        .background(.background, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(FlowTheme.subtleBorder, lineWidth: 1)
        }
    }
}

private struct InfoCard: View {
    let icon: String
    let title: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(FlowTheme.ember)
                .frame(width: 32, height: 32)
                .background(FlowTheme.ember.opacity(0.10), in: RoundedRectangle(cornerRadius: 9))
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 12.5, weight: .bold, design: .rounded))
                Text(text)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct ShortcutChoice: View {
    let shortcut: VoiceShortcut
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: shortcut == .function ? "fn" : "option")
                    .font(.system(size: 17, weight: .semibold))
                Text(shortcut.title)
                    .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                Text(shortcut.shortTitle)
                    .font(.system(size: 9.5, design: .monospaced))
                    .foregroundStyle(selected ? .white.opacity(0.68) : .secondary)
            }
            .foregroundStyle(selected ? .white : .primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(selected ? AnyShapeStyle(FlowTheme.accentGradient) : AnyShapeStyle(Color.primary.opacity(0.045)))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(selected ? .clear : FlowTheme.subtleBorder, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct ComposerTargetRow: View {
    let bundleID: String
    let name: String
    let canRemove: Bool
    let remove: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            appIcon
                .frame(width: 30, height: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.system(size: 13, weight: .semibold))
                Text(bundleID)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            StatusPill(title: "浮层模式", color: FlowTheme.ember)
            if canRemove {
                Button(action: remove) {
                    Image(systemName: "minus.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("移除")
            }
        }
        .padding(.vertical, 7)
    }

    @ViewBuilder
    private var appIcon: some View {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                .resizable()
                .scaledToFit()
        } else {
            Image(systemName: "app.fill")
                .foregroundStyle(FlowTheme.ember)
        }
    }
}

private struct PermissionCallout: View {
    let title: String
    let detail: String
    let action: String
    let perform: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 13) {
            Image(systemName: "exclamationmark.shield.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(FlowTheme.ember)
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.system(size: 13.5, weight: .bold, design: .rounded))
                Text(detail)
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Button(action, action: perform)
                .buttonStyle(FlowButtonStyle(kind: .primary))
        }
        .padding(16)
        .background(FlowTheme.ember.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(FlowTheme.ember.opacity(0.18), lineWidth: 1)
        }
    }
}

private struct PermissionRow: View {
    let icon: String
    let title: String
    let detail: String
    let granted: Bool
    let action: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(granted ? FlowTheme.mint : FlowTheme.ember)
                .frame(width: 34, height: 34)
                .background(
                    (granted ? FlowTheme.mint : FlowTheme.ember).opacity(0.10),
                    in: RoundedRectangle(cornerRadius: 10)
                )
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                Text(detail)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            StatusPill(
                title: granted ? "已启用" : "未启用",
                color: granted ? FlowTheme.mint : .orange
            )
            Button(granted ? "管理" : "启用", action: action)
                .buttonStyle(FlowButtonStyle(kind: .quiet))
        }
        .padding(.vertical, 12)
    }
}

private struct DoubaoCheckCell: View {
    let title: String
    let value: String
    let detail: String
    let ready: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 5) {
                Circle()
                    .fill(ready ? FlowTheme.mint : Color.orange)
                    .frame(width: 6, height: 6)
                Text(title)
                    .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(ready ? Color.primary : Color.orange)
            Text(detail)
                .font(.system(size: 9.5, design: .monospaced))
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        }
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(FlowTheme.subtleBorder, lineWidth: 1)
        }
    }
}

private struct DoubaoStepRow: View {
    let number: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 13) {
            Text(number)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(FlowTheme.ember)
                .frame(width: 31, height: 24)
                .background(FlowTheme.ember.opacity(0.10), in: Capsule())
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 12.5, weight: .bold, design: .rounded))
                Text(detail)
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 1)
    }
}

private struct LinkCard: View {
    let icon: String
    let title: String
    let text: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(FlowTheme.ember)
                    .frame(width: 34, height: 34)
                    .background(FlowTheme.ember.opacity(0.10), in: RoundedRectangle(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                    Text(text)
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(15)
            .background(.background, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(FlowTheme.subtleBorder, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }
}
