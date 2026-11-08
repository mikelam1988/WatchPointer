import CoreBluetooth
import SwiftUI
import WatchKit

// Must match the Mac receiver.
let serviceUUID = CBUUID(string: "6B1E0001-9F4C-4C2A-9B8E-3D2A1C0F5E01")
let inputUUID = CBUUID(string: "6B1E0002-9F4C-4C2A-9B8E-3D2A1C0F5E01")
/// Subscribing to this tells the Mac the moment the watch connects or disconnects. (It sends nothing back.)
let outputUUID = CBUUID(string: "6B1E0003-9F4C-4C2A-9B8E-3D2A1C0F5E01")

@main
struct WatchPointerApp: App {
    var body: some Scene { WindowGroup { ContentView() } }
}

/// Packets: [kind, Int16 LE a, Int16 LE b].
/// `.aim`: where the watch's 12 o'clock edge points, relative to "Center", in hundredths of a degree
/// (a = turned left, b = tipped up), then UInt16 LE: when it was measured, in ms on the watch's clock (wraps).
/// The Mac smooths with those times; Bluetooth delivers samples in bursts, so arrival times are useless.
/// `.pause`: a = 1 paused, 0 resumed.
/// `.info`: [kind, JSON] with the watch's model id, watchOS, battery and name (not the fixed 5 bytes).
/// `.drag`: a = 1 grab (mouse down), 0 drop (mouse up).
/// Clicks and drags may add the same UInt16 ms time as `.aim`: when the thumb touched down (or lifted, for a drop).
enum Kind: UInt8 { case aim = 0, leftClick = 1, rightClick = 2, scroll = 3, center = 4, pause = 5, info = 6, drag = 7, move = 8, heartbeat = 9, gesture = 10 }

/// How long to hold still before beginning a touch drag.
let holdToDrag = 0.35

/// A Mac running the receiver, seen nearby.
struct FoundMac: Identifiable {
    let id: UUID
    let name: String
    let peripheral: CBPeripheral
}

