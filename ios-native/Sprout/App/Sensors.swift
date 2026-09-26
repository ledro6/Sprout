import CoreBluetooth
import HomeKit
import Observation
import SwiftUI

/// Датчики влажности в горшках. Bluetooth — Flower Care и его родня: к
/// датчику подключаются, просят свежие показания, читают и отключаются —
/// батарейка у него на год. «Дом» — любой датчик влажности из приложения
/// «Дом», туда же попадают датчики Matter. Опрашиваются, когда приложение
/// открывают, и когда датчик привязывают. Bluetooth и «Дом» не трогаются,
/// пока датчиков нет: иначе без повода спросили бы разрешение.
@MainActor
@Observable
final class Sensors: NSObject {
    static let shared = Sensors()

    /// Датчик, который нашёлся рядом или в «Доме».
    struct Found: Identifiable, Hashable {
        var kind: Sensor.Kind
        var id: String
        var name: String
        /// Комната в «Доме» или сила сигнала.
        var detail: String?
    }

    private(set) var found: [Found] = []
    private(set) var scanning = false
    /// Bluetooth выключен или запрещён — искать нечем.
    private(set) var blind = false
    /// «Дом» не отвечает — почему.
    private(set) var homeless: String?

    @ObservationIgnored private var central: CBCentralManager?
    @ObservationIgnored private var homes: HMHomeManager?
    /// Что делать, когда Bluetooth включится.
    @ObservationIgnored private var waiting: [() -> Void] = []
    /// Идущие чтения: устройство — растение, заряд, таймер.
    @ObservationIgnored private var jobs: [UUID: Job] = [:]
    @ObservationIgnored private var stopper: Task<Void, Never>?

    private struct Job {
        var plant: Plant.ID
        var peripheral: CBPeripheral
        var battery: Int?
        var timeout: Task<Void, Never>?
    }

    private override init() {
        super.init()
    }

    // MARK: - Поиск

    /// Десять секунд слушаем Bluetooth и заодно спрашиваем «Дом».
    func search() {
        found = []
        homeless = nil
        scanning = true
        bluetooth {
            $0.scanForPeripherals(withServices: nil, options: [
                CBCentralManagerScanOptionAllowDuplicatesKey: false,
            ])
        }
        house()
        stopper?.cancel()
        stopper = Task { [weak self] in
            try? await Task.sleep(for: .seconds(10))
            guard !Task.isCancelled else { return }
            self?.stop()
        }
    }

    func stop() {
        central?.stopScan()
        scanning = false
    }

    // MARK: - Опрос

    /// Свежие показания всех привязанных датчиков.
    func poll() {
        let plants = Garden.shared.rooms.flatMap(\.plants)
            .filter { $0.sensor != nil }
        guard !plants.isEmpty else { return }
        for plant in plants { poll(plant.id) }
    }

    /// Показания одного растения.
    func poll(_ id: Plant.ID) {
        guard let sensor = Garden.shared.plant(id: id)?.sensor else { return }
        switch sensor.kind {
        case .flora: read(flora: sensor, for: id)
        case .home: read(home: sensor, for: id)
        }
    }

    private func read(flora sensor: Sensor, for plant: Plant.ID) {
        guard let uuid = UUID(uuidString: sensor.id) else { return }
        bluetooth { [weak self] central in
            guard let self,
                  let peripheral = central.retrievePeripherals(
                      withIdentifiers: [uuid]).first
            else { return }
            jobs[uuid]?.timeout?.cancel()
            // Датчик далеко или спит — через двадцать секунд бросаем.
            let timeout = Task { [weak self] in
                try? await Task.sleep(for: .seconds(20))
                guard !Task.isCancelled else { return }
                self?.finish(uuid)
            }
            jobs[uuid] = Job(plant: plant, peripheral: peripheral,
                             timeout: timeout)
            peripheral.delegate = self
            central.connect(peripheral)
        }
    }

    private func finish(_ uuid: UUID) {
        guard let job = jobs.removeValue(forKey: uuid) else { return }
        job.timeout?.cancel()
        central?.cancelPeripheralConnection(job.peripheral)
    }

    private func deliver(_ reading: Reading, to plant: Plant.ID) {
        let poured = Garden.shared.sense(plant, reading)
        if poured { Cheer.shared.now(from: Screen.middle) }
    }

    /// Bluetooth включается лениво: первое обращение и спросит разрешение.
    private func bluetooth(_ work: @escaping (CBCentralManager) -> Void) {
        if let central, central.state == .poweredOn {
            work(central)
            return
        }
        waiting.append { [weak self] in
            guard let central = self?.central else { return }
            work(central)
        }
        if central == nil {
            central = CBCentralManager(delegate: self, queue: .main)
        }
    }

    // MARK: - «Дом»

    private func house() {
        if let homes {
            gather(homes)
        } else {
            let manager = HMHomeManager()
            manager.delegate = self
            homes = manager
        }
    }

    /// Все датчики влажности «Дома».
    private func gather(_ manager: HMHomeManager) {
        if manager.authorizationStatus.contains(.restricted) {
            homeless = Lang.text("Доступ к «Дому» запрещён — разрешите его в Настройках → Sprout.")
            return
        }
        for home in manager.homes {
            for accessory in home.accessories {
                for characteristic in accessory.services.flatMap(\.characteristics)
                    where characteristic.characteristicType
                        == HMCharacteristicTypeCurrentRelativeHumidity {
                    let found = Found(
                        kind: .home, id: characteristic.uniqueIdentifier.uuidString,
                        name: accessory.name, detail: accessory.room?.name)
                    if !self.found.contains(found) { self.found.append(found) }
                }
            }
        }
        if manager.homes.isEmpty {
            homeless = Lang.text("В «Доме» пусто. Если датчики там есть — возможно, приложению не включили HomeKit в Xcode.")
        }
    }

