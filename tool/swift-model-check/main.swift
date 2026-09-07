import Foundation

var failed = 0
func check(_ got: String, _ want: String, _ what: String) {
    if got == want { print("  ✓ \(what)") }
    else { print("  ✗ \(what): получили «\(got)», ждали «\(want)»"); failed += 1 }
}
func plant(days: Int) -> Plant {
    Plant(id: "x", name: "x", species: "x", moisture: 0.5,
          daysUntilWatering: days, addedOn: DateComponents(year: 2024, month: 1, day: 1))
}

print("склонение дней:")
check(plant(days: 0).wateringLabel,  "Следующий полив сегодня", "0 → сегодня")
check(plant(days: 1).wateringLabel,  "Следующий полив завтра",  "1 → завтра")
check(plant(days: 2).wateringLabel,  "Следующий полив через 2 дня",   "2 дня")
check(plant(days: 5).wateringLabel,  "Следующий полив через 5 дней",  "5 дней")
check(plant(days: 11).wateringLabel, "Следующий полив через 11 дней", "11 дней")
check(plant(days: 21).wateringLabel, "Следующий полив через 21 день", "21 день")
check(plant(days: 22).wateringLabel, "Следующий полив через 22 дня",  "22 дня")

print("данные из макета:")
let bedroom = Garden.rooms[0]
check(bedroom.name, "Спальня", "первая комната")
check("\(bedroom.plants.count)", "5", "растений в спальне")
check(bedroom.plants[0].moistureLabel, "89%", "влажность Баксика")
check(bedroom.plants[0].addedLabel, "Добавлен 2.11.2024", "дата добавления")
check(bedroom.plants[1].wateringLabel, "Следующий полив завтра", "полив «Пр»")
check("\(Garden.rooms[1].plants.count)", "4", "растений в гостиной")
check("\(Garden.rooms[2].plants.count)", "8", "растений на кухне")

print("тревожность:")
func thirst(_ d: Int) -> String { "\(plant(days: d).thirst)" }
check(thirst(0), "now", "сегодня → сильное свечение")
check(thirst(1), "soon", "завтра → мягкое")
check(thirst(8), "calm", "через 8 дней → спокойно")

print("поиск по всей квартире:")
let found = Garden.search("лера")
check("\(found.count)", "1", "«лера» находит одно растение")
check(found.first?.name ?? "—", "Лера", "и это Лера с кухни")
check("\(Garden.search("монстера").count)", "2", "поиск идёт и по виду растения")
check("\(Garden.search("   ").count)", "0", "пустой запрос ничего не возвращает")

print(failed == 0 ? "\nвсё сошлось" : "\nпровалено проверок: \(failed)")
exit(failed == 0 ? 0 : 1)
