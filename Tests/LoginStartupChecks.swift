import Foundation
@main struct Checks {
 static func main() throws {
  let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  defer { try? FileManager.default.removeItem(at: root) }
  let model = LoginStartup(home: root, executable: URL(fileURLWithPath: "/bin/echo"))
  precondition(!model.enabled)
  model.setEnabled(true)
  precondition(model.enabled)
  let url = root.appendingPathComponent("Library/LaunchAgents/io.loopbreak.watchpointer.receiver.plist")
  let plist = try PropertyListSerialization.propertyList(from: Data(contentsOf: url), format: nil) as! [String: Any]
  precondition(plist["ProgramArguments"] as! [String] == ["/bin/echo"])
  precondition(plist["RunAtLoad"] as? Bool == true)
  precondition(LoginStartup(home: root, executable: URL(fileURLWithPath: "/bin/echo")).enabled)
  model.setEnabled(false)
  precondition(!model.enabled && !FileManager.default.fileExists(atPath: url.path))
  let missing = LoginStartup(home: root, executable: root.appendingPathComponent("missing"))
  missing.setEnabled(true)
  precondition(!missing.enabled && !missing.message.isEmpty)
  print("Login item creation, reload, removal and error checks passed")
 }
}
