import Foundation
import Combine

struct ReceiverVisibility: Equatable {
    var menuBar: Bool
    var notch: Bool
}

final class ReceiverAppearance: ObservableObject {
    static let shared = ReceiverAppearance()
    @Published private(set) var visibility: ReceiverVisibility
    private let defaults: UserDefaults

    init(defaults: UserDefaults = UserDefaults(suiteName: "io.loopbreak.watchpointer.receiver")!) {
        self.defaults = defaults
        let menu = defaults.object(forKey: "showMenuBar") as? Bool ?? true
        let notch = defaults.object(forKey: "showNotch") as? Bool ?? true
        visibility = ReceiverVisibility(menuBar: menu || !notch, notch: notch)
    }

    func setMenuBar(_ enabled: Bool) {
        var next = visibility
        next.menuBar = enabled
        if !enabled && !next.notch { next.notch = true }
        save(next)
    }
    func setNotch(_ enabled: Bool) {
        var next = visibility
        next.notch = enabled
        if !enabled && !next.menuBar { next.menuBar = true }
        save(next)
    }
    private func save(_ next: ReceiverVisibility) {
        defaults.set(next.menuBar, forKey: "showMenuBar")
        defaults.set(next.notch, forKey: "showNotch")
        visibility = next
    }
}

