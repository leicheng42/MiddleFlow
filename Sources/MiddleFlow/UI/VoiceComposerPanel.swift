import AppKit
import QuartzCore

enum VoiceComposerState {
    case preparing
    case listening
    case transcribing
    case copied

    var title: String {
        switch self {
        case .preparing: return "准备麦克风…"
        case .listening: return "正在聆听…"
        case .transcribing: return "正在转写…"
        case .copied: return "已复制，准备粘贴…"
        }
    }
}

final class ComposerTextView: NSTextView {
    var placeholderText = "" {
        didSet { needsDisplay = true }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard string.isEmpty, markedRange().location == NSNotFound else { return }
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font ?? NSFont.systemFont(ofSize: 18),
            .foregroundColor: NSColor.tertiaryLabelColor
        ]
        let padding = textContainer?.lineFragmentPadding ?? 0
        let rect = NSRect(
            x: textContainerInset.width + padding,
            y: textContainerInset.height,
            width: max(0, bounds.width - textContainerInset.width * 2 - padding * 2),
            height: min(28, bounds.height)
        )
        (placeholderText as NSString).draw(in: rect, withAttributes: attributes)
    }

    override func didChangeText() {
        super.didChangeText()
        needsDisplay = true
    }

    override func setMarkedText(
        _ string: Any,
        selectedRange: NSRange,
        replacementRange: NSRange
    ) {
        super.setMarkedText(
            string,
            selectedRange: selectedRange,
            replacementRange: replacementRange
        )
        needsDisplay = true
    }

    override func unmarkText() {
        super.unmarkText()
        needsDisplay = true
    }
}

final class ComposerWaveformView: NSView {
    var tintColor = NSColor.systemOrange {
        didSet { needsDisplay = true }
    }
    private(set) var active = false
    private var phase: CGFloat = 0
    private var timer: Timer?

    override var intrinsicContentSize: NSSize {
        NSSize(width: 30, height: 20)
    }

    func startAnimating() {
        active = true
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) {
            [weak self] _ in
            guard let self else { return }
            self.phase += 0.18
            self.needsDisplay = true
        }
    }

    func stopAnimating() {
        active = false
        timer?.invalidate()
        timer = nil
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let barWidth: CGFloat = 3
        let gap: CGFloat = 3.5
        let count = 5
        let totalWidth = CGFloat(count) * barWidth + CGFloat(count - 1) * gap
        let startX = (bounds.width - totalWidth) / 2
        let base: [CGFloat] = [0.40, 0.76, 0.56, 0.96, 0.48]
        tintColor.setFill()
        for index in 0..<count {
            let wave = active
                ? (sin(phase + CGFloat(index) * 1.18) + 1) / 2
                : CGFloat(0.22)
            let height = max(3, bounds.height * (0.20 + 0.80 * wave * base[index]))
            let rect = NSRect(
                x: startX + CGFloat(index) * (barWidth + gap),
                y: (bounds.height - height) / 2,
                width: barWidth,
                height: height
            )
            NSBezierPath(roundedRect: rect, xRadius: 1.5, yRadius: 1.5).fill()
        }
    }

    deinit {
        timer?.invalidate()
    }
}

final class VoiceComposerPanel: NSPanel, NSTextViewDelegate {
    static let width: CGFloat = 476
    static let height: CGFloat = 164

    var onCancel: (() -> Void)?
    var onTextChanged: (() -> Void)?

    private let effectView = NSVisualEffectView()
    private let backdrop = NSView()
    private let waveform = ComposerWaveformView()
    private let titleLabel = NSTextField(labelWithString: "语音输入")
    private let statusLabel = NSTextField(labelWithString: "准备中")
    private let hintLabel = NSTextField(labelWithString: "")
    private let badgeLabel = NSTextField(labelWithString: "豆包 · Right Option")
    private let textScroll = NSScrollView()
    private let textView = ComposerTextView()
    private let closeButton = NSButton()
    private var escapeMonitor: Any?
    private var dismissInProgress = false
    private var targetFrame = NSRect.zero

    var text: String { textView.string }
    var hasMarkedText: Bool { textView.markedRange().location != NSNotFound }

    func commitMarkedText() {
        textView.unmarkText()
    }

    func setMarkedTextForTesting(_ text: String) {
        let selection = NSRange(location: text.utf16.count, length: 0)
        textView.setMarkedText(
            text,
            selectedRange: selection,
            replacementRange: NSRange(location: NSNotFound, length: 0)
        )
        onTextChanged?()
    }

