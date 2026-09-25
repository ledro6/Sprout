import Foundation

/// Сроки сада для Календаря телефона: по событию на день и дело — кого
/// полить, кого подкормить. Дни сада переводятся в настоящие через
/// `Garden.speed`, как у напоминаний: иначе в Календаре полив стоял бы
/// через неделю, а карточка уже просила воды.
enum Agenda {
    enum Chore: String, Sendable {
        case water
        case feed
    }

    /// Растение в событии — с комнатой: в заметке события растения
    /// разложены по комнатам. Номер — чтобы быстрое растение не попало в
    /// один день дважды, а два тёзки попали оба.
    struct Pot: Equatable, Sendable {
        var id: Plant.ID
        var name: String
        var room: String
    }

    struct Entry: Equatable, Sendable {
        /// Начало суток: событие — на весь день.
        var day: Date
        var chore: Chore
        var pots: [Pot]

        /// «Полить: Баксик, Лера».
        var title: String {
            let names = pots.map(\.name).joined(separator: ", ")
            return switch chore {
            case .water: Lang.format("Полить: %@", names)
            case .feed: Lang.format("Подкормить: %@", names)
            }
        }

        /// По строке на комнату, в порядке сада.
        var notes: String {
            var rooms: [String] = []
            var names: [String: [String]] = [:]
            for pot in pots {
                if names[pot.room] == nil { rooms.append(pot.room) }
                names[pot.room, default: []].append(pot.name)
            }
            return rooms.map {
                "\($0): " + (names[$0] ?? []).joined(separator: ", ")
            }.joined(separator: "\n")
        }
    }

    /// Три недели вперёд: дальше срок всё равно сдвинется от первого же
    /// полива не день в день.
    static let horizon = 21

    /// Первый полив — когда земля высохнет, как «Следующий полив» на
    /// карточке; дальше — через срок, если поливать вовремя. Подкормка — в
    /// пору роста: зимой её счёт стоит, и в Календаре её нет.
    static func plan(_ rooms: [Room], now: Date = Date(),
                     horizon: Int = horizon,
                     calendar: Calendar = .current) -> [Entry] {
        let today = calendar.startOfDay(for: now)
        guard let end = calendar.date(byAdding: .day, value: horizon,
                                      to: today) else { return [] }
        var days: [Date: [Chore: [Pot]]] = [:]

        func mark(_ pot: Pot, _ chore: Chore, first: Double, every: Double) {
            guard first.isFinite, every > 0 else { return }
            var at = now.addingTimeInterval(real(first))
            while at < end {
                let day = calendar.startOfDay(for: max(at, now))
                var pots = days[day, default: [:]][chore, default: []]
                if !pots.contains(where: { $0.id == pot.id }) {
                    pots.append(pot)
                    days[day, default: [:]][chore] = pots
                }
                at = at.addingTimeInterval(real(every))
            }
        }

        for room in rooms {
            for plant in room.plants where plant.period > 0 {
                let pot = Pot(id: plant.id, name: plant.name, room: room.name)
                mark(pot, .water, first: plant.moisture * plant.period,
                     every: plant.period)
                let care = plant.tending
                if Season.growing, let left = care.feedIn,
                   let every = care.feedEvery {
                    mark(pot, .feed, first: left, every: every)
                }
            }
        }
        return days.keys.sorted().flatMap { day in
            [Chore.water, .feed].compactMap { chore in
                days[day]?[chore].map { Entry(day: day, chore: chore, pots: $0) }
            }
        }
    }

    /// Дни сада — в настоящие секунды.
    static func real(_ days: Double) -> TimeInterval {
        days * 86_400 / Garden.speed
    }
}
