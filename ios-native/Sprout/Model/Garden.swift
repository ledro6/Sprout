import Foundation
import Observation

/// Во сколько раз время в приложении быстрее настоящего.
///
/// В жизни почва сохнет неделю, и на экране это не разглядеть: проценты
/// не сдвинутся за весь сеанс. Поэтому у сада есть скорость времени —
/// её видно и можно переключить в профиле.
enum TimeSpeed: String, CaseIterable, Identifiable {
    /// Настоящее время: как в жизни.
    case real
    /// Секунда за час — сутки проходят за 24 секунды.
    case hour
    /// Секунда за сутки: всё пересыхает на глазах.
    case day

    var id: String { rawValue }

    var factor: Double {
        switch self {
        case .real: return 1
        case .hour: return 3_600
        case .day: return 86_400
        }
    }

    /// Коротко — подписи стоят в сегментах, там мало места. Подробности
    /// в подсказке под ними.
    var title: String {
        switch self {
        case .real: return "Как в жизни"
        case .hour: return "Быстрее"
        case .day: return "Ещё быстрее"
        }
    }

    var hint: String {
        switch self {
        case .real: return "Почва сохнет неделями — как на подоконнике."
        case .hour: return "Сутки проходят за 24 секунды."
        case .day: return "Сутки за секунду: полив нужен почти сразу."
        }
    }
}

/// Живой сад: комнаты, растения и время.
///
/// Влажность не хранится замороженной — сад её сушит. Раз в секунду
/// приложение отдаёт саду прошедшее время, и почва подсыхает ровно на
/// столько, сколько его прошло. Считаем от часов, а не от числа тактов:
/// пока приложение свёрнуто, таймер не идёт, а время идёт, и после
/// возвращения растения должны оказаться суше.
@Observable
final class Garden {
    var owner = Seed.owner
    var rooms = Seed.rooms
    var speed: TimeSpeed = .hour

    /// Когда сад считали в прошлый раз. Не наблюдаемое: от его смены
    /// перерисовывать нечего.
    @ObservationIgnored private var lastTick = Date()

    // MARK: - Время

    func advance(to now: Date = Date()) {
        let elapsed = now.timeIntervalSince(lastTick)
        lastTick = now
        guard elapsed > 0 else { return }
        let days = elapsed * speed.factor / 86_400
        for room in rooms.indices {
            for plant in rooms[room].plants.indices {
                rooms[room].plants[plant].dry(days: days)
            }
        }
    }

    // MARK: - Что где растёт

    var allPlants: [Plant] { rooms.flatMap(\.plants) }

    /// Те, кому пора пить, — самые сухие первыми.
    var thirsty: [Plant] {
        allPlants
            .filter { $0.thirst != .calm }
            .sorted { $0.moisture < $1.moisture }
    }

    var averageMoisture: Double {
        let plants = allPlants
        guard !plants.isEmpty else { return 0 }
        return plants.reduce(0) { $0 + $1.moisture } / Double(plants.count)
    }

    func plant(id: Plant.ID) -> Plant? {
        for room in rooms {
            if let found = room.plants.first(where: { $0.id == id }) { return found }
        }
        return nil
    }

    func roomName(of id: Plant.ID) -> String? {
        rooms.first { $0.plants.contains { $0.id == id } }?.name
    }

    func search(_ query: String) -> [Plant] { Seed.search(query, in: rooms) }

    // MARK: - Что с ними делают

    func water(_ id: Plant.ID) {
        change(id) { $0.moisture = 1 }
    }

    func waterAll() {
        for room in rooms.indices {
            for plant in rooms[room].plants.indices {
                rooms[room].plants[plant].moisture = 1
            }
        }
    }

    /// Пустое имя не сохраняем: безымянная карточка — это поломка, а не
    /// решение хозяина.
    func rename(_ id: Plant.ID, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        change(id) { $0.name = trimmed }
    }

    func delete(_ id: Plant.ID) {
        for room in rooms.indices {
            rooms[room].plants.removeAll { $0.id == id }
        }
    }

    /// Новое растение приходит политым: его только что поставили на
    /// подоконник и полили.
    func add(name: String, species: String, roomIndex: Int, dryingDays: Double) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, rooms.indices.contains(roomIndex) else { return }
        let kind = species.trimmingCharacters(in: .whitespacesAndNewlines)
        rooms[roomIndex].plants.append(
            Plant(id: UUID().uuidString,
                  name: trimmed,
                  species: kind.isEmpty ? "Растение" : kind,
                  moisture: 1,
                  dryingDays: dryingDays,
                  addedOn: Calendar.current.dateComponents(
                    [.year, .month, .day], from: Date())))
    }

    private func change(_ id: Plant.ID, _ edit: (inout Plant) -> Void) {
        for room in rooms.indices {
            if let index = rooms[room].plants.firstIndex(where: { $0.id == id }) {
                edit(&rooms[room].plants[index])
                return
            }
        }
    }
}
