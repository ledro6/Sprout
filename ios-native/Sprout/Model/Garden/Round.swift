import Foundation

/// «Обход сада» — живое действие на экране блокировки и в Dynamic Island:
/// кто просит воды, по одному, с кнопкой «Полил». Список собирается в начале
/// обхода, от самого сухого, и дальше не пересобирается — растения только
/// отмечаются. Файл общий с виджетом: живое действие рисует он.
enum Round {
    /// Остановка обхода — растение и что с ним стало.
    struct Stop: Codable, Hashable, Identifiable, Sendable {
        enum Mark: String, Codable, Sendable {
            case waiting, watered, skipped
        }

        var id: Plant.ID
        var name: String
        var room: String
        /// Влажность в начале обхода, в процентах.
        var percent: Int
        /// Имя картинки в общей папке, см. `Store.thumb`.
        var thumb: String?
        var mark = Mark.waiting
    }

    /// Больше дюжины полоска остановок не покажет.
    static let limit = 12

    /// На экране блокировки имя всё равно в одну строку.
    static let nameLimit = 32

    /// Живое действие весит не больше четырёх килобайт — остановок берём,
    /// сколько влезет с запасом на то, как их упакует система.
    static let budget = 3400

    /// Кого обойти: всех, кто просит воды, — от самого сухого.
    static func stops(in rooms: [Room],
                      thumb: (Plant) -> String? = { _ in nil }) -> [Stop] {
        var thirsty: [(room: String, plant: Plant)] = []
        for room in rooms {
            for plant in room.plants where plant.thirst != .calm {
                thirsty.append((room.name, plant))
            }
        }
        thirsty.sort { $0.plant.moisture < $1.plant.moisture }
        var stops: [Stop] = []
        for (room, plant) in thirsty.prefix(limit) {
            let percent = Int((plant.moisture * 100).rounded())
            stops.append(Stop(id: plant.id, name: clip(plant.name),
                              room: clip(room), percent: percent,
                              thumb: thumb(plant)))
        }
        while stops.count > 1, weight(stops) > budget { stops.removeLast() }
        return stops
    }

    /// Сколько байт займут остановки в живом действии.
    static func weight(_ stops: [Stop]) -> Int {
        (try? JSONEncoder().encode(stops))?.count ?? 0
    }

    /// Полит тот, у кого в журнале есть полив с начала обхода, — откуда бы
    /// ни полили: из обхода, с экрана растения, из виджета. Отменили полив —
    /// растение снова ждёт. Ушедшее из сада — пропущено: поливать некого.
    static func mark(_ stops: [Stop], log: [Watering], since: Date,
                     alive: Set<Plant.ID>) -> [Stop] {
        let poured = Set(log.lazy.filter { $0.when >= since }.map(\.plant))
        return stops.map { stop in
            var stop = stop
            if poured.contains(stop.id) {
                stop.mark = .watered
            } else if stop.mark == .watered {
                stop.mark = .waiting
            }
            if stop.mark == .waiting, !alive.contains(stop.id) {
                stop.mark = .skipped
            }
            return stop
        }
    }

    /// «Не сейчас» — дальше, не поливая.
    static func skip(_ id: Plant.ID, in stops: [Stop]) -> [Stop] {
        stops.map { stop in
            var stop = stop
            if stop.id == id, stop.mark == .waiting { stop.mark = .skipped }
            return stop
        }
    }

    static func next(_ stops: [Stop]) -> Stop? {
        stops.first { $0.mark == .waiting }
    }

    /// Пройдено — политые и пропущенные.
    static func passed(_ stops: [Stop]) -> Int {
        stops.count { $0.mark != .waiting }
    }

    static func watered(_ stops: [Stop]) -> Int {
        stops.count { $0.mark == .watered }
    }

    static func clip(_ text: String) -> String {
        text.count > nameLimit ? String(text.prefix(nameLimit - 1)) + "…" : text
    }
}
