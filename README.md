# WatchPointer

<img src="docs/icon.png" width="96" align="right" alt="">

Use your Apple Watch as a Bluetooth trackpad for your Mac.

This branch replaces motion aiming with touch input. Both the Mac receiver and embedded Watch app must be updated.

## What it does

- **Swipe** the large touch area to move the cursor relatively. Lift and reposition your finger to continue moving.
- **Tap** to click. **Hold still for 0.35 seconds, then swipe** to drag; lift to release.
- Use the system **Double Tap** primary-action gesture to right-click (requires a supported Watch and the system gesture enabled). This is not the AssistiveTouch single-pinch gesture. Turn the **Digital Crown** to scroll.
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

### 2. iPhone companion and Watch app

1. Open `Watch/WatchPointer.xcodeproj` in Xcode and select the **WatchPointerPhone** scheme.
2. Select your connected physical iPhone as the run destination. Both targets use automatic signing; choose your own team for both when building on another account.
3. Press **⌘R** to install the iPhone app, which embeds the Watch app.
4. On the iPhone, open Apple's **Watch** app → **My Watch** → **Available Apps** → **WatchPointer** → **Install** (unless already installed automatically).
5. Open WatchPointer on the watch and tap **Pair** next to your Mac.

The iPhone app contains setup instructions; it does not relay pointer data. The Watch app still talks directly to the Mac over Bluetooth. Installation requires a properly paired and connected iPhone/Watch and any developer-mode/trust confirmations requested by the devices.

Bundle identifiers: iPhone `io.loopbreak.watchpointer`, embedded Watch app `io.loopbreak.watchpointer.watchkitapp`. The Watch bundle identifier differs from the original standalone build, so an existing standalone installation does not share its saved pairing with this version.

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

Requested mappings, pending physical-device validation: two fingers for secondary click; three fingers horizontally to change Spaces, up for Mission Control, down for Show Desktop. These mappings are not enabled yet. The existing system Double Tap right-click remains until multi-touch support is verified.
