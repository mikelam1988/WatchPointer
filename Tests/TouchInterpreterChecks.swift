import Foundation
@main struct Checks {
 static func main() {
  var s = TouchInterpreter<Int>()
  func p(_ x: Double, _ y: Double = 0) -> CGPoint { CGPoint(x:x,y:y) }
  precondition(s.update([1:p(0)],now:0).isEmpty)
  precondition(s.update([:],now:0.1) == [.leftClick])
  _ = s.update([1:p(0),2:p(10)],now:1)
  precondition(s.update([1:p(0)],now:1.1).isEmpty)
  precondition(s.update([:],now:1.2) == [.gesture(0)])
  _ = s.update([1:p(0),2:p(10)],now:2)
  _ = s.update([1:p(0),2:p(10),3:p(20)],now:2.05)
  _ = s.update([1:p(-30),2:p(-20),3:p(-10)],now:2.2)
  precondition(s.update([1:p(-30),2:p(-20)],now:2.3).isEmpty)
  precondition(s.update([:],now:2.4) == [.gesture(1)])
  for (dx,dy,id) in [(30.0,0.0,Int16(2)),(0,-30,3),(0,30,4)] {
   _ = s.update([1:p(0),2:p(10),3:p(20)],now:3)
   _ = s.update([1:p(dx,dy),2:p(10+dx,dy),3:p(20+dx,dy)],now:3.1)
   precondition(s.update([:],now:3.2) == [.gesture(id)])
  }
  _ = s.update([1:p(0)],now:4)
  precondition(s.hold(now:4.4) == [.dragStart])
  precondition(s.update([1:p(0),2:p(10)],now:4.5) == [.dragEnd])
  precondition(s.cancel().isEmpty)
  _ = s.update([1:p(0)],now:5)
  precondition(s.update([:],now:5.1,cancelled:true).isEmpty)
  _ = s.update([1:p(0),2:p(10),3:p(20),4:p(30)],now:6)
  precondition(s.update([:],now:6.1).isEmpty)
  _ = s.update([1:p(0)],now:7)
  precondition(s.update([1:p(10)],now:7.1) == [.move(10,0)])
  precondition(s.hold(now:7.5).isEmpty)
  precondition(s.update([:],now:7.6).isEmpty)
  print("Touch gesture checks passed")
 }
}
