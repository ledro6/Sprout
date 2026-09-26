import Foundation

/// Черенок — растение, переданное другу кодом: кличка, вид, срок полива и
/// уход. У друга оно сажается с тем же, что знал о нём хозяин, — не
/// угадывать срок заново. Снимок в код не идёт: он большой, а переписка —
/// нет.
struct Cutting: Codable, Hashable, Sendable {
    var name: String
    var species: String
    /// Срок полива в днях сада.
    var days: Double
    var feed: Double?
    var repot: Double?
    /// Мелкий уход: `Duty` — раз в сколько дней, ноль — не нужен.
    var duties: [String: Double]?
    /// Кто передал.
    var from: String

    enum CodingKeys: String, CodingKey {
        case name = "n", species = "s", days = "d", feed = "f", repot = "r"
        case duties = "u", from = "o"
    }

    static let mark = "SPROUTC1."

    init(name: String, species: String, days: Double, feed: Double? = nil,
         repot: Double? = nil, duties: [String: Double]? = nil,
         from: String) {
        self.name = name
        self.species = species
        self.days = days
        self.feed = feed
        self.repot = repot
        self.duties = duties
        self.from = from
    }

    init(plant: Plant, from owner: String) {
        let care = plant.tending
        var chores: [String: Double] = [:]
        for duty in Duty.allCases {
            chores[duty.rawValue] = care.every(duty) ?? 0
        }
        self.init(name: plant.name, species: plant.species,
                  days: plant.dryingDays, feed: care.feedEvery,
                  repot: care.repotEvery, duties: chores, from: owner)
    }

    /// Сроки мелкого ухода — как их ждёт `Garden.tend`.
    var chores: [Duty: Double?] {
        var out: [Duty: Double?] = [:]
        for (key, every) in duties ?? [:] {
            guard let duty = Duty(rawValue: key) else { continue }
            out[duty] = max(every, 0)
        }
        return out
    }

    var code: String { Codeword.encode(self, mark: Self.mark) }

    /// Сперва человеческая часть: как поливать, видно и без Sprout.
    var card: String {
        let head = Lang.format("%1$@ передаёт черенок: «%2$@», %3$@.", from,
                               name, species)
        let water = Lang.text("Полив —") + " "
            + Lang.format("раз в %lld дней", Int(days.rounded())) + "."
        let invite = Lang.text("Посадить: скопируйте это сообщение целиком и нажмите «Вставить» у строки «Черенок от друга» в Sprout → Добавить.")
        return head + " " + water + "\n" + invite + "\n" + code
    }

    static func read(_ text: String) -> Cutting? {
        Codeword.decode(Cutting.self, mark: mark, in: text) {
            !$0.name.trimmingCharacters(in: .whitespaces).isEmpty
                && $0.days > 0 && $0.days <= 365
        }
    }
}
