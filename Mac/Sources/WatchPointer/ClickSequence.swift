import Foundation
import CoreGraphics

struct ClickSequence {
    private var lastTime: Double?
    private var lastPoint = CGPoint.zero
    private var count: Int64 = 0

    mutating func next(at time: Double, point: CGPoint, interval: Double) -> Int64 {
        if let lastTime, time >= lastTime, time - lastTime <= interval,
           hypot(point.x - lastPoint.x, point.y - lastPoint.y) <= 4 {
            count += 1
        } else { count = 1 }
        lastTime = time
        lastPoint = point
        return count
    }
    mutating func reset() { self = Self() }
}
