import Foundation
@main struct Checks {
 static func main() throws {
  let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  defer { try? FileManager.default.removeItem(at: root) }
  let url = root.appendingPathComponent("gestures.json")
  let mappings = GestureMappings(url:url)
  precondition(mappings.binding(for:0)?.action == "rightClick")
  precondition(mappings.binding(for:99) == nil)
  try Data("{\"twoFingerTap\":{\"action\":\"none\"}}".utf8).write(to:url)
  precondition(mappings.binding(for:0)?.action == "none")
  precondition(mappings.binding(for:3)?.action == "missionControl")
  try Data("{\"twoFingerTap\":{\"action\":\"shortcut\",\"keyCode\":999}}".utf8).write(to:url)
  precondition(mappings.binding(for:0)?.action == "none")
  try Data("broken".utf8).write(to:url)
  precondition(mappings.binding(for:0)?.action == "none")
  try Data("{\"threeFingerLeft\":{\"action\":\"none\"}}".utf8).write(to:url)
  precondition(mappings.binding(for:1)?.action == "none")
  try Data("{\"threeFingerLeft\":{\"action\":\"none\"},\"twoFingerLeft\":{\"action\":\"leftClick\"}}".utf8).write(to:url)
  precondition(mappings.binding(for:1)?.action == "leftClick")
  print("Mapping reload and validation checks passed")
 }
}
