import Foundation

/// Мастерская моделей: собирает объёмную модель по чертежу в фоне и держит
/// её в кэше на диске. Строит заранее — при посадке, при запуске и когда
/// меняется состав сада: без готовой модели дополненной реальности нет.
/// Кэш — в Caches: система может его вычистить, тогда модель соберётся по
/// чертежу заново. Как идёт сборка, видно на карточках — см. `Bench`.
actor Workshop {
    static let shared = Workshop()

    /// Последние открытые — в памяти: второй раз сад открывается мгновенно.
    /// Сад в AR ставит до дюжины растений разом — столько и держим.
    private var recent: [String: Kit] = [:]
    private var order: [String] = []
    private static let kept = 12

    /// Детализация по силе телефона, см. `Rig`. Известна с первой минуты:
    /// первая же сборка должна быть под этот телефон.
    let detail = Probe.detail

    /// Сборка — почти все проценты; остаток — запись на диск.
    private static let building = 0.95

    /// Готовая модель: из памяти, с диска или собранная сейчас.
    func kit(for plant: Plant) -> Kit {
        let key = key(plant)
        if let kit = recent[key] { return kit }
        let kit = read(key) ?? build(plant, key: key)
        remember(kit, key)
        return kit
    }

    /// Собрать заранее, если модели ещё нет.
    func prepare(_ plant: Plant) {
        let key = key(plant)
        guard !has(key) else {
            Self.report(plant.id, plant.blueprint.fingerprint, 1)
            return
        }
        _ = build(plant, key: key)
    }

    /// Обойти сад. Сперва сказать экранам, чьи модели готовы, а чьи ждут
    /// очереди, — это быстро; потом собрать недостающие и выбросить модели
    /// растений, которых больше нет.
    func tend(_ plants: [Plant]) {
        var missing: [Plant] = []
        for plant in plants {
            let ready = has(key(plant))
            if !ready { missing.append(plant) }
            Self.report(plant.id, plant.blueprint.fingerprint, ready ? 1 : 0)
        }
        for plant in missing { prepare(plant) }
        guard let folder = Workshop.folder,
              let files = try? FileManager.default.contentsOfDirectory(
                  atPath: folder.path)
        else { return }
        let alive = Set(plants.map { key($0) + ".kit" })
        for file in files where !alive.contains(file) {
            try? FileManager.default.removeItem(
                at: folder.appendingPathComponent(file))
        }
    }

    private func build(_ plant: Plant, key: String) -> Kit {
        let id = plant.id
        let stamp = plant.blueprint.fingerprint
        let meter = Meter(expected: Effort.expected(plant.blueprint.preset,
                                                    detail)) { share in
            Self.report(id, stamp, share * Self.building)
        }
        let kit = Meter.$current.withValue(meter) {
            Botany.grow(plant.blueprint, species: plant.species, detail: detail)
        }
        // Не записалась — держим в памяти: иначе модель считалась бы
        // несобранной, и AR ждал бы её вечно.
        if !write(kit, key) { remember(kit, key) }
        Self.report(id, stamp, 1)
        return kit
    }

    private func has(_ key: String) -> Bool {
        recent[key] != nil || exists(key)
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

    /// Детализация — в ключе: пересел на другой телефон из резервной копии
    /// — модели соберутся под него.
    private func key(_ plant: Plant) -> String {
        "\(plant.id)-\(plant.blueprint.fingerprint)-\(detail.key)"
    }

    private static let folder: URL? = {
        guard let caches = FileManager.default.urls(
            for: .cachesDirectory, in: .userDomainMask).first
        else { return nil }
        let folder = caches.appendingPathComponent("Models", isDirectory: true)
        try? FileManager.default.createDirectory(
            at: folder, withIntermediateDirectories: true)
        return folder
    }()

    private func file(_ key: String) -> URL? {
        Workshop.folder?.appendingPathComponent(key + ".kit")
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
}

extension Workshop {
    /// Заказать модель с экрана — после посадки или смены вида: карточка
    /// сразу показывает ноль процентов, сборка идёт в очереди мастерской.
    @MainActor
    static func order(_ plant: Plant) {
        Bench.shared.queue(plant)
        Task(priority: .utility) { await shared.prepare(plant) }
    }
}
