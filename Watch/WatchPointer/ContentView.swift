import SwiftUI

/// Mac scroll distance, in pixels, per unit of Crown turn. Higher = faster scrolling.
private let crownPixels = 25.0

/// Full-size trackpad with connection controls in the Mac menu.
struct ContentView: View {
    @StateObject private var pointer = Pointer()
    @State private var crown = 0.0
    @FocusState private var crownFocused: Bool
    @State private var clicks = 0
    @State private var confirmUnpair = false
    @State private var unpairTitle = ""
    @State private var showTouchDiagnostics = false

    var body: some View {
        NavigationStack {
            remote
                .toolbar {
                    if pointer.connected {
                        // Top-left, next to the clock: which Mac this is, and the way to unpair it.
                        ToolbarItem(placement: .topBarLeading) {
                            Button {
                                unpairTitle = pointer.pairedName ?? "Mac" // fixed while the dialog is up
                                confirmUnpair = true
                            } label: { Image(systemName: "laptopcomputer") }
                        }
                    }
                }
                .sheet(isPresented: $showTouchDiagnostics) {
                    TouchDiagnosticsView()
                }
                .confirmationDialog(unpairTitle, isPresented: $confirmUnpair, titleVisibility: .visible) {
                    Button(pointer.paused ? "继续操控" : "暂停操控", systemImage: pointer.paused ? "play.fill" : "pause.fill") {
                        pointer.togglePause()
                    }
                    Button("触点检测") {
                        showTouchDiagnostics = true
                    }
                    Button("Unpair", role: .destructive) {
                        // Unpair once the dialog has closed; changing the screen under it made it pop up a second time.
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { pointer.forget() }
                    }
                }
        }
    }

    private var remote: some View {
        Group {
            if pointer.connected {
                ClickPad(paused: pointer.paused, gestureEnabled: !confirmUnpair && !showTouchDiagnostics,
                         clicks: $clicks, pointer: pointer)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 4)
                .transition(.opacity)
            } else if let name = pointer.pairedName {
                WaitingForMac(name: name) { pointer.forget() }
                    .transition(.opacity)
            } else {
                PairList(found: pointer.found) { pointer.pair($0) }
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.black)
        .animation(.smooth(duration: 0.3), value: pointer.connected)
        // The Crown only reaches the focused view, so keep focus here rather than on a button.
        .focusable()
        .focused($crownFocused)
        .digitalCrownRotation($crown)
        .onChange(of: crown) { old, new in
            if !showTouchDiagnostics { pointer.scroll(by: (new - old) * crownPixels) }
        }
        .onAppear { crownFocused = true }
        .onChange(of: pointer.connected) { crownFocused = true }
        .sensoryFeedback(.impact(weight: .light), trigger: clicks)
        .sensoryFeedback(.selection, trigger: pointer.paused)
        .sensoryFeedback(trigger: pointer.connected) { _, now in now ? .start : .stop }
    }
}

/// Not paired yet: every Mac running the receiver nearby, each with a Pair button.
private struct PairList: View {
    let found: [FoundMac]
    let pair: (FoundMac) -> Void

    var body: some View {
        if found.isEmpty {
            Image(systemName: "laptopcomputer")
                .font(.system(size: 34))
                .foregroundStyle(.secondary)
                .symbolEffect(.pulse)
        } else {
            ScrollView {
                VStack(spacing: 6) {
                    ForEach(found) { mac in
                        Button { pair(mac) } label: {
                            HStack(spacing: 8) {
                                Text(mac.name)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Text("Pair")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.black)
                                    .padding(.horizontal, 10).padding(.vertical, 5)
                                    .background(.white, in: Capsule())
                            }
                            .font(.system(size: 15, weight: .medium))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .frame(minHeight: 52)
                            .background(Color(white: 0.16), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .buttonStyle(PressStyle())
                    }
                }
                .padding(.horizontal, 4)
            }
        }
    }
}

/// Paired, but that Mac isn't connected right now (receiver closed or out of range). Connects by itself when it's back.
private struct WaitingForMac: View {
    let name: String
    let forget: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            Spacer()
            Image(systemName: "laptopcomputer")
                .font(.system(size: 34))
                .foregroundStyle(.secondary)
                .symbolEffect(.pulse)
            Text(name)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color(white: 0.6))
                .lineLimit(1)
            Spacer()
            Button(action: forget) {
                Text("Forget")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(Color(white: 0.16), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(PressStyle())
        }
        .padding(.horizontal, 4)
    }
}