    init() {
        let rect = NSRect(x: 0, y: 0, width: Self.width, height: Self.height)
        super.init(
            contentRect: rect,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        isMovableByWindowBackground = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        animationBehavior = .utilityWindow
        becomesKeyOnlyIfNeeded = false

        effectView.frame = NSRect(origin: .zero, size: rect.size)
        effectView.autoresizingMask = [.width, .height]
        effectView.material = .hudWindow
        effectView.blendingMode = .behindWindow
        effectView.state = .active
        effectView.appearance = NSAppearance(named: .darkAqua)
        effectView.wantsLayer = true
        effectView.layer?.cornerRadius = 23
        effectView.layer?.masksToBounds = true
        effectView.layer?.borderWidth = 0.5
        effectView.layer?.borderColor = NSColor.white.withAlphaComponent(0.16).cgColor
        contentView = effectView

        backdrop.translatesAutoresizingMaskIntoConstraints = false
        backdrop.wantsLayer = true
        backdrop.layer?.backgroundColor = NSColor(calibratedWhite: 0.035, alpha: 0.80).cgColor
        effectView.addSubview(backdrop)
        NSLayoutConstraint.activate([
            backdrop.leadingAnchor.constraint(equalTo: effectView.leadingAnchor),
            backdrop.trailingAnchor.constraint(equalTo: effectView.trailingAnchor),
            backdrop.topAnchor.constraint(equalTo: effectView.topAnchor),
            backdrop.bottomAnchor.constraint(equalTo: effectView.bottomAnchor)
        ])
        setupViews()
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    func configureBadge(shortcut: VoiceShortcut) {
        badgeLabel.stringValue = "豆包 · \(shortcut.shortTitle)"
    }

    private func setupViews() {
        waveform.translatesAutoresizingMaskIntoConstraints = false
        waveform.tintColor = .systemOrange
        effectView.addSubview(waveform)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        titleLabel.textColor = .labelColor
        titleLabel.lineBreakMode = .byTruncatingTail
        effectView.addSubview(titleLabel)

        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.font = .systemFont(ofSize: 11.5, weight: .medium)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.lineBreakMode = .byTruncatingTail
        effectView.addSubview(statusLabel)

        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.isBordered = false
        closeButton.image = NSImage(
            systemSymbolName: "xmark.circle.fill",
            accessibilityDescription: "取消语音输入"
        )
        closeButton.symbolConfiguration = NSImage.SymbolConfiguration(
            pointSize: 16,
            weight: .regular
        )
        closeButton.contentTintColor = .secondaryLabelColor
        closeButton.toolTip = "取消（Esc）"
        closeButton.target = self
        closeButton.action = #selector(closePressed)
        effectView.addSubview(closeButton)

        textScroll.translatesAutoresizingMaskIntoConstraints = false
        textScroll.drawsBackground = false
        textScroll.borderType = .noBorder
        textScroll.hasVerticalScroller = false
        textScroll.hasHorizontalScroller = false
        textScroll.autohidesScrollers = true
        textScroll.documentView = textView
        effectView.addSubview(textScroll)

        textView.frame = NSRect(x: 0, y: 0, width: 430, height: 50)
        textView.autoresizingMask = [.width]
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(
            width: 430,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.drawsBackground = false
        textView.isRichText = false
        textView.isEditable = true
        textView.isSelectable = true
        textView.font = .systemFont(ofSize: 18, weight: .regular)
        textView.textColor = .labelColor
        textView.insertionPointColor = .systemOrange
        textView.textContainerInset = NSSize(width: 0, height: 5)
        textView.textContainer?.lineFragmentPadding = 0
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.delegate = self
        textView.placeholderText = "请说话，文字会出现在这里…"

        hintLabel.translatesAutoresizingMaskIntoConstraints = false
        hintLabel.font = .systemFont(ofSize: 11, weight: .regular)
        hintLabel.textColor = .tertiaryLabelColor
        hintLabel.stringValue = "单击结束  ·  双击发送  ·  Esc 取消"
        effectView.addSubview(hintLabel)

        badgeLabel.translatesAutoresizingMaskIntoConstraints = false
        badgeLabel.font = .monospacedSystemFont(ofSize: 10.5, weight: .medium)
        badgeLabel.textColor = .tertiaryLabelColor
        badgeLabel.alignment = .right
        effectView.addSubview(badgeLabel)

        NSLayoutConstraint.activate([
            waveform.leadingAnchor.constraint(equalTo: effectView.leadingAnchor, constant: 23),
            waveform.topAnchor.constraint(equalTo: effectView.topAnchor, constant: 21),
            waveform.widthAnchor.constraint(equalToConstant: 30),
            waveform.heightAnchor.constraint(equalToConstant: 20),

            titleLabel.leadingAnchor.constraint(equalTo: effectView.leadingAnchor, constant: 56),
            titleLabel.topAnchor.constraint(equalTo: effectView.topAnchor, constant: 14),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: closeButton.leadingAnchor, constant: -12),

            statusLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            statusLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            statusLabel.trailingAnchor.constraint(lessThanOrEqualTo: closeButton.leadingAnchor, constant: -12),

            closeButton.trailingAnchor.constraint(equalTo: effectView.trailingAnchor, constant: -17),
            closeButton.topAnchor.constraint(equalTo: effectView.topAnchor, constant: 15),
            closeButton.widthAnchor.constraint(equalToConstant: 18),
            closeButton.heightAnchor.constraint(equalToConstant: 18),

            textScroll.leadingAnchor.constraint(equalTo: effectView.leadingAnchor, constant: 23),
            textScroll.trailingAnchor.constraint(equalTo: effectView.trailingAnchor, constant: -23),
            textScroll.topAnchor.constraint(equalTo: effectView.topAnchor, constant: 66),
            textScroll.heightAnchor.constraint(equalToConstant: 50),

            hintLabel.leadingAnchor.constraint(equalTo: effectView.leadingAnchor, constant: 23),
            hintLabel.bottomAnchor.constraint(equalTo: effectView.bottomAnchor, constant: -14),
            hintLabel.trailingAnchor.constraint(lessThanOrEqualTo: badgeLabel.leadingAnchor, constant: -12),

            badgeLabel.trailingAnchor.constraint(equalTo: effectView.trailingAnchor, constant: -23),
            badgeLabel.bottomAnchor.constraint(equalTo: effectView.bottomAnchor, constant: -14)
        ])
    }

    func resetForNewSession() {
        textView.string = ""
        textView.needsDisplay = true
        setState(.preparing)
    }

    func setText(_ text: String) {
        textView.string = text
        textView.needsDisplay = true
        let length = (textView.string as NSString).length
        textView.setSelectedRange(NSRange(location: length, length: 0))
        onTextChanged?()
    }

    func setState(_ state: VoiceComposerState) {
        statusLabel.stringValue = state.title
        switch state {
        case .preparing:
            statusLabel.textColor = NSColor.systemOrange.withAlphaComponent(0.82)
            waveform.tintColor = .systemOrange
            waveform.startAnimating()
        case .listening:
            statusLabel.textColor = .systemOrange
            waveform.tintColor = .systemOrange
            waveform.startAnimating()
        case .transcribing:
            statusLabel.textColor = .systemOrange
            waveform.tintColor = .systemOrange
            waveform.startAnimating()
        case .copied:
            statusLabel.textColor = .systemGreen
            waveform.tintColor = .systemGreen
            waveform.stopAnimating()
        }
    }

    func focusEditor() {
        makeFirstResponder(textView)
        let length = (textView.string as NSString).length
        textView.setSelectedRange(NSRange(location: length, length: 0))
    }

    func present(on screen: NSScreen) {
        dismissInProgress = false
        let visible = screen.visibleFrame
        targetFrame = NSRect(
            x: visible.midX - Self.width / 2,
            y: visible.minY + 56,
            width: Self.width,
            height: Self.height
        )
        let startFrame = targetFrame.offsetBy(dx: 0, dy: -12)
        alphaValue = 0
        setFrame(startFrame, display: false)
        makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        focusEditor()
        installEscapeMonitor()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.20
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            animator().alphaValue = 1
            animator().setFrame(targetFrame, display: true)
        }
    }

    func dismiss(animated: Bool = true, completion: (() -> Void)? = nil) {
        guard !dismissInProgress else { return }
        dismissInProgress = true
        removeEscapeMonitor()
        waveform.stopAnimating()
        let endFrame = frame.offsetBy(dx: 0, dy: -8)
        let finish = { [weak self] in
            self?.orderOut(nil)
            self?.dismissInProgress = false
            completion?()
        }
        guard animated, isVisible else {
            finish()
            return
        }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.14
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            animator().alphaValue = 0
            animator().setFrame(endFrame, display: true)
        } completionHandler: {
            finish()
        }
    }

    private func installEscapeMonitor() {
        removeEscapeMonitor()
        escapeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) {
            [weak self] event in
            guard event.keyCode == 53 else { return event }
            self?.onCancel?()
            return nil
        }
    }

    private func removeEscapeMonitor() {
        if let escapeMonitor {
            NSEvent.removeMonitor(escapeMonitor)
            self.escapeMonitor = nil
        }
    }

    @objc private func closePressed() {
        onCancel?()
    }

    func textDidChange(_ notification: Notification) {
        textView.needsDisplay = true
        onTextChanged?()
    }

    deinit {
        removeEscapeMonitor()
    }
}
