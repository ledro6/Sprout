import Foundation
import UIKit

/// Мастерская моделей. Готовые модели видов лежат в приложении (см.
/// `Stock`): AR открывается сразу, и телефон ничего не собирает сам по себе.
/// Свою модель по снимку он собирает только по просьбе хозяина — за доли
/// секунды, обычной детализации — и хранит в Application Support: её
/// заказали, и вычищать её, как кэш, система не должна. Как идёт сборка,
/// видно на карточке — см. `Bench`. Скан растения — отдельно, см. `Scans`.
actor Workshop {
    static let shared = Workshop()

    /// Последние открытые — в памяти: сад в AR ставит до дюжины растений
    /// разом, и второй раз он открывается мгновенно.
    private var recent: [String: Kit] = [:]
    private var order: [String] = []
    private static let kept = 12

    /// Своя модель — обычной детализации на любом телефоне: такой она
    /// собирается за доли секунды, не греет телефон и не отличается от
    /// готовых.
    private static let detail = Rig.Detail.standard

    /// Сборка — почти все проценты; остаток — запись на диск.
    private static let building = 0.95

    /// Модель для AR: своя, если хозяин её заказал, иначе — модель вида из
    /// приложения. Заказанную, но ещё не собранную (прежние сборки
    /// строили её в кэше, а кэш вычищают) собираем здесь же — один раз.
    func kit(for plant: Plant) -> Kit {
        guard let plan = plant.plan else { return stock(plant.blueprint.preset) }
        let key = Self.key(plant.id, plan)
        if let kit = recent[key] { return kit }
        if let kit = read(key) {
            remember(kit, key)
            return kit
        }
        return build(plant, plan, key: key)
    }

    /// Модель вида. Нет в приложении — так бывает, только если после смены
    /// рецептов забыли запустить tool/make_stock.py, — растим здесь.
    func stock(_ preset: Preset) -> Kit {
        let key = "stock-\(preset.rawValue)"
        if let kit = recent[key] { return kit }
        let kit = Stock.kit(preset)
            ?? Botany.grow(.stock(preset), species: preset.title,
                           detail: Self.detail)
        remember(kit, key)
        return kit
    }

    /// Собрать свою модель по снимку — хозяин попросил. Собранная по тому
    /// же чертежу второй раз не собирается.
    func prepare(_ plant: Plant) {
        guard let plan = plant.plan else { return }
        let key = Self.key(plant.id, plan)
        guard recent[key] == nil, !exists(key) else {
            Self.report(plant.id, plan.fingerprint, 1)
            return
        }
        _ = build(plant, plan, key: key)
    }

    /// Обойти сад при запуске и когда меняется его состав: сказать экранам,
    /// чьи свои модели собраны, забрать собранные прежними сборками из
    /// кэша и выбросить модели и сканы растений, которых больше нет. Сам
    /// обход ничего не собирает.
    func tend(_ plants: [Plant]) {
        adopt(plants)
        var alive: Set<String> = []
        for plant in plants {
            guard let plan = plant.plan else { continue }
            let key = Self.key(plant.id, plan)
            alive.insert(key + ".kit")
            if recent[key] != nil || exists(key) {
                Self.report(plant.id, plan.fingerprint, 1)
            }
        }
        Self.sweep(Self.folder, keeping: alive)
        Self.sweep(Scans.folder, keeping: Set(plants.compactMap(\.scan)))
    }

    private func build(_ plant: Plant, _ plan: Blueprint, key: String) -> Kit {
        let id = plant.id
        let stamp = plan.fingerprint
        let meter = Meter(expected: Effort.expected(plan.preset, Self.detail)) {
            share in Self.report(id, stamp, share * Self.building)
        }
        let kit = Meter.$current.withValue(meter) {
            Botany.grow(plan, species: plant.species, detail: Self.detail)
        }
        // Не записалась — остаётся в памяти: иначе до конца сеанса её
        // собирали бы заново при каждом открытии AR.
        write(kit, key)
        remember(kit, key)
        Self.report(id, stamp, 1)
        return kit
    }

    private func remember(_ kit: Kit, _ key: String) {
        recent[key] = kit
        order.removeAll { $0 == key }
        order.append(key)
        while order.count > Self.kept {
            recent[order.removeFirst()] = nil
        }
    }

    /// Отчёт экранам — на главную очередь и по порядку: доска их там и
    /// читает.
    private static func report(_ id: Plant.ID, _ stamp: String,
                               _ share: Double) {
        DispatchQueue.main.async {
            MainActor.assumeIsolated {
                Bench.shared.note(id, stamp: stamp, share: share)
            }
        }
    }

    // MARK: - Диск

    /// Детализация одна, поэтому в ключе её нет: номер растения и чертёж.
    private static func key(_ id: Plant.ID, _ plan: Blueprint) -> String {
        "\(id)-\(plan.fingerprint)"
    }

    private static let folder = Scans.place("Models")

    private func file(_ key: String) -> URL? {
        Self.folder?.appendingPathComponent(key + ".kit")
    }

    private func exists(_ key: String) -> Bool {
        guard let url = file(key) else { return false }
        return FileManager.default.fileExists(atPath: url.path)
    }

    /// Сжатие LZFSE: у картинок листьев много ровного цвета, файл
    /// выходит в разы меньше.
    @discardableResult
    private func write(_ kit: Kit, _ key: String) -> Bool {
        guard let url = file(key),
              let packed = try? (kit.encoded() as NSData)
                  .compressed(using: .lzfse),
              (try? (packed as Data).write(to: url, options: .atomic)) != nil
        else { return false }
        return true
    }

    private func read(_ key: String) -> Kit? {
        guard let url = file(key),
              let packed = try? Data(contentsOf: url),
              let data = try? (packed as NSData).decompressed(using: .lzfse)
        else { return nil }
        return Kit(data as Data)
    }

    /// Прежние сборки держали модели в кэше и с детализацией в имени.
    /// Собранные туда свои модели переезжают — не собирать же их заново —
    /// а сам кэш уходит.
    private func adopt(_ plants: [Plant]) {
        let manager = FileManager.default
        guard let caches = manager.urls(for: .cachesDirectory,
                                        in: .userDomainMask).first
        else { return }
        let old = caches.appendingPathComponent("Models", isDirectory: true)
        guard let files = try? manager.contentsOfDirectory(atPath: old.path)
        else { return }
        for plant in plants {
            guard let plan = plant.plan else { continue }
            let key = Self.key(plant.id, plan)
            guard !exists(key), let url = file(key),
                  let found = files.first(where: { $0.hasPrefix(key + "-") })
            else { continue }
            try? manager.moveItem(at: old.appendingPathComponent(found),
                                  to: url)
        }
        try? manager.removeItem(at: old)
    }

    private static func sweep(_ folder: URL?, keeping names: Set<String>) {
        guard let folder,
              let files = try? FileManager.default.contentsOfDirectory(
                  atPath: folder.path)
        else { return }
        for file in files where !names.contains(file) {
            try? FileManager.default.removeItem(
                at: folder.appendingPathComponent(file))
        }
    }
}

