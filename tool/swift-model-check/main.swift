import Foundation

var failed = 0
func check(_ got: String, _ want: String, _ what: String) {
    if got == want { print("  ✓ \(what)") }
    else { print("  ✗ \(what): получили «\(got)», ждали «\(want)»"); failed += 1 }
}
func check(_ got: Bool, _ what: String) {
    if got { print("  ✓ \(what)") }
    else { print("  ✗ \(what)"); failed += 1 }
}
/// Округление для сравнения дробей: считаем до сотых, чтобы не спорить
/// с последним битом.
func round2(_ value: Double) -> String {
    String(format: "%.2f", (value * 100).rounded() / 100)
}
func plant(moisture: Double, dryingDays: Double = 7) -> Plant {
    Plant(id: "x", name: "x", species: "x", moisture: moisture,
          dryingDays: dryingDays,
          addedOn: DateComponents(year: 2024, month: 1, day: 1))
}
func plantNamed(_ name: String, moisture: Double,
                dryingDays: Double) -> Plant {
    Plant(id: name, name: name, species: "x", moisture: moisture,
          dryingDays: dryingDays,
          addedOn: DateComponents(year: 2024, month: 1, day: 1))
}

print("склонение дней:")
func label(_ d: Int) -> String { Plant.wateringLabel(days: d) }
check(label(0),  "Следующий полив: сегодня", "0 → сегодня")
check(label(1),  "Следующий полив: завтра",  "1 → завтра")
check(label(2),  "Следующий полив: 2 дня",   "2 дня")
check(label(5),  "Следующий полив: 5 дней",  "5 дней")
check(label(11), "Следующий полив: 11 дней", "11 дней")
check(label(21), "Следующий полив: 21 день", "21 день")
check(label(22), "Следующий полив: 22 дня",  "22 дня")

print("данные из макета:")
let bedroom = Seed.rooms[0]
check(bedroom.name, "Спальня", "первая комната")
check("\(bedroom.plants.count)", "8", "растений в спальне")
check(bedroom.plants[0].moistureLabel, "89%", "влажность Баксика")
check(bedroom.plants[0].addedLabel, "Добавлен 2.11.2024", "дата добавления")
check(bedroom.plants[0].wateringLabel, "Следующий полив: 8 дней",
      "у Баксика 89% при сушке за 9 суток дают 8 дней")
check("\(Seed.rooms[1].plants.count)", "7", "растений в гостиной")
check("\(Seed.rooms[2].plants.count)", "11", "растений на кухне")

print("пороги тревоги:")
func thirst(_ m: Double) -> String { "\(plant(moisture: m).thirst)" }
check(thirst(1.00), "calm",  "100% — спокойно")
check(thirst(0.41), "calm",  "41% — ещё спокойно")
check(thirst(0.40), "calm",  "40% — порог, тревоги ещё нет")
check(thirst(0.39), "warn",  "39% — оранжевая")
check(thirst(0.21), "warn",  "21% — ещё оранжевая")
check(thirst(0.20), "warn",  "20% — порог, ещё оранжевая")
check(thirst(0.19), "alarm", "19% — уже красная")
check(thirst(0.00), "alarm", "0% — красная")

print("сила тревоги растёт с каждым процентом:")
func alarm(_ m: Double) -> String { round2(plant(moisture: m).alarm) }
check(alarm(0.50), "0.00", "50% — тревоги нет")
check(alarm(0.40), "0.00", "40% — ноль на пороге")
check(alarm(0.30), "0.25", "30% — четверть силы")
check(alarm(0.20), "0.50", "20% — половина, ровно там, где меняется цвет")
check(alarm(0.10), "0.75", "10% — три четверти")
check(alarm(0.00), "1.00", "0% — полная")

var previous = -1.0
var monotone = true
var step = 40
while step >= 0 {
    let value = plant(moisture: Double(step) / 100).alarm
    if value <= previous { monotone = false }
    previous = value
    step -= 1
}
check(monotone, "каждый процент вниз делает тень ярче предыдущего")
check(abs(plant(moisture: 0.20).alarm - plant(moisture: 0.201).alarm) < 0.01,
      "на переходе в красное яркость не прыгает — меняется только цвет")

