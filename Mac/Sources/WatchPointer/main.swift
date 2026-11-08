import AppKit

setvbuf(stdout, nil, _IONBF, 0) // show log lines immediately

let prompt = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
if !AXIsProcessTrustedWithOptions([prompt: true] as CFDictionary) {
    print("Grant Accessibility access to your terminal app (System Settings › Privacy & Security › Accessibility), then rerun.")
}

print("Accessibility permission: \(AXIsProcessTrusted() ? "granted" : "missing")")

let app = NSApplication.shared
app.setActivationPolicy(.accessory) // no Dock icon, just the notch
let live = Live()
let receiver = Receiver(live: live)
let notch = NotchController(live: live)
if CommandLine.arguments.contains("--settings") { GestureSettingsController.shared.open() }
app.run()
