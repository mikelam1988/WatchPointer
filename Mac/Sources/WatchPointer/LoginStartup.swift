import Foundation
import Combine

/// A per-user LaunchAgent starts the receiver on the next graphical login.
/// Do not bootstrap here: the receiver is already running and must not be duplicated.
final class LoginStartup: ObservableObject {
    static let shared = LoginStartup()
    @Published private(set) var enabled = false
    @Published private(set) var message = ""
    private let url: URL
    private let executable: URL
    private let logs: URL
    private static let label = "io.loopbreak.watchpointer.receiver"

    init(home: URL = FileManager.default.homeDirectoryForCurrentUser,
         executable: URL = Bundle.main.executableURL!) {
        self.executable = executable.resolvingSymlinksInPath()
        url = home.appendingPathComponent("Library/LaunchAgents/\(Self.label).plist")
        logs = home.appendingPathComponent("Library/Logs/WatchPointer", isDirectory: true)
        refresh()
    }
    func refresh() {
        guard let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              plist["Label"] as? String == Self.label,
              let args = plist["ProgramArguments"] as? [String],
              args.first == executable.path else {
            enabled = false
            return
        }
        enabled = plist["RunAtLoad"] as? Bool == true
    }
    func setEnabled(_ value: Bool) {
        do {
            if value {
                guard FileManager.default.isExecutableFile(atPath: executable.path) else {
                    throw CocoaError(.fileReadNoPermission)
                }
                try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                try FileManager.default.createDirectory(at: logs, withIntermediateDirectories: true)
                let plist: [String: Any] = [
                    "Label": Self.label,
                    "ProgramArguments": [executable.path],
                    "RunAtLoad": true,
                    "LimitLoadToSessionType": "Aqua",
                    "StandardOutPath": logs.appendingPathComponent("receiver.log").path,
                    "StandardErrorPath": logs.appendingPathComponent("receiver-error.log").path
                ]
                let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
                try data.write(to: url, options: .atomic)
                message = "已开启，下次登录生效"
            } else {
                if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
                message = "已关闭自动启动，当前接收器继续运行"
            }
            refresh()
        } catch { message = "无法更新登录启动项：\(error.localizedDescription)"; refresh() }
    }
}
