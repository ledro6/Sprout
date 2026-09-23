import Foundation

/// Мастерская моделей: собирает объёмную модель по чертежу в фоне и держит
/// её в кэше на диске. Строит заранее — при посадке и при запуске, — чтобы
/// сад в дополненной реальности открывался сразу. Кэш — в Caches: система
/// может его вычистить, тогда модель соберётся по чертежу заново.
actor Workshop {
    static let shared = Workshop()

    /// Последние открытые — в памяти: второй раз сад открывается мгновенно.
    private var recent: [String: Kit] = [:]
    private var order: [String] = []

    /// Готовая модель: из памяти, с диска или собранная сейчас.
    func kit(for plant: Plant) -> Kit {
        let key = Workshop.key(plant)
        if let kit = recent[key] { return kit }
        let kit = read(key) ?? build(plant, key: key)
        remember(kit, key)
        return kit
    }

    /// Собрать заранее, если модели ещё нет.
    func prepare(_ plant: Plant) {
        let key = Workshop.key(plant)
        guard recent[key] == nil, !exists(key) else { return }
        _ = build(plant, key: key)
    }

    /// Обойти сад: собрать недостающие модели и выбросить модели растений,
    /// которых больше нет.
    func tend(_ plants: [Plant]) {
        for plant in plants { prepare(plant) }
        guard let folder = Workshop.folder,
              let files = try? FileManager.default.contentsOfDirectory(
                  atPath: folder.path)
        else { return }
        let alive = Set(plants.map { Workshop.key($0) + ".kit" })
        for file in files where !alive.contains(file) {
            try? FileManager.default.removeItem(
                at: folder.appendingPathComponent(file))
        }
    }

    private func build(_ plant: Plant, key: String) -> Kit {
        let kit = Botany.grow(plant.blueprint, species: plant.species)
        write(kit, key)
        return kit
    }

    private func remember(_ kit: Kit, _ key: String) {
        recent[key] = kit
        order.removeAll { $0 == key }
        order.append(key)
        while order.count > 3 {
            recent[order.removeFirst()] = nil
        }
    }

    // MARK: - Диск

    static func key(_ plant: Plant) -> String {
        "\(plant.id)-\(plant.blueprint.fingerprint)"
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
    private func write(_ kit: Kit, _ key: String) {
        guard let url = file(key),
              let packed = try? (kit.encoded() as NSData)
                  .compressed(using: .lzfse)
        else { return }
        try? (packed as Data).write(to: url, options: .atomic)
    }

    private func read(_ key: String) -> Kit? {
        guard let url = file(key),
              let packed = try? Data(contentsOf: url),
              let data = try? (packed as NSData).decompressed(using: .lzfse)
        else { return nil }
        return Kit(data as Data)
    }
}