extension Workshop {
    /// Хозяин попросил свою модель — карточка сразу показывает ноль
    /// процентов, сборка идёт в очереди мастерской.
    @MainActor
    static func order(_ plant: Plant) {
        Bench.shared.queue(plant)
        Task(priority: .userInitiated) { await shared.prepare(plant) }
    }
}

/// Готовые модели видов — в каталоге ресурсов приложения, сжатые DEFLATE
/// без заголовка. Растит и кладёт их туда tool/make_stock.py.
enum Stock {
    static func kit(_ preset: Preset) -> Kit? {
        guard let asset = NSDataAsset(name: "stock-\(preset.rawValue)"),
              let data = try? (asset.data as NSData).decompressed(using: .zlib)
        else { return nil }
        return Kit(data as Data)
    }
}

/// Сканы растений — модели USDZ из Object Capture, см. `ScanView`. Лежат в
/// Application Support: скан — работа хозяина, а не кэш.
enum Scans {
    static let folder = place("Scans")

    static func url(_ name: String) -> URL? {
        folder?.appendingPathComponent(name)
    }

    /// Файл этого растения есть — его и ставим в AR.
    static func file(of plant: Plant) -> URL? {
        guard let name = plant.scan, let url = url(name),
              FileManager.default.fileExists(atPath: url.path)
        else { return nil }
        return url
    }

    /// Папка в Application Support — заводится при первом обращении.
    static func place(_ name: String) -> URL? {
        guard let support = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask).first
        else { return nil }
        let folder = support.appendingPathComponent(name, isDirectory: true)
        try? FileManager.default.createDirectory(
            at: folder, withIntermediateDirectories: true)
        return folder
    }
}
