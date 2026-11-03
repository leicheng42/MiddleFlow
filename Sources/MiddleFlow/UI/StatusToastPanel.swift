import AppKit
import QuartzCore

final class StatusToastPanel: NSPanel {
    private let effectView = NSVisualEffectView()
    private let iconView = NSImageView()
    private let label = NSTextField(labelWithString: "")
    private var dismissWorkItem: DispatchWorkItem?

    init() {
        let rect = NSRect(x: 0, y: 0, width: 350, height: 48)
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
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        ignoresMouseEvents = true

        effectView.frame = NSRect(origin: .zero, size: rect.size)
        effectView.autoresizingMask = [.width, .height]
        effectView.material = .popover
        effectView.blendingMode = .behindWindow
        effectView.state = .active
        effectView.wantsLayer = true
        effectView.layer?.cornerRadius = 16
        effectView.layer?.masksToBounds = true
        effectView.layer?.borderWidth = 0.5
        effectView.layer?.borderColor = NSColor.white.withAlphaComponent(0.13).cgColor
        contentView = effectView

        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.symbolConfiguration = NSImage.SymbolConfiguration(
            pointSize: 15,
            weight: .semibold
        )
        effectView.addSubview(iconView)

        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 13, weight: .semibold)
        label.textColor = .labelColor
        label.lineBreakMode = .byTruncatingTail
        effectView.addSubview(label)

        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: effectView.leadingAnchor, constant: 17),
            iconView.centerYAnchor.constraint(equalTo: effectView.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 18),
            iconView.heightAnchor.constraint(equalToConstant: 18),
            label.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 10),
            label.trailingAnchor.constraint(equalTo: effectView.trailingAnchor, constant: -17),
            label.centerYAnchor.constraint(equalTo: effectView.centerYAnchor)
        ])
    }

    func show(
        message: String,
        symbol: String,
        tint: NSColor,
        on screen: NSScreen,
        duration: TimeInterval = 1.55
    ) {
        dismissWorkItem?.cancel()
        label.stringValue = message
        iconView.image = NSImage(systemSymbolName: symbol, accessibilityDescription: message)
        iconView.contentTintColor = tint
        let visible = screen.visibleFrame
        let target = NSRect(
            x: visible.midX - 175,
            y: visible.minY + 22,
            width: 350,
            height: 48
        )
        setFrame(target, display: false)
        alphaValue = 0
        orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.18
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            animator().alphaValue = 1
        }
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.22
                context.timingFunction = CAMediaTimingFunction(name: .easeIn)
                self.animator().alphaValue = 0
            } completionHandler: {
                self.orderOut(nil)
            }
        }
        dismissWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: work)
    }

    deinit {
        dismissWorkItem?.cancel()
    }
}
