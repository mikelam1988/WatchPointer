import Foundation
import CoreGraphics
@main struct Checks {
 static func main() {
  var s = ClickSequence()
  precondition(s.next(at:0,point:.zero,interval:0.5) == 1)
  precondition(s.next(at:0.2,point:.zero,interval:0.5) == 2)
  precondition(s.next(at:1,point:.zero,interval:0.5) == 1)
  precondition(s.next(at:1.1,point:CGPoint(x:20,y:0),interval:0.5) == 1)
  s.reset()
  precondition(s.next(at:1.2,point:CGPoint(x:20,y:0),interval:0.5) == 1)
  print("Click sequence checks passed")
 }
}