/// Swipe to move; tap to click; hold still then swipe to drag.
private struct ClickPad: View {
    let paused: Bool
    let gestureEnabled: Bool
    @Binding var clicks: Int
    let pointer: Pointer

    @State private var touches: [SpatialEventCollection.Event.ID: CGPoint] = [:]
    @State private var interpreter = TouchInterpreter<SpatialEventCollection.Event.ID>()
    @State private var dragging = false
    @State private var holdTimer: Timer?
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(paused ? Color.orange.opacity(0.25) : Color(white: dragging ? 0.5 : touches.isEmpty ? 0.16 : 0.28))
            .overlay {
                Image(systemName: paused ? "pause.fill" : dragging ? "hand.raised.fill" : "hand.draw")
                    .font(.system(size: 28)).foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
            .gesture(SpatialEventGesture().onChanged { events in
                guard !paused, gestureEnabled, scenePhase == .active else { cancelTouch(); return }
                let wasEmpty = touches.isEmpty
                var cancelled = false
                for event in events where event.kind == .touch {
                    switch event.phase {
                    case .active: touches[event.id] = event.location
                    case .ended: touches.removeValue(forKey: event.id)
                    case .cancelled: touches.removeValue(forKey: event.id); cancelled = true
                    @unknown default: cancelled = true; touches.removeValue(forKey: event.id)
                    }
                }
                emit(interpreter.update(touches, now: ProcessInfo.processInfo.systemUptime, cancelled: cancelled))
                if wasEmpty && !touches.isEmpty {
                    holdTimer?.invalidate()
                    holdTimer = Timer.scheduledTimer(withTimeInterval: 0.36, repeats: false) { _ in
                        emit(interpreter.hold(now: ProcessInfo.processInfo.systemUptime))
                    }
                }
                if touches.isEmpty { holdTimer?.invalidate() }
            }.onEnded { _ in
                emit(interpreter.update([:], now: ProcessInfo.processInfo.systemUptime))
                cancelTouch()
            })
            .onDisappear { cancelTouch() }
            .onChange(of: paused) { cancelTouch() }
            .onChange(of: gestureEnabled) { cancelTouch() }
            .onChange(of: scenePhase) { _, phase in if phase != .active { cancelTouch() } }
            .sensoryFeedback(trigger: dragging) { _, now in .impact(weight: now ? .heavy : .light) }
    }

    private func emit(_ outputs: [TouchInterpreter<SpatialEventCollection.Event.ID>.Output]) {
        for output in outputs {
            switch output {
            case let .move(dx, dy): pointer.move(dx: dx, dy: dy)
            case .leftClick: clicks += 1; pointer.send(.leftClick)
            case .dragStart: dragging = true; pointer.send(.drag, 1)
            case .dragEnd: dragging = false; pointer.send(.drag, 0)
            case let .gesture(id): clicks += 1; pointer.send(.gesture, id)
            }
        }
    }

    private func cancelTouch() {
        holdTimer?.invalidate(); holdTimer = nil
        emit(interpreter.cancel())
        touches.removeAll()
        dragging = false
    }
}

private struct PressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.6 : 1)
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.smooth(duration: 0.12), value: configuration.isPressed)
    }
}

/// Verify actual hardware touch reporting before enabling multi-finger commands.
private struct TouchDiagnosticsView: View {
    @State private var active: [SpatialEventCollection.Event.ID: CGPoint] = [:]
    @State private var maximum = 0

    var body: some View {
        VStack(spacing: 6) {
            Text("触点检测").font(.headline)
            Text("当前 \(active.count) · 最多 \(maximum)")
                .monospacedDigit()
            ZStack {
                RoundedRectangle(cornerRadius: 18).fill(Color.blue.opacity(0.2))
                Text("在此放下两根或三根手指\n并轻轻滑动")
                    .font(.caption2).multilineTextAlignment(.center)
                ForEach(Array(active.keys), id: \.self) { id in
                    if let point = active[id] {
                        Circle().fill(.blue).frame(width: 18, height: 18)
                            .position(point)
                    }
                }
            }
            .contentShape(Rectangle())
            .gesture(SpatialEventGesture().onChanged { events in
                for event in events where event.kind == .touch {
                    switch event.phase {
                    case .active: active[event.id] = event.location
                    case .ended, .cancelled: active.removeValue(forKey: event.id)
                    @unknown default: active.removeValue(forKey: event.id)
                    }
                }
                maximum = max(maximum, active.count)
            }.onEnded { _ in active.removeAll() })
            Text("仅检测，不发送鼠标操作").font(.caption2).foregroundStyle(.secondary)
        }
        .padding(6)
    }
}