print("у каждого растения свой темп:")
var fern = plant(moisture: 1, dryingDays: 7)
var cactus = plant(moisture: 1, dryingDays: 57)
fern.dry(days: 1)
cactus.dry(days: 1)
check(round2(fern.moisture), "0.86", "папоротник за сутки теряет седьмую часть")
check(round2(cactus.moisture), "0.98", "кактус за те же сутки — почти ничего")
check(fern.moisture < cactus.moisture, "темп у них разный")

var dry = plant(moisture: 0.05, dryingDays: 7)
dry.dry(days: 100)
check(round2(dry.moisture), "0.00", "ниже нуля влажность не уходит")

print("часы сада:")
let garden = Garden()
garden.rooms = Seed.rooms
let start = Date()
// 24 секунды при секунде за час — ровно сутки.
garden.advance(to: start)
garden.advance(to: start.addingTimeInterval(24))
let baksik = garden.plant(id: "baksik")!
check(round2(baksik.moisture), "0.78", "за сутки Баксик потерял девятую часть")

print("полив:")
garden.water("baksik")
check(round2(garden.plant(id: "baksik")!.moisture), "1.00", "полив наполняет до краёв")
check("\(garden.plant(id: "baksik")!.thirst)", "calm", "и снимает тревогу")
check(garden.plant(id: "baksik")!.wateringLabel, "Следующий полив: 9 дней",
      "срок пересчитался сам")

print("переименование и удаление:")
garden.rename("baksik", to: "  Барсик  ")
check(garden.plant(id: "baksik")!.name, "Барсик", "имя обрезается по краям")
garden.rename("baksik", to: "   ")
check(garden.plant(id: "baksik")!.name, "Барсик", "пустое имя не сохраняется")
garden.delete("baksik")
check(garden.plant(id: "baksik") == nil, "удалённое растение исчезает")
check("\(garden.rooms[0].plants.count)", "7", "и уходит из своей комнаты")

print("поиск по всей квартире:")
check("\(Seed.search("лера", in: Seed.rooms).count)", "1", "«лера» находит одно")
check("\(Seed.search("баксик", in: Seed.rooms).count)", "2", "«баксик» находит два")
check("\(Seed.search("монстера", in: Seed.rooms).count)", "2", "ищет и по виду")
check("\(Seed.search("   ", in: Seed.rooms).count)", "0", "пустой запрос ничего не возвращает")

print("настройки: значения по умолчанию и границы:")
let keys = ["theme", "patternKinds", "patternShapes", "reminders",
            "remindThreshold", "patternTint", "waveTint"]
let store = UserDefaults.standard
for key in keys { store.removeObject(forKey: key) }
let fresh = Settings(store: store)
check("\(fresh.theme)", "system", "тема по умолчанию — за системой")
check("\(fresh.chosen)", "[0, 1]", "в узоре росток и капля — узор макета")
check("\(fresh.patternTint)", "green", "узор по умолчанию зелёный — цвет макета")
check("\(fresh.waveTint)", "blue", "волна по умолчанию синяя")
check(fresh.reminders == false, "напоминания по умолчанию выключены")
check(round2(fresh.threshold), "0.20", "порог по умолчанию — двадцать процентов")

print("фигурки узора включаются по одной:")
fresh.toggle(shape: 2)
check("\(fresh.chosen)", "[0, 1, 2]", "цветок добавился к двум прежним")
fresh.toggle(shape: 0)
check("\(fresh.chosen)", "[1, 2]", "росток убрался — узор и без него живёт")
fresh.toggle(shape: 1)
check("\(fresh.chosen)", "[2]", "остался один цветок")
fresh.toggle(shape: 2)
check("\(fresh.chosen)", "[2]", "последнюю выключить нельзя: пустого фона не бывает")
fresh.toggle(shape: 9)
check("\(fresh.chosen)", "[2]", "несуществующая фигурка ничего не меняет")