    private func characteristic(_ id: String) -> HMCharacteristic? {
        guard let homes else { return nil }
        for home in homes.homes {
            for accessory in home.accessories {
                for service in accessory.services {
                    if let hit = service.characteristics.first(where: {
                        $0.uniqueIdentifier.uuidString == id
                    }) { return hit }
                }
            }
        }
        return nil
    }

    private func read(home sensor: Sensor, for plant: Plant.ID) {
        guard let homes else {
            // «Дом» ещё не открыт: откроем и прочтём, когда он ответит.
            pendingHome.insert(plant)
            house()
            return
        }
        guard let characteristic = characteristic(sensor.id) else {
            if homes.homes.isEmpty { pendingHome.insert(plant) }
            return
        }
        characteristic.readValue { [weak self] error in
            guard error == nil,
                  let value = (characteristic.value as? NSNumber)?.doubleValue
            else { return }
            Task { @MainActor in
                self?.deliver(Reading(moisture: value, when: Date()),
                              to: plant)
            }
        }
    }

    @ObservationIgnored private var pendingHome: Set<Plant.ID> = []
}

// MARK: - Bluetooth

extension Sensors: @preconcurrency CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        blind = central.state == .poweredOff || central.state == .unauthorized
            || central.state == .unsupported
        guard central.state == .poweredOn else { return }
        let queued = waiting
        waiting = []
        for work in queued { work() }
    }

    func centralManager(_ central: CBCentralManager,
                        didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any],
                        rssi RSSI: NSNumber) {
        let name = advertisementData[CBAdvertisementDataLocalNameKey] as? String
            ?? peripheral.name
        guard Flora.named(name) else { return }
        let id = peripheral.identifier.uuidString
        guard !found.contains(where: { $0.id == id }) else { return }
        found.append(Found(kind: .flora, id: id, name: name ?? "Flower Care",
                           detail: Lang.format("Сигнал %lld дБм",
                                               RSSI.intValue)))
    }

    func centralManager(_ central: CBCentralManager,
                        didConnect peripheral: CBPeripheral) {
        peripheral.discoverServices([CBUUID(string: Flora.service)])
    }

    func centralManager(_ central: CBCentralManager,
                        didFailToConnect peripheral: CBPeripheral,
                        error: (any Error)?) {
        finish(peripheral.identifier)
    }

    func centralManager(_ central: CBCentralManager,
                        didDisconnectPeripheral peripheral: CBPeripheral,
                        error: (any Error)?) {
        jobs[peripheral.identifier]?.timeout?.cancel()
        jobs[peripheral.identifier] = nil
    }
}

extension Sensors: @preconcurrency CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral,
                    didDiscoverServices error: (any Error)?) {
        guard let service = peripheral.services?.first(where: {
            $0.uuid == CBUUID(string: Flora.service)
        }) else {
            finish(peripheral.identifier)
            return
        }
        peripheral.discoverCharacteristics(
            [Flora.mode, Flora.data, Flora.firmware].map { CBUUID(string: $0) },
            for: service)
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didDiscoverCharacteristicsFor service: CBService,
                    error: (any Error)?) {
        guard let mode = service.characteristics?.first(where: {
            $0.uuid == CBUUID(string: Flora.mode)
        }) else {
            finish(peripheral.identifier)
            return
        }
        // Сначала заряд, потом «покажи сейчас» — и после него показания.
        if let firmware = service.characteristics?.first(where: {
            $0.uuid == CBUUID(string: Flora.firmware)
        }) {
            peripheral.readValue(for: firmware)
        }
        peripheral.writeValue(Data(Flora.realtime), for: mode,
                              type: .withResponse)
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didWriteValueFor characteristic: CBCharacteristic,
                    error: (any Error)?) {
        guard characteristic.uuid == CBUUID(string: Flora.mode),
              let data = characteristic.service?.characteristics?.first(where: {
                  $0.uuid == CBUUID(string: Flora.data)
              })
        else { return }
        peripheral.readValue(for: data)
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didUpdateValueFor characteristic: CBCharacteristic,
                    error: (any Error)?) {
        let uuid = peripheral.identifier
        guard error == nil, let value = characteristic.value,
              var job = jobs[uuid] else { return }
        let bytes = [UInt8](value)
        if characteristic.uuid == CBUUID(string: Flora.firmware) {
            job.battery = Flora.battery(bytes)
            jobs[uuid] = job
        } else if characteristic.uuid == CBUUID(string: Flora.data) {
            if let reading = Flora.reading(bytes, battery: job.battery) {
                deliver(reading, to: job.plant)
            }
            finish(uuid)
        }
    }
}

// MARK: - «Дом»

extension Sensors: @preconcurrency HMHomeManagerDelegate {
    func homeManagerDidUpdateHomes(_ manager: HMHomeManager) {
        gather(manager)
        let waiting = pendingHome
        pendingHome = []
        for plant in waiting { poll(plant) }
    }
}
