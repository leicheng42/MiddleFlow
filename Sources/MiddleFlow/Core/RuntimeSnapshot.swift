import Foundation

struct RuntimeSnapshot: Codable, Equatable {
    var accessibility = false
    var canPostEvents = false
    var mappingActive = false
    var microphoneActive = false
    var voiceState = "idle"
    var mappedPresses = 0
    var mappedClicks = 0
    var doubleClickSends = 0
    var latestTranscriptCharacters = 0
    var lastAutoPasteSent: Bool?
    var lastError = ""
    var updatedAt = Date()
}
