import Foundation
import CoreGraphics

/// One gesture lasts until every finger lifts. Never turn a swipe or extra-finger contact into a tap.
struct TouchInterpreter<ID: Hashable> {
    enum Output: Equatable {
        case move(Double, Double), leftClick, dragStart, dragEnd, gesture(Int16)
    }
    private var previous: [ID: CGPoint] = [:]
    private var maxCount = 0
    private var startTime = 0.0
    private var moved = false
    private var dragging = false
    private var cancelled = false
    private var travel = CGPoint.zero
    private var singleTravel = CGPoint.zero

    mutating func update(_ touches: [ID: CGPoint], now: Double, cancelled wasCancelled: Bool = false) -> [Output] {
        var result: [Output] = []
        if previous.isEmpty && !touches.isEmpty { startTime = now }
        cancelled = cancelled || wasCancelled
        maxCount = max(maxCount, touches.count)
        if touches.count > 1 && dragging { result.append(.dragEnd); dragging = false }
        if !touches.isEmpty && touches.keys.count == previous.keys.count && Set(touches.keys) == Set(previous.keys) {
            let dx = touches.reduce(0.0) { $0 + $1.value.x - previous[$1.key]!.x } / Double(touches.count)
            let dy = touches.reduce(0.0) { $0 + $1.value.y - previous[$1.key]!.y } / Double(touches.count)
            if maxCount == 1 && !cancelled {
                singleTravel.x += dx; singleTravel.y += dy
                if hypot(singleTravel.x, singleTravel.y) > 3 { moved = true }
                if moved || dragging {
                    result.append(.move(dx, dy))
                }
            } else if touches.count == 2 && maxCount == 2 {
                travel.x += dx; travel.y += dy
                if hypot(travel.x, travel.y) > 8 { moved = true }
            }
        }
        if touches.isEmpty && !previous.isEmpty {
            if dragging { result.append(.dragEnd) }
            else if !cancelled {
                if maxCount == 1 && !moved { result.append(.leftClick) }
                if maxCount == 2 && !moved && now - startTime < 0.7 { result.append(.gesture(0)) }
                if maxCount == 2 && moved {
                    if abs(travel.x) >= 24 && abs(travel.x) > abs(travel.y) * 1.3 {
                        result.append(.gesture(travel.x < 0 ? 1 : 2))
                    } else if abs(travel.y) >= 24 && abs(travel.y) > abs(travel.x) * 1.3 {
                        result.append(.gesture(travel.y < 0 ? 3 : 4))
                    }
                }
            }
            self = Self()
        } else { previous = touches }
        return result
    }

    mutating func hold(now: Double) -> [Output] {
        guard previous.count == 1, maxCount == 1, !moved, !dragging, !cancelled, now - startTime >= 0.35 else { return [] }
        dragging = true
        return [.dragStart]
    }

    mutating func cancel() -> [Output] {
        let outputs: [Output] = dragging ? [.dragEnd] : []
        self = Self()
        return outputs
    }
}
