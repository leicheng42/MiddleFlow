import CoreAudio
import Foundation

final class AudioInputMonitor {
    private(set) var devices: [AudioDeviceID] = []
    private var lastRefresh = Date.distantPast

    func refreshIfNeeded(force: Bool = false) {
        guard force || Date().timeIntervalSince(lastRefresh) > 10 else { return }
        lastRefresh = Date()
        devices = Self.inputDevices()
    }

    func isMicrophoneActive() -> Bool {
        devices.contains(where: Self.isRunning)
    }

    private static func makeAddress(
        _ selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal
    ) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: scope,
            mElement: kAudioObjectPropertyElementMain
        )
    }

    private static func inputDevices() -> [AudioDeviceID] {
        var address = makeAddress(kAudioHardwarePropertyDevices)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &size
        ) == noErr else { return [] }

        var devices = [AudioDeviceID](
            repeating: 0,
            count: Int(size) / MemoryLayout<AudioDeviceID>.size
        )
        guard AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &size,
            &devices
        ) == noErr else { return [] }

        return devices.filter { device in
            var streamAddress = makeAddress(
                kAudioDevicePropertyStreams,
                scope: kAudioObjectPropertyScopeInput
            )
            var streamSize: UInt32 = 0
            return AudioObjectGetPropertyDataSize(
                device,
                &streamAddress,
                0,
                nil,
                &streamSize
            ) == noErr && streamSize > 0
        }
    }

    private static func isRunning(_ device: AudioDeviceID) -> Bool {
        var runningAddress = makeAddress(kAudioDevicePropertyDeviceIsRunningSomewhere)
        var size = UInt32(MemoryLayout<UInt32>.size)
        var value: UInt32 = 0
        return AudioObjectGetPropertyData(
            device,
            &runningAddress,
            0,
            nil,
            &size,
            &value
        ) == noErr && value != 0
    }
}
