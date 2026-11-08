import Foundation
@main struct Checks {
 static func main() {
  let suite = "WatchPointer.AppearanceTests." + UUID().uuidString
  let defaults = UserDefaults(suiteName: suite)!
  defer { defaults.removePersistentDomain(forName: suite) }
  let model = ReceiverAppearance(defaults: defaults)
  precondition(model.visibility == ReceiverVisibility(menuBar: true, notch: true))
  model.setNotch(false)
  precondition(model.visibility == ReceiverVisibility(menuBar: true, notch: false))
  precondition(ReceiverAppearance(defaults: defaults).visibility == model.visibility)
  model.setMenuBar(false)
  precondition(model.visibility == ReceiverVisibility(menuBar: false, notch: true))
  model.setNotch(false)
  precondition(model.visibility == ReceiverVisibility(menuBar: true, notch: false))
  defaults.set(false, forKey: "showMenuBar")
  defaults.set(false, forKey: "showNotch")
  precondition(ReceiverAppearance(defaults: defaults).visibility.menuBar)
  print("Appearance persistence and accessible-entry checks passed")
 }
}
