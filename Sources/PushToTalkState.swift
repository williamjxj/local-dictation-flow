import Foundation

/// Tracks whether the dictation hotkey is held and whether it owns the active recording.
struct PushToTalkState {
  private(set) var isHeld = false
  private(set) var ownsRecording = false

  mutating func press() -> Bool {
    guard !isHeld else { return false }
    isHeld = true
    return true
  }

  mutating func didStartRecording() {
    if isHeld { ownsRecording = true }
  }

  mutating func failedToStart() {
    ownsRecording = false
  }

  mutating func release() -> Bool {
    guard isHeld else { return false }
    isHeld = false
    guard ownsRecording else { return false }
    ownsRecording = false
    return true
  }

  mutating func recordingEnded() {
    ownsRecording = false
  }
}
