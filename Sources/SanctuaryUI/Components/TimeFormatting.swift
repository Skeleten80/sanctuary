import Foundation

/// m:ss formatting for cue timers.
public func formatClock(_ interval: TimeInterval) -> String {
    let total = max(0, Int(interval))
    return String(format: "%d:%02d", total / 60, total % 60)
}

/// h:mm:ss when over an hour, otherwise m:ss. For total runtime.
public func formatClockHMS(_ interval: TimeInterval) -> String {
    let total = max(0, Int(interval))
    let hours = total / 3600
    let minutes = (total % 3600) / 60
    let seconds = total % 60
    if hours > 0 {
        return String(format: "%d:%02d:%02d", hours, minutes, seconds)
    }
    return String(format: "%d:%02d", minutes, seconds)
}