print("настройки переживают запуск:")
fresh.theme = .dark
fresh.toggle(shape: 3)
fresh.reminders = true
fresh.threshold = 0.3
fresh.patternTint = .rose
fresh.waveTint = .amber
let reopened = Settings(store: store)
check("\(reopened.theme)", "dark", "тема прочиталась обратно")
check("\(reopened.chosen)", "[2, 3]", "и набор фигурок")
check(reopened.reminders, "и переключатель напоминаний")
check(round2(reopened.threshold), "0.30", "и порог")
check("\(reopened.patternTint)", "rose", "и цвет узора")
check("\(reopened.waveTint)", "amber", "и цвет волны")

print("оттенки:")
check("\(Tint.allCases.count)", "5", "пять оттенков на выбор")
check(Set(Tint.allCases.map(\.title)).count == Tint.allCases.count,
      "названия не повторяются")
check(Set(Tint.allCases.map(\.pale)).count == Tint.allCases.count,
      "бледные ипостаси не повторяются")
check(Set(Tint.allCases.map(\.vivid)).count == Tint.allCases.count,
      "насыщенные тоже")
// Бледные держатся на одной светлоте: смена цвета не должна менять то,
// насколько узор заметен. Считаем по формуле яркости для sRGB.
func brightness(_ c: Channels) -> Double {
    (0.2126 * c.red + 0.7152 * c.green + 0.0722 * c.blue) / 255
}
let pales = Tint.allCases.map { brightness($0.pale) }
let spread = pales.max()! - pales.min()!
check(spread <= 0.01,
      "бледные ипостаси одной светлоты — разброс \(round2(spread))")
check(Tint.allCases.allSatisfy { brightness($0.vivid) < brightness($0.pale) },
      "насыщенная ипостась всегда темнее бледной")
// Насыщенная ипостась должна быть насыщенной на самом деле: ею идёт волна
// и ею же лежит узор в тёмной теме, а бледный цвет там читается серым.
// Мерим размахом каналов — у серого он ноль.
func chroma(_ c: Channels) -> Double {
    max(c.red, c.green, c.blue) - min(c.red, c.green, c.blue)
}
let dullest = Tint.allCases.min { chroma($0.vivid) < chroma($1.vivid) }!
check(Tint.allCases.allSatisfy { chroma($0.vivid) >= 150 },
      "самая тусклая насыщенная — \(dullest.title), размах "
      + "\(Int(chroma(dullest.vivid)))")
check("\(Tint(rawValue: 99) == nil)", "true", "мусор в ключе оттенком не станет")

print("прежняя настройка «сколько фигурок» переносится в набор:")
for key in keys { store.removeObject(forKey: key) }
store.set(3, forKey: "patternKinds")
check("\(Settings(store: store).chosen)", "[0, 1, 2]",
      "«три» стали первыми тремя, а не сбросом на умолчание")
store.set(99, forKey: "patternKinds")
check("\(Settings(store: store).chosen)", "[0, 1]",
      "мусор в старом ключе — берём умолчание")

print("раскладка узора: одинаковые не стоят рядом:")
// Перебираем все раскладки, какие может выбрать запуск, и всю округу
// каждой: соседей у узла четверо, но хватает правого и нижнего — левый и
// верхний те же соседи, только с другой стороны.
var clashes = 0
var arrangements: [Int: Set<[Int]>] = [:]
for count in 1...4 {
    var seen = Set<[Int]>()
    for twistX in 0 ..< 64 {
        for twistY in 0 ..< 64 {
            for start in 0 ..< 64 {
                let weave = Weave(count: count, twistX: twistX,
                                  twistY: twistY, start: start)
                seen.insert([weave.stepX, weave.stepY, weave.shift])
                guard count > 1 else { continue }
                for row in -3...3 {
                    for node in -6...6 {
                        let here = weave.index(column: node / 2, slot: node % 2,
                                               row: row, of: count)
                        let right = weave.index(column: (node + 1) / 2,
                                                slot: (node + 1) % 2,
                                                row: row, of: count)
                        let below = weave.index(column: node / 2, slot: node % 2,
                                                row: row + 1, of: count)
                        if here == right || here == below { clashes += 1 }
                    }
                }
            }
        }
    }
    arrangements[count] = seen
}
check("\(clashes)", "0", "ни в одной раскладке нет двух одинаковых рядом")
check("\(arrangements[1]!.count)", "1", "при одной фигурке раскладка одна")
check("\(arrangements[2]!.count)", "2",
      "при двух — две: у шахматной доски других расцветок не бывает")
