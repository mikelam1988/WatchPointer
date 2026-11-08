import AppKit
import Combine

/// Retained by main for the receiver lifetime, independent of the settings window.
final class ReceiverPresentation: NSObject {
    private var item: NSStatusItem?
    private var observer: AnyCancellable?
    private let notch: NotchController

    init(notch: NotchController) {
        self.notch = notch
        super.init()
        observer = ReceiverAppearance.shared.$visibility.sink { [weak self] state in
            self?.apply(state)
        }
    }
    private func apply(_ state: ReceiverVisibility) {
        notch.setVisible(state.notch)
        if state.menuBar && item == nil {
            let status = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
            status.button?.image = NSImage(systemSymbolName: "applewatch", accessibilityDescription: "WatchPointer")
            status.button?.image?.isTemplate = true
            status.button?.toolTip = "WatchPointer 接收器"
            let menu = NSMenu()
            let title = NSMenuItem(title: "WatchPointer", action: nil, keyEquivalent: "")
            title.isEnabled = false
            menu.addItem(title)
            let settings = NSMenuItem(title: "设置…", action: #selector(openSettings), keyEquivalent: ",")
            settings.target = self
            menu.addItem(settings)
            menu.addItem(.separator())
            let quit = NSMenuItem(title: "退出 WatchPointer", action: #selector(quitReceiver), keyEquivalent: "q")
            quit.target = self
            menu.addItem(quit)
            status.menu = menu
            item = status
        } else if !state.menuBar, let item {
            NSStatusBar.system.removeStatusItem(item)
            self.item = nil
        }
    }
    @objc private func openSettings() { GestureSettingsController.shared.open() }
    @objc private func quitReceiver() { NSApp.terminate(nil) }
}
