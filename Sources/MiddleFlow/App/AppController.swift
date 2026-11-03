import AppKit
import Carbon
import Combine
import CoreGraphics
import Foundation
import ServiceManagement

@MainActor
final class AppController: NSObject, NSApplicationDelegate, ObservableObject {
    struct VoiceSession {
        let originalPID: pid_t
        let originalBundleID: String
        let originalName: String
        let startedAt: TimeInterval
        let clickPoint: CGPoint
        var state: VoiceComposerState
        var didSeeMicrophone = false
        var optionSent = false
        var stoppedAt: TimeInterval?
    }

    struct LatestTarget {
        let pid: pid_t
        let bundleID: String
        let point: CGPoint
        let capturedAt: TimeInterval
    }

    @Published private(set) var preferences: AppPreferences
    @Published private(set) var runtime = RuntimeSnapshot()
    @Published private(set) var latestTranscriptAvailable = false
    @Published private(set) var logTail = ""
    @Published private(set) var loginItemError = ""

    let paths: AppPaths

    private let preferencesStore: PreferencesStore
    private let diagnostics: Diagnostics
    private let keyboard = KeyboardSynthesizer()
    private let audio = AudioInputMonitor()
    private let clipboard = ClipboardService()
    private var eventTap: EventTapService
    private var directClassifier: GestureClassifier
    private var composerClassifier: GestureClassifier

    private var statusItem: NSStatusItem?
    private var statusMenu: NSMenu?
    private var mappingMenuItem: NSMenuItem?
    private var settingsWindowController: SettingsWindowController?
    private var testWindowController: VoiceTestWindowController?
    private var voiceComposer: VoiceComposerPanel?
    private var statusToast: StatusToastPanel?
    private var pollTimer: Timer?
    private var signalSources: [DispatchSourceSignal] = []

    private var pendingSingleWorkItem: DispatchWorkItem?
    private var composerStartWorkItem: DispatchWorkItem?
    private var composerToggleWorkItem: DispatchWorkItem?
    private var transcriptCheckWorkItem: DispatchWorkItem?
    private var composerTimeoutWorkItem: DispatchWorkItem?
    private var directGeneration = 0
    private var composerGeneration = 0

    private var pressed = false
    private var pressedAt = Date.distantPast
    private var voiceSession: VoiceSession?
    private var voiceComposerVisible = false
    private var composerTransitioning = false
    private var autoPasteInProgress = false
    private var pendingReturnAfterPaste = false
    private var lastComposerTextChangeAt = Date.distantPast
    private var latestTranscript = ""
    private var latestClipboardWrite: ClipboardWrite?
    private var latestTarget: LatestTarget?
    private var latestPasteGeneration = 0

    private var micActive = false
    private var micStartedAt: Date?
    private var lastMicDuration = 0.0
    private var lastStatusWrite = Date.distantPast
    private var lastRuntimeRefresh = Date.distantPast
    private var permissionPromptShown: Bool

    private var isPreview: Bool {
        CommandLine.arguments.contains("--ui-preview")
    }