check("\(arrangements[3]!.count)", "12", "при трёх — двенадцать")
check("\(arrangements[4]!.count)", "16", "при четырёх — шестнадцать")

let alone = Weave()
check("\(alone.index(column: 3, slot: 1, row: 2, of: 1))", "0",
      "одна фигурка стоит везде, что бы ни спросили")

print("шаг раскладки взаимно прост с числом фигурок:")
func divisor(_ a: Int, _ b: Int) -> Int { b == 0 ? a : divisor(b, a % b) }
for count in 2...4 {
    let steps = Set(arrangements[count]!.flatMap { [$0[0], $0[1]] })
    check(steps.allSatisfy { divisor($0, count) == 1 },
          "при \(count) фигурках шаг обходит все, а не через одну")
}

print("срок напоминания:")
func delay(_ moisture: Double, _ dryingDays: Double = 7,
           _ threshold: Double = 0.2) -> String {
    guard let seconds = Reminder.delay(
        for: plant(moisture: moisture, dryingDays: dryingDays),
        threshold: threshold)
    else { return "никогда" }
    return round2(seconds)
}
// Час сада проходит за секунду: 0.3 от семи суток — это 2.1 суток сада,
// то есть 50.4 суток по 24 «часа»-секунды.
check(delay(0.50), "50.40", "с 50% до 20% при недельной сушке — 50.4 секунды")
check(delay(0.50, 14), "100.80", "вдвое медленнее сохнет — вдвое дольше ждать")
check(delay(0.20), "0.00", "ровно на пороге — уже пора")
check(delay(0.05), "0.00", "ниже порога — тем более")
check(delay(0.50, 0), "никогда", "без скорости сушки срока нет")
check(delay(0.50, 7, 0.4), "16.80", "порог выше — ждать меньше")

print("кого будить первым:")
let thirsty = [
    Room(name: "Комната", plants: [
        plantNamed("Тихоня", moisture: 0.9, dryingDays: 7),
        plantNamed("Борис", moisture: 0.25, dryingDays: 5),
        plantNamed("Сумка", moisture: 0.05, dryingDays: 6),
        plantNamed("Кефир", moisture: 0.1, dryingDays: 6),
    ]),
]
let due = Reminder.next(in: thirsty, threshold: 0.2)!
check(due.plant.name, "Сумка", "первой — та, что уже суше всех")
check("\(due.others)", "1", "и с ней ещё одна такая же")
check(round2(due.after), "15.00", "срок не раньше, чем через четверть минуты")
check(Reminder.text(for: due), "«Сумка» и ещё 1 растение просят воды",
      "строка уведомления с соседями")

let single = Reminder.next(in: [Room(name: "Комната", plants: [
    plantNamed("Борис", moisture: 0.5, dryingDays: 5),
])], threshold: 0.2)!
check(single.plant.name, "Борис", "в одиночку — он один и есть")
check("\(single.others)", "0", "соседей нет")
check(round2(single.after), "36.00", "0.3 от пяти суток — 36 секунд")
check(Reminder.text(for: single), "«Борис» просит воды", "строка про одного")

check(Reminder.next(in: [], threshold: 0.2) == nil,
      "в пустой квартире будить некого")

print("склонение растений в уведомлении:")
func many(_ n: Int) -> String {
    Reminder.text(for: Reminder.Due(plant: plantNamed("Х", moisture: 0,
                                                      dryingDays: 1),
                                    others: n, after: 0))
}
check(many(1), "«Х» и ещё 1 растение просят воды", "1 растение")
check(many(2), "«Х» и ещё 2 растения просят воды", "2 растения")
check(many(5), "«Х» и ещё 5 растений просят воды", "5 растений")

if failed > 0 {
    print("\nне сошлось: \(failed)")
    exit(1)
}
print("\nвсё сошлось")
