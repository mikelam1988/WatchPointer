# WatchPointer

<img src="docs/icon.png" width="96" align="right" alt="">

Use your Apple Watch as a Bluetooth trackpad for your Mac.

This branch replaces motion aiming with touch input. Both the Mac receiver and Watch app must be updated.

## What it does

- **Swipe** the large touch area to move the cursor relatively. Lift and reposition your finger to continue moving.
- **Tap** to click; tap twice quickly at the same location to double-click (uses the Mac system double-click interval). **Hold still for 0.35 seconds, then swipe** to drag; lift to release.
- **Two-finger tap** performs the configured secondary action (right click by default). Lift both fingers to confirm; two-finger swipes suppress secondary click. Turn the **Digital Crown** to scroll.
- **Pause / Resume** lives in the top-left Mac menu and disables touch input and the right-click gesture while paused. No wrist motion or Center calibration is needed.
- Pair once with your Mac over Bluetooth. No Wi-Fi or iPhone relay is needed during use.

## Requirements

- Mac with macOS 14 or later and Bluetooth
- Apple Watch with watchOS 11 or later
- Xcode 16 or later (to install the watch app)

## Run it

### 1. Mac receiver

```bash
cd Mac
swift run WatchPointer
```

The first time, macOS asks for **Bluetooth** access and for **Accessibility** access (System Settings › Privacy & Security › Accessibility) for your terminal app. Accessibility is what lets it move the cursor. Allow both, then run it again.

It shows up in the notch (or the middle of the menu bar on Macs without one).

### 2. Standalone Watch app

1. Open `Watch/WatchPointer.xcodeproj` in Xcode and select the **WatchPointer** scheme.
2. Select your connected physical Apple Watch as the run destination and use your signing team.
3. Press **⌘R** to build and install directly on the Watch. Confirm device trust / Developer Mode prompts if requested.
4. Open WatchPointer on the Watch and pair with your Mac.

No iOS companion app is needed. The Watch target is watch-only (`WKWatchOnly = YES`) and retains `io.loopbreak.watchpointer.watchkitapp` so an in-place update can preserve existing pairing data. The original standalone identifier was different. This change removes the iOS target, not the trackpad features or Mac receiver.

### 3. Use the trackpad

Swipe on the large pad to move the cursor, tap to click, or hold still until the haptic feedback and then slide to drag. Lift to release. The default gain is 3 Mac screen points per Watch touch point; the Mac `speed` argument scales it.

## Settings

All on the Mac, no reinstall needed:

```bash
swift run WatchPointer 1.2               # speed: higher = less turn to reach the edges
swift run WatchPointer steady=0.6        # steadier when holding still (default 0.8)
swift run WatchPointer quick=0.02        # less lag on fast moves (default 0.01)
```

## Sky Shot

Open `Game/index.html` in a browser, press **F** for full screen, and tap the watch to start. Paper planes fly across a sky that turns from morning to sunset as the round runs out. Bullseyes count double, gold planes triple.

## Tips for using it in your hand

On the iPhone's Watch app, turn off **Passcode › Wrist Detection**, or the watch locks as soon as it's off your wrist. On the watch, set **Display & Brightness › Wake Duration** to 70 seconds and **General › Return to Clock › WatchPointer** to one hour.

## How it works

- The Watch sends relative touch deltas using packet kind 8: `[kind, Int16 LE dx, Int16 LE dy]`, in sixteenths of a touch point. Positive x is right, positive y is down.
- The Mac applies these deltas to the current cursor position. It retains legacy aim support for older Watch builds.
- Kind 9 is a heartbeat every 0.5 seconds. The Mac releases a held mouse button after two seconds without a heartbeat or movement, and on Bluetooth disconnect.
- Click, drag, scroll, pause and info packets retain their existing kinds. Touch input is coalesced at 30 Hz and uses writes without response, respecting Bluetooth backpressure. Pending movement expires after 100 ms instead of being replayed late; under congestion, some distance may be lost. Only button transitions use acknowledged writes.
- CoreMotion is not used by the Watch app on this branch.

## Security note

Pairing is chosen on the watch. The Mac itself doesn't ask for confirmation yet, so any nearby Bluetooth device that speaks this protocol could move the cursor while the receiver is running. Quit the receiver when you're not using it.

## License

MIT, see [LICENSE](LICENSE).

## Multi-touch hardware check

The Mac menu on the Watch has a **触点检测** (touch diagnostic) page. It displays current and maximum simultaneous touch events reported by `SpatialEventGesture`, without sending mouse commands. Availability of this API does not establish that a particular Watch reports multiple fingers.

Two-finger tap and two-finger swipes are enabled. System Double Tap is no longer bound. Three- and four-finger contacts are ignored. Gestures fire once on lift; cancelled gestures do not click.

## Customize Mac gesture actions

Hover over the top-center receiver panel and click **设置** to choose actions, record a custom keyboard shortcut, or restore defaults. Changes save immediately. You can also open settings at startup with `swift run WatchPointer --settings`. No Watch update is required for mapping changes.

On first launch the receiver creates `~/Library/Application Support/WatchPointer/gestures.json`. Edit this JSON on each Mac; changes reload on the next gesture, with no Watch reinstall or receiver restart. Invalid files retain the last valid mappings and log an error. Missing entries use defaults.

| Event | Default action |
| --- | --- |
| twoFingerTap | rightClick |
| twoFingerLeft | nextDesktop (Control–Right) |
| twoFingerRight | previousDesktop (Control–Left) |
| twoFingerUp | missionControl (Control–Up) |
| twoFingerDown | showDesktop (F11) |

Actions: `rightClick`, `leftClick`, `nextDesktop`, `previousDesktop`, `missionControl`, `showDesktop`, `shortcut`, `none`. Desktop actions require the corresponding macOS keyboard shortcuts enabled in System Settings → Keyboard → Keyboard Shortcuts → Mission Control. Switching desktops requires multiple Spaces. These are discrete shortcut actions, not interactive macOS trackpad animations.

Custom shortcut example (Control–Down for App Exposé):

```json
{
  "twoFingerDown": {
    "action": "shortcut",
    "keyCode": 125,
    "modifiers": ["control"]
  }
}
```

`keyCode` uses macOS virtual key codes (0–127). Modifiers: `command`, `control`, `option`, `shift`. The JSON does not execute shell commands. Packet kind 10 carries event IDs 0–4 in the order listed above; the Watch sends the gesture, not the configured action.

Checks: compile each file in `Tests/` with its matching implementation (`TouchInterpreter.swift`, `PendingMotion.swift`, or `GestureMappings.swift`) using `swiftc` and run the result.

Existing `threeFingerLeft/Right/Up/Down` configuration keys remain readable and migrate to `twoFingerLeft/Right/Up/Down` when saved from Settings.

## Receiver display and login settings

Settings includes **显示菜单栏图标** (menu bar icon), **显示刘海面板效果** (notch panel), and **登录 Mac 后自动启动** (start at login). Display changes take effect immediately and persist. At least one settings entry point is preserved: disabling the last visible entry enables the other one. The menu bar menu offers Settings and Quit.

Start at login is off unless enabled. It writes a per-user LaunchAgent at `~/Library/LaunchAgents/io.loopbreak.watchpointer.receiver.plist`, using the current executable path, and takes effect on the next graphical login. It does not launch another receiver immediately or require administrator access. Disabling removes the file without stopping this session. If you move the receiver executable, re-enable this option from its new location. Logs go to `~/Library/Logs/WatchPointer/`. The receiver must have the usual Bluetooth and Accessibility permissions.