    override init() {
        paths = .live
        preferencesStore = PreferencesStore(url: paths.preferencesURL)
        diagnostics = Diagnostics(logURL: paths.logURL)
        let loaded = preferencesStore.load()
        preferences = loaded
        directClassifier = GestureClassifier(
            interval: loaded.doubleClickInterval,
            maxDistance: loaded.doubleClickMaxDistance
        )
        composerClassifier = GestureClassifier(
            interval: loaded.doubleClickInterval,
            maxDistance: loaded.doubleClickMaxDistance
        )
        eventTap = EventTapService(buttonNumber: Int64(loaded.triggerButtonNumber))
        permissionPromptShown = UserDefaults.standard.bool(forKey: "permissionPromptShown")
        super.init()
        eventTap.delegate = self
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(isPreview ? .regular : .accessory)
        installSignalHandlers()
        audio.refreshIfNeeded(force: true)
        micActive = audio.isMicrophoneActive()
        if micActive { micStartedAt = Date() }
        buildStatusItem()
        syncLoginItemState()
        refreshRuntime()
        diagnostics.write(
            "READY pid=\(getpid()) preview=\(isPreview) " +
            "ax=\(PermissionCenter.accessibilityGranted) " +
            "post=\(PermissionCenter.canPostEvents)"
        )

        if preferences.mappingEnabled && !isPreview {
            startEventTap()
        }

        let timer = Timer(timeInterval: 0.12, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.poll()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        pollTimer = timer

        if shouldShowSettingsOnLaunch {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
                self?.showSettings()
            }
        }
        if CommandLine.arguments.contains("--test-window") ||
            CommandLine.arguments.contains("--self-test") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { [weak self] in
                self?.showTestWindow()
            }
        }
        if CommandLine.arguments.contains("--self-test") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
                self?.runSelfTest()
            }
        }
        if CommandLine.arguments.contains("--composer-demo") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { [weak self] in
                self?.runComposerDemo()
            }
        }
    }

    func applicationShouldHandleReopen(
        _ sender: NSApplication,
        hasVisibleWindows flag: Bool
    ) -> Bool {
        showSettings()
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        cancelAllScheduledWork()
        keyboard.releaseHeldModifier()
        eventTap.stop()
        writeStatus()
    }

    func showSettings() {
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController(app: self)
        }
        settingsWindowController?.showWindow(nil)
        settingsWindowController?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        preferences.onboardingCompleted = true
        persistPreferences()
    }

    func showTestWindow() {
        if testWindowController == nil {
            testWindowController = VoiceTestWindowController(app: self)
        }
        testWindowController?.showWindow(nil)
        testWindowController?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func toggleMapping() {
        setMappingEnabled(!preferences.mappingEnabled)
    }

    func setMappingEnabled(_ enabled: Bool) {
        guard preferences.mappingEnabled != enabled else { return }
        preferences.mappingEnabled = enabled
        cancelAllScheduledWork()
        keyboard.releaseHeldModifier()
        if enabled {
            startEventTap()
        } else {
            eventTap.stop()
            runtime.mappingActive = false
            runtime.lastError = ""
        }
        persistPreferences()
        refreshRuntime()
        diagnostics.write("MAPPING_ENABLED=\(enabled)")
    }

    func setDoubleClickEnabled(_ enabled: Bool) {
        preferences.doubleClickEnabled = enabled
        directClassifier.reset()
        composerClassifier.reset()
        cancelPendingSingle()
        persistPreferences()
        refreshRuntime()
    }

    func setDoubleClickAction(_ action: DoubleClickAction) {
        preferences.doubleClickAction = action
        persistPreferences()
    }

    func setVoiceShortcut(_ shortcut: VoiceShortcut) {
        preferences.voiceShortcut = shortcut
        voiceComposer?.configureBadge(shortcut: shortcut)
        persistPreferences()
        refreshRuntime()
    }

    func setAutoPaste(_ enabled: Bool) {
        preferences.autoPaste = enabled
        persistPreferences()
    }

    func setPasteThenReturn(_ enabled: Bool) {
        preferences.pasteThenReturn = enabled
        persistPreferences()
    }

    func setRestoreClipboard(_ enabled: Bool) {
        preferences.restoreClipboardAfterPaste = enabled
        persistPreferences()
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            try LoginItemManager.setEnabled(enabled)
            preferences.launchAtLogin = enabled
            loginItemError = ""
            persistPreferences()
        } catch {
            loginItemError = error.localizedDescription
            preferences.launchAtLogin = LoginItemManager.isEnabled
            diagnostics.write("LOGIN_ITEM_ERROR \(error.localizedDescription)")
        }
        objectWillChange.send()
    }

    func addComposerTarget(_ target: ComposerTarget) {
        guard !target.bundleID.isEmpty else { return }
        preferences.composerBundleIDs.insert(target.bundleID)
        persistPreferences()
        refreshRuntime()
    }

    func removeComposerTarget(bundleID: String) {
        preferences.composerBundleIDs.remove(bundleID)
        persistPreferences()
        refreshRuntime()
    }

    func addRunningComposerTarget(_ application: NSRunningApplication) {
        guard let bundleID = application.bundleIdentifier else { return }
        addComposerTarget(
            ComposerTarget(
                bundleID: bundleID,
                name: application.localizedName ?? bundleID
            )
        )
    }

    func pasteLatestTranscript() {
        guard !latestTranscript.isEmpty else {
            showToast(
                "还没有可粘贴的转写",
                symbol: "text.badge.xmark",
                tint: .systemOrange,
                duration: 1.8
            )
            return
        }
        guard let target = latestTarget,
              let application = NSRunningApplication(processIdentifier: target.pid),
              !application.isTerminated,
              ProcessInfo.processInfo.systemUptime - target.capturedAt < 120
        else {
            _ = clipboard.copy(latestTranscript)
            showToast(
                "已复制，按 Cmd+V 粘贴",
                symbol: "doc.on.clipboard.fill",
                tint: .systemGreen,
                duration: 2.0
            )
            return
        }
        latestClipboardWrite = clipboard.copy(latestTranscript)
        restore(application: application)
        let generation = nextPasteGeneration()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) { [weak self] in
            Task { @MainActor in
                self?.performPaste(
                    target: target,
                    generation: generation,
                    isFallbackCopy: false
                )
            }
        }
    }

    func copyLatestTranscript() {
        guard !latestTranscript.isEmpty else { return }
        _ = clipboard.copy(latestTranscript)
        showToast(
            "已复制最新转写",
            symbol: "checkmark.circle.fill",
            tint: .systemGreen
        )
    }

    func requestAccessibilityPermission() {
        permissionPromptShown = true
        UserDefaults.standard.set(true, forKey: "permissionPromptShown")
        PermissionCenter.requestAccessibility()
        PermissionCenter.openAccessibilitySettings()
        refreshRuntime()
    }

    func openAccessibilitySettings() {
        PermissionCenter.openAccessibilitySettings()
    }

    func openInputMonitoringSettings() {
        PermissionCenter.openInputMonitoringSettings()
    }

    func openDiagnosticLog() {
        NSWorkspace.shared.open(paths.logURL)
    }

    func refreshLogTail() {
        logTail = diagnostics.tail(maxLines: 140)
    }

    func copyDiagnosticsSummary() {
        let text = """
        MiddleFlow diagnostics
        Version: \(Self.version)
        macOS: \(ProcessInfo.processInfo.operatingSystemVersionString)
        Accessibility: \(PermissionCenter.accessibilityGranted)
        Post events: \(PermissionCenter.canPostEvents)
        Mapping active: \(runtime.mappingActive)
        Microphone active: \(runtime.microphoneActive)
        Voice state: \(runtime.voiceState)
        Mapped clicks: \(runtime.mappedClicks)
        Double-click sends: \(runtime.doubleClickSends)
        Last error: \(runtime.lastError)
        """
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        showToast(
            "诊断摘要已复制",
            symbol: "checkmark.circle.fill",
            tint: .systemGreen
        )
    }

    func openGitHub() {
        if let url = URL(string: "https://github.com/leicheng42/MiddleFlow") {
            NSWorkspace.shared.open(url)
        }
    }

    func openPrivacy() {
        if let url = URL(string: "https://github.com/leicheng42/MiddleFlow/blob/main/PRIVACY.md") {
            NSWorkspace.shared.open(url)
        }
    }

    func quit() {
        cancelAllScheduledWork()
        keyboard.releaseHeldModifier()
        eventTap.stop()
        NSApp.terminate(nil)
    }

    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "2.0.0"
    }

    private var shouldShowSettingsOnLaunch: Bool {
        if isPreview || CommandLine.arguments.contains("--show-settings") {
            return true
        }
        return !preferences.onboardingCompleted
    }

    private var legacyBridgeIsRunning: Bool {
        NSRunningApplication
            .runningApplications(withBundleIdentifier: "local.leicheng.middle-option-bridge")
            .contains { !$0.isTerminated }
    }

    private func syncLoginItemState() {
        guard !isPreview else {
            preferences.launchAtLogin = LoginItemManager.isEnabled
            return
        }
        let inApplications = Bundle.main.bundleURL.path.contains("/Applications/")
        if inApplications,
           preferences.launchAtLogin,
           !LoginItemManager.isEnabled {
            do {
                try LoginItemManager.setEnabled(true)
            } catch {
                loginItemError = error.localizedDescription
                diagnostics.write("LOGIN_ITEM_REGISTER_ERROR \(error.localizedDescription)")
            }
        }
        preferences.launchAtLogin = LoginItemManager.isEnabled
    }

    private func buildStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.image = NSImage(
                systemSymbolName: "cursorarrow.click.2",
                accessibilityDescription: "MiddleFlow"
            )
            button.imagePosition = .imageLeading
            button.title = " MiddleFlow"
            button.font = .systemFont(ofSize: 12, weight: .semibold)
            button.toolTip = "MiddleFlow"
        }
        let menu = NSMenu()
        menu.autoenablesItems = false

        let open = NSMenuItem(
            title: "打开 MiddleFlow",
            action: #selector(menuOpenSettings),
            keyEquivalent: ","
        )
        open.target = self
        menu.addItem(open)

        let summary = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        summary.isEnabled = false
        menu.addItem(summary)
        menu.addItem(.separator())

        mappingMenuItem = NSMenuItem(
            title: "",
            action: #selector(menuToggleMapping),
            keyEquivalent: ""
        )
        mappingMenuItem?.target = self
        menu.addItem(mappingMenuItem!)

        let test = NSMenuItem(
            title: "打开语音测试窗口",
            action: #selector(menuShowTestWindow),
            keyEquivalent: ""
        )
        test.target = self
        menu.addItem(test)

        let paste = NSMenuItem(
            title: "粘贴最新转写",
            action: #selector(menuPasteLatest),
            keyEquivalent: ""
        )
        paste.target = self
        menu.addItem(paste)
        menu.addItem(.separator())

        let permissions = NSMenuItem(
            title: "检查辅助功能权限",
            action: #selector(menuRequestPermission),
            keyEquivalent: ""
        )
        permissions.target = self
        menu.addItem(permissions)

        let log = NSMenuItem(
            title: "打开诊断日志",
            action: #selector(menuOpenLog),
            keyEquivalent: ""
        )
        log.target = self
        menu.addItem(log)
        menu.addItem(.separator())

        let quit = NSMenuItem(
            title: "退出 MiddleFlow",
            action: #selector(menuQuit),
            keyEquivalent: "q"
        )
        quit.target = self
        menu.addItem(quit)

        item.menu = menu
        statusItem = item
        statusMenu = menu
        refreshStatusItem()
    }

    private func refreshStatusItem() {
        let state = runtime.mappingActive ? "已开启" : "已暂停"
        let summary = statusMenu?.items.first(where: { $0.action == nil && !$0.isSeparatorItem })
        summary?.title = "\(state) · \(preferences.voiceShortcut.shortTitle)"
        mappingMenuItem?.title = preferences.mappingEnabled ? "暂停中键映射" : "开启中键映射"
        statusItem?.button?.appearsDisabled = !preferences.mappingEnabled
    }

    private func startEventTap() {
        guard !isPreview else { return }
        guard !legacyBridgeIsRunning else {
            runtime.mappingActive = false
            runtime.lastError = "检测到旧版 MiddleOptionBridge 正在运行"
            diagnostics.write("TAP_SKIPPED_LEGACY_BRIDGE_RUNNING")
            refreshRuntime()
            return
        }
        if eventTap.start() {
            runtime.mappingActive = true
            runtime.lastError = ""
            diagnostics.write("TAP_STARTED")
        } else {
            runtime.mappingActive = false
            runtime.lastError = "需要辅助功能权限"
            diagnostics.write(
                "TAP_CREATE_FAILED ax=\(PermissionCenter.accessibilityGranted) " +
                "post=\(PermissionCenter.canPostEvents)"
            )
            if !permissionPromptShown {
                permissionPromptShown = true
                UserDefaults.standard.set(true, forKey: "permissionPromptShown")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    PermissionCenter.requestAccessibility()
                }
            }
        }
        refreshRuntime()
    }

    private func poll() {
        if preferences.mappingEnabled,
           !isPreview,
           !eventTap.isRunning,
           !legacyBridgeIsRunning,
           PermissionCenter.accessibilityGranted,
           PermissionCenter.canPostEvents {
            startEventTap()
        }

        audio.refreshIfNeeded()
        let active = audio.isMicrophoneActive()
        if active != micActive {
            micActive = active
            if active {
                micStartedAt = Date()
                diagnostics.write("MICROPHONE_ACTIVE")
                if var session = voiceSession {
                    session.didSeeMicrophone = true
                    if session.state == .preparing || session.state == .listening {
                        session.state = .listening
                        voiceComposer?.setState(.listening)
                    }
                    voiceSession = session
                }
            } else {
                lastMicDuration = micStartedAt.map { Date().timeIntervalSince($0) } ?? 0
                micStartedAt = nil
                diagnostics.write(
                    "MICROPHONE_STOPPED duration=\(String(format: "%.2f", lastMicDuration))s"
                )
                if let session = voiceSession, session.state == .listening {
                    beginTranscription()
                }
            }
        }

        if pressed && Date().timeIntervalSince(pressedAt) > 10 {
            pressed = false
            keyboard.releaseHeldModifier()
        }

        if Date().timeIntervalSince(lastRuntimeRefresh) > 0.4 {
            refreshRuntime()
        }
        if Date().timeIntervalSince(lastStatusWrite) > 2 {
            writeStatus()
        }
    }

    private func refreshRuntime() {
        lastRuntimeRefresh = Date()
        runtime.accessibility = PermissionCenter.accessibilityGranted
        runtime.canPostEvents = PermissionCenter.canPostEvents
        runtime.mappingActive = preferences.mappingEnabled && eventTap.isRunning && !isPreview
        runtime.microphoneActive = micActive
        runtime.voiceState = voiceSession.map { Self.string(for: $0.state) } ?? "idle"
        runtime.mappedPresses = mappedPresses
        runtime.mappedClicks = mappedClicks
        runtime.doubleClickSends = doubleClickSends
        runtime.latestTranscriptCharacters = latestTranscript.count
        runtime.lastAutoPasteSent = lastAutoPasteSent
        runtime.updatedAt = Date()
        refreshStatusItem()
    }

    private func writeStatus() {
        lastStatusWrite = Date()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(runtime) {
            try? data.write(to: paths.statusURL, options: .atomic)
        }
    }

    private var mappedPresses = 0
    private var mappedClicks = 0
    private var doubleClickSends = 0
    private var lastAutoPasteSent: Bool?

    private func handleDirectClick(at point: CGPoint) {
        guard preferences.doubleClickEnabled else {
            sendVoiceShortcut()
            return
        }
        let now = ProcessInfo.processInfo.systemUptime
        switch directClassifier.ingest(at: now, point: point) {
        case .pendingSingle:
            cancelPendingSingle()
            let generation = directGeneration + 1
            directGeneration = generation
            let work = DispatchWorkItem { [weak self] in
                Task { @MainActor in
                    guard let self, self.directGeneration == generation,
                          self.preferences.mappingEnabled else { return }
                    self.sendVoiceShortcut()
                    self.directClassifier.reset()
                }
            }
            pendingSingleWorkItem = work
            DispatchQueue.main.asyncAfter(
                deadline: .now() + preferences.doubleClickInterval,
                execute: work
            )
        case .doubleClick:
            cancelPendingSingle()
            directGeneration += 1
            guard preferences.doubleClickAction == .returnKey else { return }
            doubleClickSends += 1
            _ = keyboard.sendReturn()
            diagnostics.write("DOUBLE_CLICK_RETURN")
            refreshRuntime()
        }
    }

    private func sendVoiceShortcut() {
        guard preferences.mappingEnabled else { return }
        mappedClicks += 1
        let sent = keyboard.sendVoiceShortcut(preferences.voiceShortcut)
        diagnostics.write(
            "VOICE_SHORTCUT_SENT shortcut=\(preferences.voiceShortcut.rawValue) sent=\(sent)"
        )
        refreshRuntime()
    }

    private func beginVoiceComposer(
        application: NSRunningApplication,
        point: CGPoint
    ) {
        guard voiceSession == nil, !composerTransitioning, !autoPasteInProgress else { return }
        guard let screen = screenContaining(NSEvent.mouseLocation) else {
            showToast(
                "找不到当前显示器",
                symbol: "display.trianglebadge.exclamationmark",
                tint: .systemOrange
            )
            return
        }
        composerGeneration += 1
        let generation = composerGeneration
        pendingReturnAfterPaste = false
        composerClassifier.reset()
        _ = composerClassifier.ingest(
            at: ProcessInfo.processInfo.systemUptime,
            point: point
        )
        let panel = ensureVoiceComposer()
        panel.configureBadge(shortcut: preferences.voiceShortcut)
        panel.resetForNewSession()
        voiceSession = VoiceSession(
            originalPID: application.processIdentifier,
            originalBundleID: application.bundleIdentifier ?? "",
            originalName: application.localizedName ?? "目标应用",
            startedAt: ProcessInfo.processInfo.systemUptime,
            clickPoint: point,
            state: .preparing
        )
        voiceComposerVisible = true
        lastComposerTextChangeAt = Date()
        panel.present(on: screen)
        diagnostics.write(
            "COMPOSER_OPENED target=\(application.bundleIdentifier ?? "unknown") " +
            "pid=\(application.processIdentifier)"
        )

        let work = DispatchWorkItem { [weak self] in
            Task { @MainActor in
                guard let self, self.composerGeneration == generation,
                      var session = self.voiceSession,
                      session.state == .preparing,
                      self.composerClassifier.pendingClickCount == 1 else { return }
                self.sendVoiceShortcut()
                session.optionSent = true
                session.state = .listening
                if self.micActive { session.didSeeMicrophone = true }
                self.voiceSession = session
                self.voiceComposer?.setState(.listening)
                self.composerClassifier.reset()
                self.diagnostics.write("COMPOSER_VOICE_STARTED")
                self.scheduleComposerStartTimeout(generation: generation)
            }
        }
        composerStartWorkItem = work
        DispatchQueue.main.asyncAfter(
            deadline: .now() + preferences.doubleClickInterval,
            execute: work
        )
    }

    private func handleComposerClick(at point: CGPoint) {
        guard var session = voiceSession else { return }
        let now = ProcessInfo.processInfo.systemUptime
        let gesture = composerClassifier.ingest(at: now, point: point)

        if session.state == .transcribing {
            if gesture == .doubleClick {
                pendingReturnAfterPaste = true
                diagnostics.write("RETURN_QUEUED_AFTER_TRANSCRIPT")
            }
            return
        }

        if session.state == .preparing {
            if gesture == .doubleClick {
                composerStartWorkItem?.cancel()
                composerStartWorkItem = nil
                cancelVoiceComposer(reason: "double_click_before_start")
                if preferences.doubleClickAction == .returnKey {
                    doubleClickSends += 1
                    _ = keyboard.sendReturn()
                    diagnostics.write("DOUBLE_CLICK_RETURN_BEFORE_VOICE")
                }
            }
            return
        }

        guard session.state == .listening else { return }
        if !preferences.doubleClickEnabled {
            stopVoiceAndTranscribe()
            return
        }
        if gesture == .doubleClick {
            composerToggleWorkItem?.cancel()
            composerToggleWorkItem = nil
            pendingReturnAfterPaste = true
            diagnostics.write("RETURN_QUEUED_AFTER_STOP")
            stopVoiceAndTranscribe()
            return
        }
        let generation = composerGeneration
        let work = DispatchWorkItem { [weak self] in
            Task { @MainActor in
                guard let self, self.composerGeneration == generation,
                      self.voiceSession?.state == .listening else { return }
                self.stopVoiceAndTranscribe()
            }
        }
        composerToggleWorkItem = work
        DispatchQueue.main.asyncAfter(
            deadline: .now() + preferences.doubleClickInterval,
            execute: work
        )
        session.didSeeMicrophone = session.didSeeMicrophone || micActive
        voiceSession = session
    }

    private func stopVoiceAndTranscribe() {
        guard var session = voiceSession, session.state == .listening else { return }
        composerToggleWorkItem?.cancel()
        composerToggleWorkItem = nil
        composerClassifier.reset()
        mappedClicks += 1
        session.state = .transcribing
        session.stoppedAt = ProcessInfo.processInfo.systemUptime
        voiceSession = session
        _ = keyboard.sendVoiceShortcut(preferences.voiceShortcut)
        voiceComposer?.setState(.transcribing)
        lastComposerTextChangeAt = Date()
        diagnostics.write("VOICE_STOP_REQUESTED")
        scheduleTranscriptCheck(after: 0.16)
    }

    private func beginTranscription() {
        guard var session = voiceSession, session.state == .listening else { return }
        session.state = .transcribing
        session.stoppedAt = ProcessInfo.processInfo.systemUptime
        voiceSession = session
        composerTimeoutWorkItem?.cancel()
        composerTimeoutWorkItem = nil
        lastComposerTextChangeAt = Date()
        voiceComposer?.setState(.transcribing)
        diagnostics.write("TRANSCRIBING")
        scheduleTranscriptCheck(after: 0.18)
    }

    private func scheduleComposerStartTimeout(generation: Int) {
        composerTimeoutWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            Task { @MainActor in
                guard let self, self.composerGeneration == generation,
                      let session = self.voiceSession,
                      session.state == .listening,
                      !session.didSeeMicrophone,
                      !self.micActive else { return }
                self.failVoiceComposer(
                    "没有检测到麦克风，请重试",
                    reason: "microphone_not_started"
                )
            }
        }
        composerTimeoutWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 8, execute: work)
    }

    private func scheduleTranscriptCheck(after delay: TimeInterval) {
        transcriptCheckWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            Task { @MainActor in
                self?.checkTranscriptReady()
            }
        }
        transcriptCheckWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private func checkTranscriptReady() {
        guard let session = voiceSession, session.state == .transcribing,
              let composer = voiceComposer else { return }
        let text = composer.text.trimmingCharacters(in: .whitespacesAndNewlines)
        let now = ProcessInfo.processInfo.systemUptime
        let stoppedAt = session.stoppedAt ?? now
        let elapsed = now - stoppedAt
        let stableFor = Date().timeIntervalSince(lastComposerTextChangeAt)

        if !text.isEmpty,
           !composer.hasMarkedText,
           elapsed >= 0.30,
           stableFor >= 0.26 {
            finishVoiceComposer(with: text, session: session)
            return
        }
        if elapsed >= 4.0 {
            if text.isEmpty {
                failVoiceComposer("没有收到文字，请重试", reason: "empty_transcript")
            } else if composer.hasMarkedText {
                failVoiceComposer("转写尚未完成，请重试", reason: "marked_text_timeout")
            } else {
                finishVoiceComposer(with: text, session: session)
            }
            return
        }
        scheduleTranscriptCheck(after: 0.09)
    }

    private func finishVoiceComposer(with text: String, session: VoiceSession) {
        guard voiceSession != nil else { return }
        cancelSessionTimers()
        voiceSession = nil
        voiceComposerVisible = false
        latestTranscript = text
        latestTranscriptAvailable = true
        latestTarget = LatestTarget(
            pid: session.originalPID,
            bundleID: session.originalBundleID,
            point: session.clickPoint,
            capturedAt: ProcessInfo.processInfo.systemUptime
        )
        latestClipboardWrite = clipboard.copy(text)
        voiceComposer?.setState(.copied)
        diagnostics.write("TRANSCRIPT_READY chars=\(text.count)")
        refreshRuntime()

        let screen = screenContaining(NSEvent.mouseLocation)
        let shouldPaste = preferences.autoPaste
        autoPasteInProgress = shouldPaste
        composerTransitioning = true
        let generation = composerGeneration
        restoreApplication(pid: session.originalPID)
        voiceComposer?.dismiss(animated: true) { [weak self] in
            Task { @MainActor in
                guard let self, self.composerGeneration == generation else { return }
                self.composerTransitioning = false
            }
        }

        if shouldPaste {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.20) { [weak self] in
                Task { @MainActor in
                    guard let self, self.composerGeneration == generation else { return }
                    self.attemptAutoPaste(session: session, screen: screen)
                }
            }
        } else {
            autoPasteInProgress = false
            pendingReturnAfterPaste = false
            showToast(
                "已复制，按 Cmd+V 粘贴",
                symbol: "doc.on.clipboard.fill",
                tint: .systemOrange,
                on: screen,
                duration: 2.2
            )
            refreshRuntime()
        }
    }

    private func attemptAutoPaste(session: VoiceSession, screen: NSScreen?) {
        guard let application = NSRunningApplication(processIdentifier: session.originalPID),
              !application.isTerminated else {
            failPaste(screen: screen)
            return
        }
        let generation = nextPasteGeneration()
        if !isFrontmost(pid: session.originalPID) {
            restore(application: application)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { [weak self] in
                Task { @MainActor in
                    self?.performPaste(
                        target: LatestTarget(
                            pid: session.originalPID,
                            bundleID: session.originalBundleID,
                            point: session.clickPoint,
                            capturedAt: session.startedAt
                        ),
                        generation: generation,
                        isFallbackCopy: false
                    )
                }
            }
            return
        }
        performPaste(
            target: LatestTarget(
                pid: session.originalPID,
                bundleID: session.originalBundleID,
                point: session.clickPoint,
                capturedAt: session.startedAt
            ),
            generation: generation,
            isFallbackCopy: false
        )
    }

    private func performPaste(
        target: LatestTarget,
        generation: Int,
        isFallbackCopy: Bool
    ) {
        guard generation == latestPasteGeneration,
              let application = NSRunningApplication(processIdentifier: target.pid),
              !application.isTerminated,
              isFrontmost(pid: target.pid) else {
            failPaste(screen: screenContaining(NSEvent.mouseLocation))
            return
        }
        let age = ProcessInfo.processInfo.systemUptime - target.capturedAt
        guard age < 120 else {
            failPaste(screen: screenContaining(NSEvent.mouseLocation))
            return
        }
        if !isFallbackCopy {
            _ = postLeftClick(at: target.point)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in
            Task { @MainActor in
                guard let self, generation == self.latestPasteGeneration,
                      self.isFrontmost(pid: target.pid),
                      self.keyboard.sendPaste() else {
                    self?.failPaste(screen: self?.screenContaining(NSEvent.mouseLocation))
                    return
                }
                self.lastAutoPasteSent = true
                self.diagnostics.write("PASTE_SHORTCUT_SENT")
                self.showToast(
                    "已发送粘贴",
                    symbol: "arrow.down.doc.fill",
                    tint: .systemGreen
                )
                if self.preferences.pasteThenReturn || self.pendingReturnAfterPaste {
                    self.pendingReturnAfterPaste = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { [weak self] in
                        Task { @MainActor in
                            guard let self else { return }
                            _ = self.keyboard.sendReturn()
                            self.diagnostics.write("RETURN_AFTER_PASTE_SENT")
                            self.finishPasteCycle()
                        }
                    }
                } else {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.38) { [weak self] in
                        Task { @MainActor in
                            self?.finishPasteCycle()
                        }
                    }
                }
            }
        }
    }

    private func finishPasteCycle() {
        autoPasteInProgress = false
        pendingReturnAfterPaste = false
        refreshRuntime()
        if preferences.restoreClipboardAfterPaste,
           let write = latestClipboardWrite {
            let captured = write
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                Task { @MainActor in
                    _ = self?.clipboard.restoreIfUnchanged(captured)
                }
            }
        }
    }

    private func failPaste(screen: NSScreen?) {
        autoPasteInProgress = false
        pendingReturnAfterPaste = false
        lastAutoPasteSent = false
        refreshRuntime()
        showToast(
            "已复制，请按 Cmd+V 粘贴",
            symbol: "doc.on.clipboard.fill",
            tint: .systemOrange,
            on: screen,
            duration: 2.2
        )
    }

    private func nextPasteGeneration() -> Int {
        latestPasteGeneration += 1
        return latestPasteGeneration
    }

    private func registerPostPasteClick(at point: CGPoint) {
        let now = ProcessInfo.processInfo.systemUptime
        if directClassifier.ingest(at: now, point: point) == .doubleClick {
            pendingReturnAfterPaste = true
            diagnostics.write("RETURN_QUEUED_DURING_PASTE")
        }
    }

    private func cancelVoiceComposer(reason: String) {
        guard let session = voiceSession else { return }
        cancelSessionTimers()
        if session.state == .listening {
            _ = keyboard.sendVoiceShortcut(preferences.voiceShortcut)
        }
        voiceSession = nil
        voiceComposerVisible = false
        pendingReturnAfterPaste = false
        autoPasteInProgress = false
        composerGeneration += 1
        diagnostics.write("COMPOSER_CANCELLED reason=\(reason)")
        voiceComposer?.dismiss(animated: true) { [weak self] in
            Task { @MainActor in
                self?.restoreApplication(pid: session.originalPID)
            }
        }
        refreshRuntime()
    }

    private func failVoiceComposer(_ message: String, reason: String) {
        guard let session = voiceSession else { return }
        cancelSessionTimers()
        if session.state == .listening {
            _ = keyboard.sendVoiceShortcut(preferences.voiceShortcut)
        }
        voiceSession = nil
        voiceComposerVisible = false
        pendingReturnAfterPaste = false
        autoPasteInProgress = false
        composerGeneration += 1
        diagnostics.write("COMPOSER_FAILED reason=\(reason)")
        let screen = screenContaining(NSEvent.mouseLocation)
        voiceComposer?.dismiss(animated: true) { [weak self] in
            Task { @MainActor in
                self?.restoreApplication(pid: session.originalPID)
                self?.showToast(
                    message,
                    symbol: "exclamationmark.triangle.fill",
                    tint: .systemOrange,
                    on: screen,
                    duration: 2.2
                )
            }
        }
        refreshRuntime()
    }

    private func ensureVoiceComposer() -> VoiceComposerPanel {
        if let voiceComposer { return voiceComposer }
        let panel = VoiceComposerPanel()
        panel.onCancel = { [weak self] in
            Task { @MainActor in
                self?.cancelVoiceComposer(reason: "escape_or_close")
            }
        }
        panel.onTextChanged = { [weak self] in
            Task { @MainActor in
                self?.lastComposerTextChangeAt = Date()
            }
        }
        voiceComposer = panel
        return panel
    }

    private func restoreApplication(pid: pid_t) {
        guard let application = NSRunningApplication(processIdentifier: pid) else { return }
        NSApp.deactivate()
        let activated = application.activate(options: [])
        diagnostics.write("RESTORE_APP pid=\(pid) activated=\(activated)")
    }

    private func restore(application: NSRunningApplication) {
        NSApp.deactivate()
        _ = application.activate(options: [])
    }

    private func isFrontmost(pid: pid_t) -> Bool {
        NSWorkspace.shared.frontmostApplication?.processIdentifier == pid
    }

    @discardableResult
    private func postLeftClick(at point: CGPoint) -> Bool {
        guard let screen = screenContaining(point) else { return false }
        guard screen.frame.contains(point) else { return false }
        let source = CGEventSource(stateID: .hidSystemState) ??
            CGEventSource(stateID: .privateState)
        guard let down = CGEvent(
            mouseEventSource: source,
            mouseType: .leftMouseDown,
            mouseCursorPosition: point,
            mouseButton: .left
        ), let up = CGEvent(
            mouseEventSource: source,
            mouseType: .leftMouseUp,
            mouseCursorPosition: point,
            mouseButton: .left
        ) else { return false }
        down.setIntegerValueField(.eventSourceUserData, value: KeyboardSynthesizer.eventMarker)
        up.setIntegerValueField(.eventSourceUserData, value: KeyboardSynthesizer.eventMarker)
        down.post(tap: .cghidEventTap)
        usleep(20_000)
        up.post(tap: .cghidEventTap)
        diagnostics.write("REMOTE_FOCUS_CLICK_SENT")
        return true
    }

    private func screenContaining(_ point: CGPoint) -> NSScreen? {
        NSScreen.screens.first { $0.frame.contains(point) } ?? NSScreen.main
    }

    private func showToast(
        _ message: String,
        symbol: String,
        tint: NSColor,
        on screen: NSScreen? = nil,
        duration: TimeInterval = 1.55
    ) {
        guard let screen = screen ?? screenContaining(NSEvent.mouseLocation) else { return }
        if statusToast == nil { statusToast = StatusToastPanel() }
        statusToast?.show(
            message: message,
            symbol: symbol,
            tint: tint,
            on: screen,
            duration: duration
        )
    }

    private func cancelPendingSingle() {
        pendingSingleWorkItem?.cancel()
        pendingSingleWorkItem = nil
        directGeneration += 1
        directClassifier.reset()
    }

    private func cancelSessionTimers() {
        composerStartWorkItem?.cancel()
        composerStartWorkItem = nil
        composerToggleWorkItem?.cancel()
        composerToggleWorkItem = nil
        transcriptCheckWorkItem?.cancel()
        transcriptCheckWorkItem = nil
        composerTimeoutWorkItem?.cancel()
        composerTimeoutWorkItem = nil
        composerClassifier.reset()
    }

    private func cancelAllScheduledWork() {
        cancelPendingSingle()
        cancelSessionTimers()
        autoPasteInProgress = false
        pendingReturnAfterPaste = false
    }

    private func persistPreferences() {
        preferencesStore.save(preferences)
        objectWillChange.send()
    }

    private func installSignalHandlers() {
        for number in [SIGTERM, SIGINT] {
            signal(number, SIG_IGN)
            let source = DispatchSource.makeSignalSource(signal: number, queue: .main)
            source.setEventHandler { [weak self] in
                Task { @MainActor in
                    self?.quit()
                }
            }
            source.resume()
            signalSources.append(source)
        }
    }

    private static func string(for state: VoiceComposerState) -> String {
        switch state {
        case .preparing: return "preparing"
        case .listening: return "listening"
        case .transcribing: return "transcribing"
        case .copied: return "copied"
        }
    }

    private func runSelfTest() {
        showTestWindow()
        guard let window = testWindowController?.window else { return }
        let query = [kTISPropertyInputSourceID: "com.bytedance.inputmethod.doubaoime.pinyin"] as CFDictionary
        if let sources = TISCreateInputSourceList(query, false)?.takeRetainedValue() as? [TISInputSource],
           let doubao = sources.first {
            _ = TISSelectInputSource(doubao)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                let rect = window.frame
                let point = CGPoint(x: rect.midX, y: rect.midY)
                self.postMiddleTestEvent(down: true, at: point)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                    Task { @MainActor in
                        self.postMiddleTestEvent(down: false, at: point)
                    }
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                    Task { @MainActor in
                        self.diagnostics.write(
                            "SELF_TEST_RESULT mapped=\(self.mappedPresses) " +
                            "mic=\(self.micActive) " +
                            "voice=\(self.runtime.voiceState)"
                        )
                    }
                }
            }
        }
    }

    private func postMiddleTestEvent(down: Bool, at point: CGPoint) {
        guard let event = CGEvent(
            mouseEventSource: CGEventSource(stateID: .privateState),
            mouseType: down ? .otherMouseDown : .otherMouseUp,
            mouseCursorPosition: point,
            mouseButton: .center
        ) else { return }
        event.setIntegerValueField(.eventSourceUserData, value: KeyboardSynthesizer.eventMarker)
        event.post(tap: .cghidEventTap)
        diagnostics.write("SELF_TEST_MIDDLE_\(down ? "DOWN" : "UP")")
    }

    private func runComposerDemo() {
        guard let screen = screenContaining(NSEvent.mouseLocation) else { return }
        composerGeneration += 1
        let panel = ensureVoiceComposer()
        panel.configureBadge(shortcut: preferences.voiceShortcut)
        panel.resetForNewSession()
        panel.present(on: screen)
        let app = NSWorkspace.shared.frontmostApplication
        voiceSession = VoiceSession(
            originalPID: app?.processIdentifier ?? getpid(),
            originalBundleID: app?.bundleIdentifier ?? "",
            originalName: app?.localizedName ?? "MiddleFlow",
            startedAt: ProcessInfo.processInfo.systemUptime,
            clickPoint: NSEvent.mouseLocation,
            state: .listening,
            didSeeMicrophone: true
        )
        panel.setState(.listening)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { [weak self] in
            self?.voiceComposer?.setText("这是语音输入的预览文字，可以直接编辑后再粘贴到目标应用。")
            self?.voiceComposer?.setState(.transcribing)
        }
    }

    @objc private func menuOpenSettings() { showSettings() }
    @objc private func menuToggleMapping() { toggleMapping() }
    @objc private func menuShowTestWindow() { showTestWindow() }
    @objc private func menuPasteLatest() { pasteLatestTranscript() }
    @objc private func menuRequestPermission() { requestAccessibilityPermission() }
    @objc private func menuOpenLog() { openDiagnosticLog() }
    @objc private func menuQuit() { quit() }
}

extension AppController: @preconcurrency EventTapServiceDelegate {
    func eventTapDidReceiveMiddleDown(at point: CGPoint) {
        guard preferences.mappingEnabled else { return }
        guard !pressed else { return }
        pressed = true
        pressedAt = Date()
        mappedPresses += 1
        runtime.mappedPresses = mappedPresses
        if autoPasteInProgress {
            registerPostPasteClick(at: point)
            return
        }
        if voiceSession != nil {
            handleComposerClick(at: point)
            return
        }
        let frontmost = NSWorkspace.shared.frontmostApplication
        let behavior = TargetPolicy.behavior(
            for: frontmost?.bundleIdentifier,
            composerBundleIDs: preferences.composerBundleIDs
        )
        switch behavior {
        case .composer:
            if let frontmost {
                beginVoiceComposer(application: frontmost, point: point)
            } else {
                handleDirectClick(at: point)
            }
        case .directShortcut:
            handleDirectClick(at: point)
        }
    }

    func eventTapDidReceiveMiddleUp() {
        pressed = false
    }

    func eventTapDidDisableTemporarily() {
        diagnostics.write("TAP_REENABLED")
        keyboard.releaseHeldModifier()
    }
}
