import Foundation

/// Bounded, coalesced touch state. Never replay motion older than 100 ms.
struct PendingMotion {
    private var x = 0.0
    private var y = 0.0
    private var scroll = 0.0
    private var startedAt: TimeInterval?

    mutating func expire(now: TimeInterval) {
        if let startedAt, now - startedAt > 0.1 { clear() }
    }

    mutating func add(dx: Double = 0, dy: Double = 0, scroll delta: Double = 0, now: TimeInterval) {
        expire(now: now)
        if startedAt == nil { startedAt = now }
        x = min(2047, max(-2047, x + dx))
        y = min(2047, max(-2047, y + dy))
        scroll = min(32767, max(-32767, scroll + delta))
    }

    mutating func takeMove(now: TimeInterval) -> (Int16, Int16)? {
        expire(now: now)
        let a = Int16((x * 16).rounded()), b = Int16((y * 16).rounded())
        guard a != 0 || b != 0 else { return nil }
        x -= Double(a) / 16
        y -= Double(b) / 16
        return (a, b)
    }

    mutating func takeScroll(now: TimeInterval) -> Int16? {
        expire(now: now)
        let value = Int16(scroll)
        guard value != 0 else { return nil }
        scroll -= Double(value)
        return value
    }

    mutating func clear() {
        x = 0; y = 0; scroll = 0; startedAt = nil
    }
}
