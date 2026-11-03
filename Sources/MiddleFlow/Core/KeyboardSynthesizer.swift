import CoreGraphics
import Foundation

final class KeyboardSynthesizer {
    static let eventMarker: Int64 = 0x4D464C57

    private let source = CGEventSource(stateID: .privateState)
    private(set) var optionDown = false

    @discardableResult
    func sendVoiceShortcut(_ shortcut: VoiceShortcut) -> Bool {
        let down = makeModifierEvent(shortcut: shortcut, isDown: true)
        let up = makeModifierEvent(shortcut: shortcut, isDown: false)
        guard let down, let up else { return false }
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
        optionDown = false
        return true
    }

    @discardableResult
    func sendReturn() -> Bool {
        guard let down = CGEvent(
            keyboardEventSource: source,
            virtualKey: 36,
            keyDown: true
        ), let up = CGEvent(
            keyboardEventSource: source,
            virtualKey: 36,
            keyDown: false
        ) else { return false }
        down.setIntegerValueField(.eventSourceUserData, value: Self.eventMarker)
        up.setIntegerValueField(.eventSourceUserData, value: Self.eventMarker)
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
        return true
    }

    @discardableResult
    func sendPaste() -> Bool {
        let pasteSource = CGEventSource(stateID: .hidSystemState) ?? source
        guard let commandDown = CGEvent(
            keyboardEventSource: pasteSource,
            virtualKey: 55,
            keyDown: true
        ), let down = CGEvent(
            keyboardEventSource: pasteSource,
            virtualKey: 9,
            keyDown: true
        ), let up = CGEvent(
            keyboardEventSource: pasteSource,
            virtualKey: 9,
            keyDown: false
        ), let commandUp = CGEvent(
            keyboardEventSource: pasteSource,
            virtualKey: 55,
            keyDown: false
        ) else { return false }

        commandDown.type = .flagsChanged
        commandUp.type = .flagsChanged
        commandDown.flags = [.maskCommand, .maskNonCoalesced]
        down.flags = [.maskCommand, .maskNonCoalesced]
        up.flags = [.maskCommand, .maskNonCoalesced]
        commandUp.flags = [.maskNonCoalesced]
        for event in [commandDown, down, up, commandUp] {
            event.setIntegerValueField(.eventSourceUserData, value: Self.eventMarker)
            event.post(tap: .cghidEventTap)
        }
        return true
    }

    func releaseHeldModifier() {
        optionDown = false
    }

    private func makeModifierEvent(
        shortcut: VoiceShortcut,
        isDown: Bool
    ) -> CGEvent? {
        guard let event = CGEvent(
            keyboardEventSource: source,
            virtualKey: shortcut.keyCode,
            keyDown: isDown
        ) else { return nil }
        event.type = .flagsChanged
        var flags = CGEventSource.flagsState(.combinedSessionState).rawValue
        let genericMask: UInt64
        let deviceMask: UInt64

        switch shortcut {
        case .rightOption:
            genericMask = CGEventFlags.maskAlternate.rawValue
            deviceMask = 0x40
        case .leftOption:
            genericMask = CGEventFlags.maskAlternate.rawValue
            deviceMask = 0x20
        case .function:
            genericMask = CGEventFlags.maskSecondaryFn.rawValue
            deviceMask = 0
        }

        if isDown {
            flags |= genericMask | deviceMask
        } else {
            flags &= ~deviceMask
            if shortcut != .function,
               flags & 0x20 == 0,
               flags & 0x40 == 0 {
                flags &= ~genericMask
            }
        }
        event.flags = CGEventFlags(rawValue: flags | CGEventFlags.maskNonCoalesced.rawValue)
        event.setIntegerValueField(.eventSourceUserData, value: Self.eventMarker)
        return event
    }
}
