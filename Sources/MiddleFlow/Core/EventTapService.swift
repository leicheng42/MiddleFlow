import CoreGraphics
import Foundation

protocol EventTapServiceDelegate: AnyObject {
    func eventTapDidReceiveMiddleDown(at point: CGPoint)
    func eventTapDidReceiveMiddleUp()
    func eventTapDidDisableTemporarily()
}

final class EventTapService {
    weak var delegate: EventTapServiceDelegate?
    private(set) var isRunning = false
    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private let buttonNumber: Int64

    init(buttonNumber: Int64 = 2) {
        self.buttonNumber = buttonNumber
    }

    @discardableResult
    func start() -> Bool {
        guard tap == nil else {
            isRunning = true
            return true
        }
        let mask = (CGEventMask(1) << CGEventType.otherMouseDown.rawValue)
            | (CGEventMask(1) << CGEventType.otherMouseUp.rawValue)
            | (CGEventMask(1) << CGEventType.otherMouseDragged.rawValue)
        tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, type, event, context in
                guard let context else { return Unmanaged.passUnretained(event) }
                let service = Unmanaged<EventTapService>
                    .fromOpaque(context)
                    .takeUnretainedValue()
                return service.handle(type: type, event: event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        )
        guard let tap else {
            isRunning = false
            return false
        }
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        isRunning = true
        return true
    }

    func stop() {
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
        }
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        tap = nil
        runLoopSource = nil
        isRunning = false
    }

    private func handle(
        type: CGEventType,
        event: CGEvent
    ) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            delegate?.eventTapDidDisableTemporarily()
            return Unmanaged.passUnretained(event)
        }
        guard event.getIntegerValueField(.mouseEventButtonNumber) == buttonNumber else {
            return Unmanaged.passUnretained(event)
        }
        switch type {
        case .otherMouseDown:
            delegate?.eventTapDidReceiveMiddleDown(at: event.location)
        case .otherMouseUp:
            delegate?.eventTapDidReceiveMiddleUp()
        default:
            break
        }
        return nil
    }
}
