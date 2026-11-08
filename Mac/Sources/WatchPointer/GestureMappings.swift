import Foundation

struct GestureBinding: Codable {
    var action: String
    var keyCode: UInt16?
    var modifiers: [String]?
}

final class GestureMappings {
    static let names = ["twoFingerTap", "twoFingerLeft", "twoFingerRight", "twoFingerUp", "twoFingerDown"]
    static let defaults: [String: GestureBinding] = [
        "twoFingerTap": .init(action: "rightClick"),
        "twoFingerLeft": .init(action: "nextDesktop"),
        "twoFingerRight": .init(action: "previousDesktop"),
        "twoFingerUp": .init(action: "missionControl"),
        "twoFingerDown": .init(action: "showDesktop")
    ]
    let url: URL
    private var bindings = defaults
    private var lastData: Data?
    init(url: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/WatchPointer/gestures.json")) {
        self.url = url
        do {
            if !FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                try encoder.encode(Self.defaults).write(to: url, options: .atomic)
            }
        } catch { print("Cannot create gesture config: \(error)") }
        print("Gesture mappings (reload on use): \(url.path)")
    }
    /// Accept old files without losing customized actions; new names take precedence.
    static func normalized(_ map: [String: GestureBinding]) -> [String: GestureBinding] {
        var result = map
        for direction in ["Left", "Right", "Up", "Down"] {
            let old = "threeFinger" + direction, new = "twoFinger" + direction
            if let binding = result.removeValue(forKey: old), result[new] == nil { result[new] = binding }
        }
        return result
    }
    static func validate(_ map: [String: GestureBinding]) -> Bool {
        let actions = ["rightClick", "leftClick", "nextDesktop", "previousDesktop", "missionControl", "showDesktop", "shortcut", "none"]
        return normalized(map).allSatisfy { name, value in
            names.contains(name) && actions.contains(value.action) &&
            (value.action != "shortcut" || (value.keyCode != nil && value.keyCode! <= 127)) &&
            (value.modifiers ?? []).allSatisfy { ["command", "control", "option", "shift"].contains($0) }
        }
    }
    func binding(for id: Int16) -> GestureBinding? {
        guard Self.names.indices.contains(Int(id)) else { return nil }
        do {
            let data = try Data(contentsOf: url)
            if data != lastData {
                let parsed = try JSONDecoder().decode([String: GestureBinding].self, from: data)
                if Self.validate(parsed) {
                    bindings = Self.defaults.merging(Self.normalized(parsed)) { _, new in new }
                } else { print("Invalid gesture config; retaining last valid mappings") }
                lastData = data
            }
        } catch { print("Cannot read gesture config; retaining last valid mappings: \(error)") }
        return bindings[Self.names[Int(id)]]
    }
}
