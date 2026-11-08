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

    @State private var pressing = false
    @State private var dragging = false
    @State private var holdTimer: Timer?
    @State private var lastTranslation: CGSize = .zero
    @State private var moved = false
    @Environment(\.scenePhase) private var scenePhase

    private var fill: Color {
        if dragging { return .white }
        if paused { return Color.orange.opacity(0.25) }
        return Color(white: pressing ? 0.28 : 0.16)
    }

    private var symbol: String { dragging ? "hand.raised.fill" : paused ? "pause.fill" : "hand.draw" }

    var body: some View {
        Button {
            guard !paused, !pressing, !dragging, gestureEnabled, scenePhase == .active else { return }
            clicks += 1
            pointer.send(.rightClick)
        } label: {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(fill)
            .overlay {
                Image(systemName: symbol)
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(dragging ? .black : paused ? .orange : Color(white: 0.55))
                    .contentTransition(.symbolEffect(.replace))
            }
        }
            .buttonStyle(.plain)
            .accessibilityLabel("触摸板，系统双指互点两下执行右键")
            .handGestureShortcut(.primaryAction,
                                 isEnabled: gestureEnabled && !paused && !pressing && scenePhase == .active)
            .scaleEffect(pressing && !dragging ? 0.98 : 1)
            .animation(.smooth(duration: 0.15), value: pressing)
            .animation(.smooth(duration: 0.2), value: dragging)
            .contentShape(Rectangle())
            .highPriorityGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard !paused else { return }
                        if !pressing {
                            pressing = true
                            moved = false
                            lastTranslation = .zero
                            holdTimer = Timer.scheduledTimer(withTimeInterval: holdToDrag, repeats: false) { _ in
                                guard pressing, !moved, !paused else { return }
                                dragging = true
                                pointer.send(.drag, 1)
                            }
                        }
                        let translation = value.translation
                        if !moved && hypot(translation.width, translation.height) > 3 {
                            moved = true
                            holdTimer?.invalidate()
                        }
                        if moved || dragging {
                            pointer.move(dx: Double(translation.width - lastTranslation.width),
                                         dy: Double(translation.height - lastTranslation.height))
                            lastTranslation = translation
                        }
                    }
                    .onEnded { _ in
                        if pressing && !paused && !dragging && !moved {
                            clicks += 1
                            pointer.send(.leftClick)
                        }
                        cancelTouch()
                    }
            )
            .onDisappear { cancelTouch() }
            .onChange(of: paused) { cancelTouch() }
            .onChange(of: scenePhase) { _, phase in
                if phase != .active { cancelTouch() }
            }
            .sensoryFeedback(trigger: dragging) { _, now in .impact(weight: now ? .heavy : .light) }
    }
    private func cancelTouch() {
        holdTimer?.invalidate()
        holdTimer = nil
        if dragging { pointer.send(.drag, 0) }
        dragging = false
        pressing = false
        moved = false
        lastTranslation = .zero
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
