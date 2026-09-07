import Foundation

var failed = 0
func check(_ got: String, _ want: String, _ what: String) {
    if got == want { print("  ✓ \(what)") }
    else { print("  ✗ \(what): получили «\(got)», ждали «\(want)»"); failed += 1 }
}

print("склонение дней:")
check(Plant.wateringLabel(days: 0),  "Следующий полив сегодня", "0 → сегодня")
check(Plant.wateringLabel(days: 1),  "Следующий полив завтра",  "1 → завтра")
check(Plant.wateringLabel(days: 2),  "Следующий полив через 2 дня",   "2 дня")
check(Plant.wateringLabel(days: 5),  "Следующий полив через 5 дней",  "5 дней")
check(Plant.wateringLabel(days: 11), "Следующий полив через 11 дней", "11 дней")
check(Plant.wateringLabel(days: 21), "Следующий полив через 21 день", "21 день")
check(Plant.wateringLabel(days: 22), "Следующий полив через 22 дня",  "22 дня")

print("данные из макета:")
let bedroom = Seed.rooms[0]
check(bedroom.name, "Спальня", "первая комната")
check("\(bedroom.plants.count)", "5", "растений в спальне")
check("\(Seed.rooms[1].plants.count)", "4", "растений в гостиной")
check("\(Seed.rooms[2].plants.count)", "8", "растений на кухне")
check(bedroom.plants[0].moistureLabel, "89%", "влажность Баксика")
check(bedroom.plants[0].addedLabel, "Добавлен 2.11.2024", "дата добавления")

print("сроки полива сошлись с макетом:")
let fromDesign: [(String, Int)] = [
    ("baksik", 8), ("pr", 1), ("zelenik", 2),
    ("murzik", 8), ("privet", 1), ("lera", 5), ("sumka", 0),
]
let everyone = Seed.rooms.flatMap(\.plants)
for (id, days) in fromDesign {
    let plant = everyone.first { $0.id == id }
    check("\(plant?.daysUntilWatering ?? -1)", "\(days)", "\(plant?.name ?? id) → \(days)")
}

print("тревожность:")
func thirst(_ moisture: Double, _ dryingDays: Double) -> String {
    let pot = Plant(id: "x", name: "x", species: "x", moisture: moisture,
                    dryingDays: dryingDays, addedOn: DateComponents())
    return "\(pot.thirst)"
}
check(thirst(0.02, 7), "now",  "почти сухая → сильное свечение")
check(thirst(0.14, 7), "soon", "на день воды → мягкое")
check(thirst(0.89, 9), "calm", "полная → спокойно")

print("почва сохнет и полив её возвращает:")
var pot = Plant(id: "x", name: "x", species: "x", moisture: 1,
                dryingDays: 10, addedOn: DateComponents())
pot.dry(days: 2.5)
check(pot.moistureLabel, "75%", "за четверть срока ушла четверть влаги")
check("\(pot.daysUntilWatering)", "8", "и до полива осталось 8 суток")
pot.dry(days: 100)
check(pot.moistureLabel, "0%", "ниже нуля не уходит")
pot.moisture = 1
check(pot.moistureLabel, "100%", "полив возвращает к полной")

print("поиск по всей квартире:")
let found = Seed.search("лера", in: Seed.rooms)
check("\(found.count)", "1", "«лера» находит одно растение")
check(found.first?.name ?? "—", "Лера", "и это Лера с кухни")
check("\(Seed.search("монстера", in: Seed.rooms).count)", "2",
      "поиск идёт и по виду растения")
check("\(Seed.search("   ", in: Seed.rooms).count)", "0",
      "пустой запрос ничего не возвращает")

print("")
if failed == 0 { print("всё сошлось") }
else { print("не сошлось: \(failed)"); exit(1) }
