import AppKit
@main struct Checks {
 static func main() throws {
  let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  defer { try? FileManager.default.removeItem(at: root) }
  let store = GestureMappings(url: root.appendingPathComponent("gestures.json"))
  let model = GestureSettingsModel(store: store)
  model.reload()
  model.choose("twoFingerTap", action: "none")
  precondition(store.binding(for: 0)?.action == "none")
  model.choose("twoFingerTap", action: "shortcut")
  precondition(model.recording == "twoFingerTap")
  precondition(store.binding(for: 0)?.action == "none")
  let event = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [.control,.shift], timestamp: 0, windowNumber: 0, context: nil, characters: "a", charactersIgnoringModifiers: "a", isARepeat: false, keyCode: 0)!
  model.capture(event, name: "twoFingerTap")
  precondition(store.binding(for: 0)?.keyCode == 0)
  precondition(store.binding(for: 0)?.modifiers == ["control","shift"])
  precondition(model.recording == nil)
  model.restore()
  precondition(store.binding(for: 0)?.action == "rightClick")
  print("Settings persistence, recording, and defaults checks passed")
 }
}
