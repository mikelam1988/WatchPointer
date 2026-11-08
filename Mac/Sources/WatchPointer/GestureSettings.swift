import AppKit
import SwiftUI

final class GestureSettingsModel: ObservableObject {
    @Published var bindings = GestureMappings.defaults
    @Published var message = "修改后自动保存，即时生效"
    @Published var recording: String?
    private let store: GestureMappings
    init(store: GestureMappings = GestureMappings()) { self.store = store }

    func reload() {
        recording = nil
        do {
            let parsed = try JSONDecoder().decode([String: GestureBinding].self, from: Data(contentsOf: store.url))
            guard GestureMappings.validate(parsed) else { throw CocoaError(.fileReadCorruptFile) }
            bindings = GestureMappings.defaults.merging(GestureMappings.normalized(parsed)) { _, new in new }
            message = "修改后自动保存，即时生效"
        } catch { message = "读取配置失败，未覆盖文件：\(error.localizedDescription)" }
    }

    func choose(_ name: String, action: String) {
        if action == "shortcut" {
            recording = name
            message = "请按下快捷键；Esc 取消录入"
            return
        }
        var next = bindings
        next[name] = GestureBinding(action: action)
        save(next)
    }

    func capture(_ event: NSEvent, name: String) {
        if event.keyCode == 53 { recording = nil; message = "已取消录入"; return }
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        var modifiers: [String] = []
        if flags.contains(.command) { modifiers.append("command") }
        if flags.contains(.control) { modifiers.append("control") }
        if flags.contains(.option) { modifiers.append("option") }
        if flags.contains(.shift) { modifiers.append("shift") }
        var next = bindings
        next[name] = GestureBinding(action: "shortcut", keyCode: event.keyCode, modifiers: modifiers)
        recording = nil
        save(next)
    }

    func restore() { recording = nil; save(GestureMappings.defaults) }

    private func save(_ next: [String: GestureBinding]) {
        guard GestureMappings.validate(next) else { message = "此快捷键不受支持，未保存"; return }
        do {
            let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(next).write(to: store.url, options: .atomic)
            bindings = next
            message = "已保存 · 下次手势即生效"
        } catch { message = "保存失败：\(error.localizedDescription)" }
    }
}

final class GestureSettingsController: NSWindowController, NSWindowDelegate {
    static let shared = GestureSettingsController()
    private let model = GestureSettingsModel()
    private init() {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 620, height: 440),
                              styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        window.title = "WatchPointer 设置"
        window.isReleasedWhenClosed = false
        super.init(window: window)
        window.contentView = NSHostingView(rootView: GestureSettingsView(model: model))
        window.delegate = self
        window.center()
    }
    required init?(coder: NSCoder) { fatalError("Not supported") }
    func open() {
        model.reload()
        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }
    func windowWillClose(_ notification: Notification) { model.recording = nil }
}

private struct GestureSettingsView: View {
    @ObservedObject var model: GestureSettingsModel
    private let labels = ["双指轻点", "双指左滑", "双指右滑", "双指上滑", "双指下滑"]
    private let actions = [("rightClick", "右键点击"), ("leftClick", "左键点击"),
                           ("nextDesktop", "下一桌面"), ("previousDesktop", "上一桌面"),
                           ("missionControl", "调度中心"), ("showDesktop", "显示桌面"),
                           ("shortcut", "自定义快捷键…"), ("none", "不执行操作")]
    @State private var confirmRestore = false
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("手势与操作").font(.title2.bold())
            Text("按你的习惯设置手表手势，无需重新安装手表 App。")
                .foregroundStyle(.secondary)
            Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 14) {
                ForEach(Array(GestureMappings.names.enumerated()), id: \.element) { index, name in
                    GridRow {
                        Text(labels[index]).frame(width: 90, alignment: .leading)
                        Picker(labels[index], selection: Binding(get: {
                            model.recording == name ? "shortcut" : model.bindings[name]?.action ?? "none"
                        }, set: { model.choose(name, action: $0) })) {
                            ForEach(actions, id: \.0) { action in Text(action.1).tag(action.0) }
                        }.labelsHidden().frame(width: 175)
                        if model.recording == name {
                            ShortcutCapture { model.capture($0, name: name) }
                                .frame(width: 220, height: 28)
                        } else if let binding = model.bindings[name], binding.action == "shortcut" {
                            Button(shortcutLabel(binding)) { model.recording = name }
                                .help("点击重新录入；Esc 取消")
                        } else {
                            Text(defaultHint(model.bindings[name]?.action ?? "")).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            Text("切换桌面需创建多个桌面，并启用 macOS 对应键盘快捷键。录入时若快捷键被系统拦截，请选择其他组合。")
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Divider()
            HStack {
                Text(model.message).font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("取消录入") { model.recording = nil }.disabled(model.recording == nil)
                Button("恢复默认") { confirmRestore = true }
            }
        }.padding(24).frame(width: 620)
            .confirmationDialog("恢复全部手势的默认操作？", isPresented: $confirmRestore) {
                Button("恢复默认") { model.restore() }
            }
    }
    private func defaultHint(_ action: String) -> String {
        switch action {
        case "nextDesktop": "⌃ →"
        case "previousDesktop": "⌃ ←"
        case "missionControl": "⌃ ↑"
        case "showDesktop": "F11"
        default: ""
        }
    }
    private func shortcutLabel(_ binding: GestureBinding) -> String {
        let symbols = ["control": "⌃", "option": "⌥", "shift": "⇧", "command": "⌘"]
        let prefix = (binding.modifiers ?? []).map { symbols[$0] ?? $0 }.joined()
        let key = binding.keyCode ?? 0
        let names: [UInt16: String] = [0:"A",1:"S",2:"D",3:"F",4:"H",5:"G",6:"Z",7:"X",8:"C",9:"V",11:"B",12:"Q",13:"W",14:"E",15:"R",16:"Y",17:"T",31:"O",32:"U",34:"I",35:"P",37:"L",38:"J",40:"K",45:"N",46:"M",36:"↩",48:"⇥",49:"空格",51:"⌫",123:"←",124:"→",125:"↓",126:"↑",103:"F11"]
        return prefix + (names[key] ?? "键码 \(key)") + " · 修改"
    }
}

private struct ShortcutCapture: NSViewRepresentable {
    let capture: (NSEvent) -> Void
    func makeNSView(context: Context) -> KeyCaptureView {
        let view = KeyCaptureView(); view.capture = capture; return view
    }
    func updateNSView(_ view: KeyCaptureView, context: Context) {
        view.capture = capture
        DispatchQueue.main.async { view.window?.makeFirstResponder(view) }
    }
}
private final class KeyCaptureView: NSView {
    var capture: ((NSEvent) -> Void)?
    override var acceptsFirstResponder: Bool { true }
    override func viewDidMoveToWindow() { super.viewDidMoveToWindow(); window?.makeFirstResponder(self) }
    override func keyDown(with event: NSEvent) { capture?(event) }
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard window?.firstResponder === self else { return false }
        capture?(event); return true
    }
    override func draw(_ dirtyRect: NSRect) {
        NSColor.controlAccentColor.withAlphaComponent(0.15).setFill()
        NSBezierPath(roundedRect: bounds, xRadius: 6, yRadius: 6).fill()
        ("请按快捷键 · Esc 取消" as NSString).draw(at: NSPoint(x: 8, y: 6), withAttributes: [
            .font: NSFont.systemFont(ofSize: 12), .foregroundColor: NSColor.labelColor
        ])
    }
}