final class Pointer: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    @Published var connected = false
    @Published var paused = false
    /// Macs nearby you can pair with (only while nothing is paired).
    @Published var found: [FoundMac] = []
    /// The Mac you paired with. The watch only ever connects to this one until you forget it.
    @Published var pairedName = UserDefaults.standard.string(forKey: "pairedMacName")
    private var pairedID = UserDefaults.standard.string(forKey: "pairedMacID").flatMap(UUID.init)

    private var central: CBCentralManager!
    private var mac: CBPeripheral?
    private var input: CBCharacteristic?
    private var output: CBCharacteristic?
    private var infoTimer: Timer?
    private var motionTimer: Timer?
    private var pendingMotion = PendingMotion()

    override init() {
        super.init()
        central = CBCentralManager(delegate: self, queue: .main)

    }

    func togglePause() {
        pendingMotion.clear()
        paused.toggle()
        send(.pause, paused ? 1 : 0)
    }

    /// Relative movement in sixteenths of a screen point.
    func move(dx: Double, dy: Double) {
        guard !paused else { return }
        guard connected else { return }
        pendingMotion.add(dx: dx, dy: dy, now: ProcessInfo.processInfo.systemUptime)
    }

    /// Tells the Mac which watch this is when connecting.
    private func sendInfo() {
        guard let mac, let input else { return }
        var system = utsname()
        uname(&system)
        let model = withUnsafeBytes(of: &system.machine) { String(decoding: $0.prefix { $0 != 0 }, as: UTF8.self) }
        let device = WKInterfaceDevice.current()
        device.isBatteryMonitoringEnabled = true
        let info: [String: Any] = [
            "model": model,                                          // e.g. "Watch7,5"
            "os": device.systemVersion,
            "battery": device.batteryLevel < 0 ? -1 : Int((device.batteryLevel * 100).rounded()),
            "charging": device.batteryState == .charging || device.batteryState == .full,
            "name": String(device.name.prefix(40)),                  // kept short so it fits in one packet
        ]
        guard let json = try? JSONSerialization.data(withJSONObject: info) else { return }
        mac.writeValue(Data([Kind.info.rawValue]) + json, for: input, type: .withResponse)
    }

    func scroll(by pixels: Double) {
        guard connected, !paused else { return }
        pendingMotion.add(scroll: pixels, now: ProcessInfo.processInfo.systemUptime)
    }

    /// One aggregate per display interval, never a backlog of touch events.
    private func flushMotion() {
        guard let mac, let input, !paused else { return }
        let now = ProcessInfo.processInfo.systemUptime
        pendingMotion.expire(now: now)
        guard mac.canSendWriteWithoutResponse else { return }
        if let packet = pendingMotion.takeMove(now: now) {
            writeFast(.move, packet.0, packet.1, mac: mac, input: input)
        }
        if mac.canSendWriteWithoutResponse, let scroll = pendingMotion.takeScroll(now: now) {
            writeFast(.scroll, scroll, 0, mac: mac, input: input)
        }
    }

    private func writeFast(_ kind: Kind, _ a: Int16, _ b: Int16, mac: CBPeripheral, input: CBCharacteristic) {
        let bytes = [kind.rawValue, UInt8(truncatingIfNeeded: a), UInt8(truncatingIfNeeded: a >> 8),
                     UInt8(truncatingIfNeeded: b), UInt8(truncatingIfNeeded: b >> 8)]
        mac.writeValue(Data(bytes), for: input, type: .withoutResponse)
    }

    func send(_ kind: Kind, _ a: Int16 = 0, _ b: Int16 = 0, at time: TimeInterval? = nil) {
        guard let mac, let input else { return }
        if paused && kind != .pause && kind != .heartbeat && kind != .drag { return }
        if kind == .heartbeat {
            guard mac.canSendWriteWithoutResponse else { return }
            writeFast(kind, a, b, mac: mac, input: input)
            return
        }
        // Deliver current movement before button transitions; discard any blocked remainder.
        flushMotion()
        pendingMotion.clear()
        var bytes = [kind.rawValue,
                     UInt8(truncatingIfNeeded: a), UInt8(truncatingIfNeeded: a >> 8),
                     UInt8(truncatingIfNeeded: b), UInt8(truncatingIfNeeded: b >> 8)]
        if let time {
            let ms = UInt16(truncatingIfNeeded: Int64(time * 1000))
            bytes += [UInt8(truncatingIfNeeded: ms), UInt8(truncatingIfNeeded: ms >> 8)]
        }
        // Only infrequent button transitions use acknowledged writes.
        mac.writeValue(Data(bytes), for: input, type: kind == .aim ? .withoutResponse : .withResponse)
    }

    // MARK: Bluetooth

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn { start() }
    }

    /// Paired: wait for that Mac (the connect completes whenever it's in range). Not paired: list what's nearby.
    private func start() {
        guard central.state == .poweredOn, mac == nil else { return }
        found = []
        if let pairedID, let known = central.retrievePeripherals(withIdentifiers: [pairedID]).first {
            connect(to: known)
        }
        central.scanForPeripherals(withServices: [serviceUUID])
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any], rssi: NSNumber) {
        if let pairedID {
            if peripheral.identifier == pairedID { connect(to: peripheral) }
            return
        }
        let name = advertisementData[CBAdvertisementDataLocalNameKey] as? String ?? peripheral.name ?? "Mac"
        guard !found.contains(where: { $0.id == peripheral.identifier }) else { return }
        found.append(FoundMac(id: peripheral.identifier, name: name, peripheral: peripheral))
    }

    /// Pair with this Mac: remember it, then connect.
    func pair(_ found: FoundMac) {
        pairedID = found.id
        pairedName = found.name
        UserDefaults.standard.set(found.id.uuidString, forKey: "pairedMacID")
        UserDefaults.standard.set(found.name, forKey: "pairedMacName")
        self.found = []
        connect(to: found.peripheral)
    }

    /// Unpair, drop the connection and go back to listing nearby Macs.
    func forget() {
        pairedID = nil
        pairedName = nil
        UserDefaults.standard.removeObject(forKey: "pairedMacID")
        UserDefaults.standard.removeObject(forKey: "pairedMacName")
        if let mac { central.cancelPeripheralConnection(mac) }
        reset()
    }

    private func connect(to peripheral: CBPeripheral) {
        guard mac == nil else { return }
        central.stopScan()
        mac = peripheral
        peripheral.delegate = self
        central.connect(peripheral)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.discoverServices([serviceUUID])
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        reset()
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        reset()
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let service = peripheral.services?.first(where: { $0.uuid == serviceUUID }) else { return }
        peripheral.discoverCharacteristics([inputUUID, outputUUID], for: service)
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        input = service.characteristics?.first { $0.uuid == inputUUID }
        output = service.characteristics?.first { $0.uuid == outputUUID }
        if let output { peripheral.setNotifyValue(true, for: output) }
        connected = input != nil
        send(.heartbeat)
        sendInfo()
        motionTimer?.invalidate()
        let timer = Timer(timeInterval: 1.0 / 30, repeats: true) { [weak self] _ in self?.flushMotion() }
        RunLoop.main.add(timer, forMode: .common)
        motionTimer = timer
        infoTimer?.invalidate()
        infoTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in self?.send(.heartbeat) }
    }

    private func reset() {
        mac = nil
        input = nil
        output = nil
        connected = false
        paused = false
        pendingMotion.clear()
        motionTimer?.invalidate()
        motionTimer = nil
        infoTimer?.invalidate()
        start()
    }
}
