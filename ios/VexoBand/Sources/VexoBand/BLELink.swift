// The real band over Bluetooth (CoreBluetooth). It only ever connects to ONE band: the
// number it was made with. Other teams' bands are in the same room and are never touched.
@preconcurrency import CoreBluetooth
import Foundation

@MainActor
public final class BLELink: NSObject, BandLink {
    public var onEvent: ((LinkEvent) -> Void)?
    public var onFrame: ((Data) -> Void)?

    private let band: Int
    private let expectedName: String
    private let service = CBUUID(string: VexoContract.serviceUUID)
    private let rxID = CBUUID(string: VexoContract.rxUUID)
    private let txID = CBUUID(string: VexoContract.txUUID)

    private var central: CBCentralManager?
    private var peripheral: CBPeripheral?
    private var rx: CBCharacteristic?
    private var wantOpen = false
    private var closedByUs = false
    private var searchSeconds: TimeInterval = 20
    private var searchTimer: Task<Void, Never>?

    public init(band: Int) {
        self.band = band
        self.expectedName = VexoContract.name(forBand: band)
    }

    public func open(searchSeconds: TimeInterval) {
        self.searchSeconds = searchSeconds
        wantOpen = true
        closedByUs = false
        if let central {
            stateChanged(central)
        } else {
            // Made here, not in init: this is the moment iOS asks for the Bluetooth permission.
            central = CBCentralManager(delegate: self, queue: .main)
        }
    }

    public func send(_ frame: Data) {
        guard let peripheral, let rx else { return }
        peripheral.writeValue(frame, for: rx, type: .withResponse)
    }

    public func close() {
        wantOpen = false
        closedByUs = true
        searchTimer?.cancel()
        central?.stopScan()
        if let peripheral {
            central?.cancelPeripheralConnection(peripheral)
        } else {
            onEvent?(.closed(byUs: true))
        }
    }

    // MARK: finding the band

    private func stateChanged(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            if wantOpen, peripheral == nil { startSearch(central) }
        case .poweredOff:
            fail("Bluetooth is off. Switch it on in Settings or Control Centre.")
        case .unauthorized:
            fail("Familiar is not allowed to use Bluetooth. Allow it in Settings > Privacy & Security > Bluetooth.")
        case .unsupported:
            fail("This device has no Bluetooth (the Simulator has none). Use the pretend band.")
        default:
            break       // .unknown / .resetting: another state follows
        }
    }

    private func fail(_ text: String) {
        searchTimer?.cancel()
        peripheral = nil
        rx = nil
        if wantOpen { onEvent?(.unavailable(text)) }
    }

    private func startSearch(_ central: CBCentralManager) {
        onEvent?(.searching)
        // Only Vexo Open bands answer this scan. Duplicates are allowed because the name
        // arrives in a second packet (the scan response), a moment after the first.
        central.scanForPeripherals(withServices: [service], options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])
        searchTimer?.cancel()
        searchTimer = Task { [weak self, searchSeconds] in
            try? await Task.sleep(nanoseconds: UInt64(searchSeconds * 1_000_000_000))
            guard !Task.isCancelled, let self, self.peripheral == nil, self.wantOpen else { return }
            self.central?.stopScan()
            self.wantOpen = false
            self.onEvent?(.notFound)
        }
    }

    /// True only for our own band: its number in the advertising packet, or its exact name.
    /// A packet that says another number or another name is never ours.
    private func isOurBand(_ advertisement: [String: Any]) -> Bool {
        let name = advertisement[CBAdvertisementDataLocalNameKey] as? String
        let number = (advertisement[CBAdvertisementDataManufacturerDataKey] as? Data).flatMap(VexoContract.bandNumber(fromManufacturerData:))
        if let number, number != band { return false }
        if let name, name != expectedName { return false }
        return number != nil || name != nil
    }
}

extension BLELink: @preconcurrency CBCentralManagerDelegate {
    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        stateChanged(central)
    }

    public func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                               advertisementData: [String: Any], rssi RSSI: NSNumber) {
        guard wantOpen, self.peripheral == nil, isOurBand(advertisementData) else { return }
        searchTimer?.cancel()
        central.stopScan()
        self.peripheral = peripheral
        peripheral.delegate = self
        onEvent?(.connecting)
        central.connect(peripheral)
    }

    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.discoverServices([service])
    }

    public func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        ended()
    }

    public func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        ended()
    }

    private func ended() {
        peripheral = nil
        rx = nil
        wantOpen = false
        onEvent?(.closed(byUs: closedByUs))
    }
}

extension BLELink: @preconcurrency CBPeripheralDelegate {
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let found = peripheral.services?.first(where: { $0.uuid == service }) else {
            central?.cancelPeripheralConnection(peripheral)
            return
        }
        peripheral.discoverCharacteristics([rxID, txID], for: found)
    }

    public func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        let all = service.characteristics ?? []
        guard let rx = all.first(where: { $0.uuid == rxID }), let tx = all.first(where: { $0.uuid == txID }) else {
            central?.cancelPeripheralConnection(peripheral)
            return
        }
        self.rx = rx
        // No command runs until we have subscribed to the band's notifications.
        peripheral.setNotifyValue(true, for: tx)
    }

    public func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        guard characteristic.uuid == txID else { return }
        if characteristic.isNotifying {
            onEvent?(.ready)
        } else {
            central?.cancelPeripheralConnection(peripheral)
        }
    }

    public func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard characteristic.uuid == txID, let value = characteristic.value else { return }
        onFrame?(value)
    }
}
