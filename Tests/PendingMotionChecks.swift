import Foundation

@main
struct PendingMotionChecks {
    static func main() {
        var state = PendingMotion()
        for _ in 0..<100 { state.add(dx: 0.25, dy: -0.5, now: 0) }
        let packet = state.takeMove(now: 0.03)!
        precondition(packet.0 == 400 && packet.1 == -800)
        precondition(state.takeMove(now: 0.04) == nil)
        state.add(dx: 100, now: 1)
        precondition(state.takeMove(now: 1.11) == nil, "Stale motion must not replay")
        state.add(dx: 100, now: 2)
        state.add(dx: 1, now: 2.11)
        precondition(state.takeMove(now: 2.12)!.0 == 16, "New input replaces expired backlog")
        state.add(dx: 1e6, dy: -1e6, scroll: 1e6, now: 3)
        let bounded = state.takeMove(now: 3.01)!
        precondition(bounded.0 == 32752 && bounded.1 == -32752)
        precondition(state.takeScroll(now: 3.01) == 32767)
        state.add(dx: 5, scroll: 2, now: 4)
        state.clear()
        precondition(state.takeMove(now: 4) == nil && state.takeScroll(now: 4) == nil)
        print("PendingMotion checks passed: coalescing, expiry, bounds, reset")
    }
}
