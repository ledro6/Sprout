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
/// До сотых — чтобы не спорить с последним битом.
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
garden.remove("baksik")
check(garden.plant(id: "baksik") == nil, "удалённое растение исчезает")
check("\(garden.rooms[0].plants.count)", "7", "и уходит из своей комнаты")

print("перестановка в комнате:")
func lineup(_ room: Int) -> [String] { garden.rooms[room].plants.map(\.id) }
let lined = lineup(0)
let (p1, p2, p3, p4) = (lined[0], lined[1], lined[2], lined[3])
garden.move(p1, to: p3)
check(lineup(0)[0 ..< 4] == [p2, p3, p1, p4][...],
      "вперёд — встаёт за тем, над кем держат, сосед отступает назад")
garden.move(p1, to: p2)
check(lineup(0)[0 ..< 4] == [p1, p2, p3, p4][...],
      "назад — встаёт перед ним, и порядок вернулся")
garden.move(p4, to: p1)
check(lineup(0)[0 ..< 4] == [p4, p1, p2, p3][...],
      "с конца в начало — остальные сдвинулись на одно")
check(lineup(0).count == lined.count && Set(lineup(0)) == Set(lined),
      "никто не потерялся и не задвоился")
let kitchenLine = lineup(2)
garden.move(p1, to: kitchenLine[0])
check(lineup(0)[0 ..< 4] == [p4, p1, p2, p3][...]
      && lineup(2) == kitchenLine, "в чужую комнату не переносит")
garden.move(p1, to: p1)
check(lineup(0)[0 ..< 4] == [p4, p1, p2, p3][...],
      "на своё же место — ничего не меняется")
garden.move("никого-нет", to: p1)
check(lineup(0)[0 ..< 4] == [p4, p1, p2, p3][...],
      "чужой номер ничего не трогает")
let shuffled = lineup(0)
// Через слепок: на Linux папка документов не идёт за подменённым HOME.
let lineupFile = try! JSONEncoder().encode(garden.state)
let lineupBack = try! JSONDecoder().decode(GardenState.self, from: lineupFile)
check(lineupBack.rooms[0].plants.map(\.id) == shuffled,
      "порядок ложится в файл сада и читается обратно")

print("поиск по всей квартире:")
check("\(Seed.search("лера", in: Seed.rooms).count)", "1", "«лера» находит одно")
check("\(Seed.search("баксик", in: Seed.rooms).count)", "2", "«баксик» находит два")
check("\(Seed.search("монстера", in: Seed.rooms).count)", "2", "ищет и по виду")
check("\(Seed.search("   ", in: Seed.rooms).count)", "0", "пустой запрос ничего не возвращает")

print("настройки: значения по умолчанию и границы:")
let keys = ["theme", "patternKinds", "patternShapes", "reminders",
            "remindThreshold", "patternTint", "waveTint",
            "hushedHaptics", "stillPattern", "stiffShapes",
            "plantLook", "plantOrder"]
let store = UserDefaults.standard
for key in keys { store.removeObject(forKey: key) }
let fresh = Settings(store: store)
check("\(fresh.theme)", "system", "тема по умолчанию — за системой")
check("\(fresh.look)", "grid", "растения по умолчанию плиткой — как в макете")
check("\(fresh.order)", "manual", "и в том порядке, в каком их расставили")
check("\(fresh.chosen)", "[0, 1]", "в узоре росток и капля — узор макета")
check("\(fresh.patternTint)", "green", "узор по умолчанию зелёный — цвет макета")
check("\(fresh.waveTint)", "blue", "волна по умолчанию синяя")
check(fresh.reminders == false, "напоминания по умолчанию выключены")
check(fresh.haptics, "отклик в руке по умолчанию включён")
check(fresh.parallax, "узор по умолчанию едет за наклоном")
check(fresh.sway, "и фигурки по умолчанию расходятся")
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
fresh.look = .list
fresh.order = .thirsty
fresh.toggle(shape: 3)
fresh.reminders = true
fresh.threshold = 0.3
fresh.patternTint = .rose
fresh.waveTint = .amber
let reopened = Settings(store: store)
check("\(reopened.theme)", "dark", "тема прочиталась обратно")
check("\(reopened.look)", "list", "и вид списком")
check("\(reopened.order)", "thirsty", "и порядок «сначала сухие»")
check("\(reopened.chosen)", "[2, 3]", "и набор фигурок")
check(reopened.reminders, "и переключатель напоминаний")
check(round2(reopened.threshold), "0.30", "и порог")
check("\(reopened.patternTint)", "rose", "и цвет узора")
check("\(reopened.waveTint)", "amber", "и цвет волны")
fresh.parallax = false
fresh.sway = false
let stilled = Settings(store: store)
check(stilled.parallax == false, "выключенный параллакс прочитался обратно")
check(stilled.sway == false, "и выключенный разъезд")
fresh.parallax = true
fresh.sway = true
check(Settings(store: store).parallax, "и включённый обратно тоже")

print("оттенки:")
check("\(Tint.allCases.count)", "5", "пять оттенков на выбор")
check(Set(Tint.allCases.map(\.title)).count == Tint.allCases.count,
      "названия не повторяются")
check(Set(Tint.allCases.map(\.pale)).count == Tint.allCases.count,
      "бледные ипостаси не повторяются")
check(Set(Tint.allCases.map(\.vivid)).count == Tint.allCases.count,
      "насыщенные тоже")
// Бледные — на одной светлоте (по формуле для sRGB): смена цвета не должна
// менять заметность узора.
func brightness(_ c: Channels) -> Double {
    (0.2126 * c.red + 0.7152 * c.green + 0.0722 * c.blue) / 255
}
let pales = Tint.allCases.map { brightness($0.pale) }
let spread = pales.max()! - pales.min()!
check(spread <= 0.01,
      "бледные ипостаси одной светлоты — разброс \(round2(spread))")
check(Tint.allCases.allSatisfy { brightness($0.vivid) < brightness($0.pale) },
      "насыщенная ипостась всегда темнее бледной")
// Насыщенная должна быть насыщенной: размах каналов у серого — ноль.
func chroma(_ c: Channels) -> Double {
    max(c.red, c.green, c.blue) - min(c.red, c.green, c.blue)
}
let dullest = Tint.allCases.min { chroma($0.vivid) < chroma($1.vivid) }!
check(Tint.allCases.allSatisfy { chroma($0.vivid) >= 150 },
      "самая тусклая насыщенная — \(dullest.title), размах "
      + "\(Int(chroma(dullest.vivid)))")
check("\(Tint(rawValue: 99) == nil)", "true", "мусор в ключе оттенком не станет")

print("смесь оттенков — ею идёт плавная смена цвета:")
let rose = Shade(.rose), amber = Shade(.amber)
check(Shade.mix(rose, amber, 0) == rose, "в начале перехода — прежний целиком")
check(Shade.mix(rose, amber, 1) == amber, "в конце — новый целиком")
check(Shade.mix(rose, amber, -5) == rose, "доля ниже нуля не откатывает дальше")
check(Shade.mix(rose, amber, 5) == amber, "и выше единицы не забегает")
let half = Shade.mix(rose, amber, 0.5)
check("\(half.pale.red) \(half.pale.green) \(half.pale.blue)",
      "255.0 231.5 222.0", "на середине — середина, канал за каналом")
// Ипостаси смешиваются каждая со своей — иначе середина перехода уходила бы в
// серый.
check(half.pale == Channels.mix(rose.pale, amber.pale, 0.5),
      "бледная смешивается с бледной")
check(half.vivid == Channels.mix(rose.vivid, amber.vivid, 0.5),
      "насыщенная с насыщенной")
check(Shade(.rose) != Shade(.amber), "разные оттенки дают разные смеси")

print("прежняя настройка «сколько фигурок» переносится в набор:")
for key in keys { store.removeObject(forKey: key) }
store.set(3, forKey: "patternKinds")
check("\(Settings(store: store).chosen)", "[0, 1, 2]",
      "«три» стали первыми тремя, а не сбросом на умолчание")
store.set(99, forKey: "patternKinds")
check("\(Settings(store: store).chosen)", "[0, 1]",
      "мусор в старом ключе — берём умолчание")

print("раскладка узора: одинаковые не стоят рядом:")
// Все раскладки запуска и вся округа каждой; хватает правого и нижнего
// соседа.
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

print("журнал поливов и статистика:")
var clock = Calendar(identifier: .gregorian)
clock.timeZone = TimeZone(identifier: "UTC")!
let noon = clock.date(from: DateComponents(year: 2026, month: 9, day: 18,
                                           hour: 12))!
func day(_ back: Int, _ hour: Int = 10) -> Date {
    clock.date(byAdding: .day, value: -back,
               to: clock.date(bySettingHour: hour, minute: 0, second: 0,
                              of: noon)!)!
}
func note(_ plant: String, _ back: Int) -> Watering {
    Watering(plant: plant, when: day(back))
}

let plot = [
    Room(name: "Спальня", plants: [plantNamed("Баксик", moisture: 1, dryingDays: 9),
                                   plantNamed("Борис", moisture: 1, dryingDays: 5)]),
    Room(name: "Кухня", plants: [plantNamed("Мурзик", moisture: 1, dryingDays: 7)]),
]
let journal = [note("Баксик", 0), note("Баксик", 0), note("Борис", 0),
               note("Мурзик", 1), note("Баксик", 2),
               note("Борис", 9), note("Борис", 20)]
let score = Score.of(journal, rooms: plot, now: noon, calendar: clock)
check("\(score.total)", "7", "всего поливов — весь журнал")
check("\(score.today)", "3", "сегодня — только сегодняшние")
check("\(score.week)", "5", "за неделю — шесть дней назад и ближе")
check("\(score.days.count)", "14", "в ряду для графика ровно две недели")
check(score.days.first!.day < score.days.last!.day, "ряд идёт от старого к новому")
check("\(score.days.last!.count)", "3", "последний день ряда — сегодня")
check("\(score.days.map(\.count).filter { $0 == 0 }.count)", "10",
      "пустые дни в ряду есть: поливали в четыре дня из четырнадцати")

print("череда дней:")
check("\(score.streak)", "3", "сегодня, вчера и позавчера — это три подряд")
let withGap = [note("Баксик", 0), note("Баксик", 2), note("Баксик", 3)]
check("\(Score.of(withGap, rooms: plot, now: noon, calendar: clock).streak)",
      "1", "вчерашний пропуск обрывает: в череде только сегодня")
let inARow = [note("Баксик", 0), note("Баксик", 1), note("Баксик", 2)]
check("\(Score.of(inARow, rooms: plot, now: noon, calendar: clock).streak)", "3",
      "три дня подряд — череда в три")
let sinceYesterday = [note("Баксик", 1), note("Баксик", 2)]
check("\(Score.of(sinceYesterday, rooms: plot, now: noon, calendar: clock).streak)",
      "2", "сегодня ещё не полили — череда жива, день не кончился")
let stale = [note("Баксик", 2), note("Баксик", 3)]
check("\(Score.of(stale, rooms: plot, now: noon, calendar: clock).streak)", "0",
      "пропустили вчера целиком — череда оборвана")
check("\(Score.of([], rooms: plot, now: noon, calendar: clock).streak)", "0",
      "в пустом журнале череды нет")
let twoRuns = [note("Баксик", 10), note("Баксик", 11), note("Баксик", 12),
               note("Баксик", 13), note("Баксик", 0)]
check("\(Score.of(twoRuns, rooms: plot, now: noon, calendar: clock).best)", "4",
      "самая длинная череда — из прошлого, не из сегодняшнего дня")

print("кого поливали чаще:")
check("\(score.plants.map(\.name))", "[\"Баксик\", \"Борис\", \"Мурзик\"]",
      "растения от большего к меньшему")
check("\(score.plants.map(\.count))", "[3, 3, 1]", "и с их числами")
check("\(score.rooms.map(\.name))", "[\"Спальня\", \"Кухня\"]",
      "комнаты тоже")
check("\(score.rooms.map(\.count))", "[6, 1]", "сумма по растениям комнаты")
let quiet = Score.of([note("Баксик", 0)], rooms: plot, now: noon, calendar: clock)
check("\(quiet.plants.count)", "1", "кого ни разу не полили, в списке нет")
check("\(quiet.rooms.count)", "1", "и пустых комнат тоже")

print("сад ведёт журнал:")
let plot2 = Garden()
let before = plot2.log.count
plot2.water("pr")
check("\(plot2.log.count - before)", "1", "полив добавил запись")
check(plot2.log.last!.plant, "pr", "и записал, кого")
check("\(plot2.score().total)", "\(plot2.log.count)", "статистика считает весь журнал")

print("сад принимает новые растения:")
let rooms0 = plot2.rooms.count
let bed0 = plot2.rooms[0].plants.count
plot2.add(Plant.new(name: "Ёжик", species: "Кактус", dryingDays: 30),
          to: plot2.rooms[0].name)
check("\(plot2.rooms[0].plants.count - bed0)", "1", "растение встало в комнату")
plot2.add(Plant.new(name: "Пыль", species: "Фикус", dryingDays: 7),
          to: "Кабинет")
check("\(plot2.rooms.count - rooms0)", "1", "незнакомая комната заводится сама")
check(plot2.rooms.last!.name, "Кабинет", "и с тем именем, что дали")
check(Plant.new(name: "А", species: "Б", dryingDays: 1).id
      != Plant.new(name: "А", species: "Б", dryingDays: 1).id,
      "у двух одинаковых с виду растений номера разные")

print("хозяин переименовывается:")
plot2.rename(owner: "  Тёма  ")
check(plot2.owner, "Тёма", "имя обрезается по краям")
plot2.rename(owner: "   ")
check(plot2.owner, "Тёма", "пустое не сохраняется")

print("сад, записанный прежней сборкой, читается:")
let old = """
{"owner":"Святослав","savedAt":760000000,"rooms":[{"name":"Спальня","plants":[
{"id":"x","name":"Икс","species":"Игрек","moisture":0.5,"dryingDays":7,
"addedOn":{"year":2024,"month":1,"day":1},"photo":"monstera"}]}]}
"""
let decoder = JSONDecoder()
if let revived = try? decoder.decode(GardenState.self,
                                     from: Data(old.utf8)) {
    check(revived.owner, "Святослав", "хозяин на месте")
    check("\(revived.rooms[0].plants.count)", "1", "растения на месте")
    check("\(revived.log.count)", "0", "журнала не было — он пуст, а не падение")
    check(revived.since == revived.savedAt, "дату сада берём от записи")
} else {
    check(false, "старый сад разобрался")
}

print("фронт перехода: очередь по узору:")
let canvas = CGSize(width: 400, height: 800)
func turn(_ front: Front, _ x: Double, _ y: Double) -> Double {
    front.turn(at: CGPoint(x: x, y: y), over: canvas)
}
let corner = Front.point(CGPoint(x: 0, y: 0))
check(round2(turn(corner, 0, 0)), "0.00", "из угла: сам угол идёт первым")
check(round2(turn(corner, 900, 0)), "1.00",
      "на мерке фронта — ровно единица")
check(round2(turn(corner, 2000, 0)), "1.00", "дальше мерки — всё та же")
// Мерка общая: круг из середины и из угла идут с одной скоростью.
let middle = Front.point(CGPoint(x: 200, y: 400))
check(round2(turn(middle, 200, 400)), "0.00", "из середины: середина первой")
check(round2(turn(middle, 200 + 450, 400)), "0.50",
      "полмерки в сторону — половина черёда")
check(round2(turn(corner, 450, 0)), "0.50",
      "и из угла ровно столько же: скорость одна")

// Обратная волна: дальние первыми, точка нажатия последней; мерка — до
// дальнего угла холста.
let inward = Front.collapse(CGPoint(x: 200, y: 400))
check(round2(turn(inward, 200, 400)), "1.00",
      "обратная: точка нажатия идёт последней — волна в неё садится")
check(round2(turn(inward, 0, 0)), "0.00",
      "а самый дальний угол холста — ровно первым, без задержки")
var late = 0
for spot in [CGPoint(x: 0, y: 0), CGPoint(x: 200, y: 400),
             CGPoint(x: 400, y: 800), CGPoint(x: 399, y: 1)] {
    let back = Front.collapse(spot)
    // У каждого холста есть фигурка, трогающаяся в ноль.
    var first = 1.0
    for x in stride(from: 0.0, through: 400, by: 10) {
        for y in stride(from: 0.0, through: 800, by: 10) {
            first = min(first, turn(back, x, y))
        }
    }
    if first > 1e-6 { late += 1 }
}
check("\(late)", "0", "откуда ни нажми, волна трогается сразу")

let up = Front.sweep(-Double.pi / 2)
check(turn(up, 200, 800) < turn(up, 200, 0),
      "полосой вверх: низ раньше верха — угол говорит, куда фронт идёт")
check(round2(turn(up, 200, 800)), "0.00", "дальняя кромка ровно на нуле")
check(round2(turn(up, 200, 0)), "1.00", "ближняя ровно на единице")

// Черёд всегда остаётся долей 0…1.
var outside = 0
for front in [corner, middle, inward, up,
              Front.point(CGPoint(x: -300, y: 900))] {
    for x in stride(from: -200.0, through: 600, by: 25) {
        for y in stride(from: -200.0, through: 1000, by: 25) {
            let value = turn(front, x, y)
            if value < 0 || value > 1 || value.isNaN { outside += 1 }
        }
    }
}
check("\(outside)", "0", "черёд нигде не выходит за 0…1, даже за краем холста")

print("кутерьма от тряски:")
func look(_ elapsed: Double, _ turn: Double) -> (Int, Double) {
    let seen = Frolic(elapsed: elapsed).look(turn: turn)
    return (seen.state, (seen.scale * 1000).rounded() / 1000)
}
check("\(look(0, 0).0)", "0", "в самом начале узор ещё обычный")
check("\(look(0, 0).1)", "1.0", "и в полный размер")
check("\(look(-1, 0).0)", "0", "до начала — тоже")
check("\(look(Frolic.beat, 1).0)", "0", "дальняя в этот миг ещё не тронулась")
check("\(look(Frolic.beat, 0).0)", "1", "а ближняя уже в первом беспорядке")
check(look(Frolic.beat * 0.5, 0).1 < 0.05,
      "к середине такта фигурка сжата почти в ноль")
check(look(Frolic.beat * 0.25, 0).1 > 0.8,
      "в первой четверти ещё почти целая — сквозь ноль она проскакивает")
check("\(look(Frolic.beat * 0.75, 0).0)", "1",
      "после нуля растёт уже следующим состоянием")

// Кончается тем же узором, с которого началась.
check("\(look(Frolic.seconds, 0).0)", "\(Frolic.beats)",
      "у ближней последнее состояние — обычный узор")
check("\(look(Frolic.seconds, 1).0)", "\(Frolic.beats)",
      "и у дальней тоже, она успевает")
check("\(look(Frolic.seconds, 1).1)", "1.0", "и в полный размер")
check(!Frolic.chaotic(0) && !Frolic.chaotic(Frolic.beats),
      "первое и последнее состояния — не беспорядок")
check(Frolic.chaotic(1) && Frolic.chaotic(Frolic.beats - 1),
      "а всё, что между ними, — беспорядок")

var wild = 0
for tick in stride(from: -0.5, through: Frolic.seconds + 1, by: 0.01) {
    for turn in stride(from: 0.0, through: 1.0, by: 0.05) {
        let seen = Frolic(elapsed: tick).look(turn: turn)
        if seen.scale < -1e-9 || seen.scale > 1 + 1e-9 || seen.scale.isNaN {
            wild += 1
        }
        if seen.state < 0 || seen.state > Frolic.beats { wild += 1 }
    }
}
check("\(wild)", "0", "размер и состояние нигде не выходят за свои границы")
check(Frolic.seconds > 4.5 && Frolic.seconds < 5.5,
      "вся кутерьма укладывается примерно в пять секунд")

print("что искали раньше:")
let searches = UserDefaults(suiteName: "check.recents")!
searches.removePersistentDomain(forName: "check.recents")
let recent = Recents(store: searches)
check("\(recent.queries.count)", "0", "на чистом месте искали ещё ничего")
recent.remember("Баксик")
recent.remember("Сумка")
check(recent.queries.joined(separator: ", "), "Сумка, Баксик",
      "свежий запрос идёт первым")
recent.remember("баксик")
check(recent.queries.joined(separator: ", "), "баксик, Сумка",
      "повтор не заводит второй строки, а всплывает наверх")
recent.remember("  Ко  ")
check(recent.queries.first ?? "—", "Ко", "пробелы по краям обрезаются")
recent.remember("к")
check(recent.queries.first ?? "—", "Ко", "запрос в одну букву не запоминается")
recent.remember("   ")
check(recent.queries.first ?? "—", "Ко", "и пустой тоже")
for name in ["Борис", "Тапок", "Шуба", "Соня", "Гоша"] { recent.remember(name) }
check("\(recent.queries.count)", "\(Recents.keep)",
      "список не растёт дальше отведённого")
check(recent.queries.first ?? "—", "Гоша", "и обрезается снизу, а не сверху")
check(Recents(store: searches).queries.count == Recents.keep,
      "список пережил перезапуск")
recent.forget("гоша")
check(recent.queries.contains { $0 == "Гоша" } == false,
      "забытый запрос уходит, и регистр ему не помеха")
recent.clear()
check("\(recent.queries.count)", "0", "и всё сразу тоже забывается")
searches.removePersistentDomain(forName: "check.recents")

print("отклик в руке:")
for (name, pulse) in Pulse.all {
    check(pulse.valid, "рисунок «\(name)» движок примет")
}

// Ряд тычков, а не ровный гул: рука должна слышать ряды фигурок.
let splash = Pulse.water
let drops = splash.taps(over: 2.4)
check(drops.count > 20, "за волну в руку уходит не один тычок, а десятки")
check(drops.allSatisfy { $0.strength >= Pulse.faintest && $0.strength <= 1 },
      "и все они в силах, которые движок покажет")
check(zip(drops, drops.dropFirst()).allSatisfy { $0.at < $1.at },
      "и идут по времени вперёд")
check(round2(drops[1].at - drops[0].at), round2(1 / splash.rate),
      "промежуток между тычками — обратная частота")
check(drops.allSatisfy { $0.at <= 2.4 + 1e-9 },
      "и ни один не выпадает за отведённое время")
check(round2(splash.rate), "13.00",
      "частота полива — сколько рядов узора волна поднимает за секунду")

// После горба сила только убывает.
var rising = 0
var peak = 0.0
for step in stride(from: 0.0, through: 1.0, by: 0.01) {
    let now = splash.strength(at: step)
    if step > 0.15, now > peak + 1e-9 { rising += 1 }
    peak = max(peak, now)
}
check("\(rising)", "0", "полив после горба только слабеет")
check(splash.strike > 0.8, "и начинается резким ударом")
check(splash.hum > 0 && splash.hum < 0.5,
      "под дробью тихая подложка, чтобы между тычками рука не пустовала")
check(round2(splash.strength(at: 0.195)), "0.70",
      "между точками огибающая идёт по прямой")

let rise = Pulse.sprout
let seeds = rise.taps(over: 1.1)
check(seeds.count > 8, "за всходы в руку уходит с десяток тычков")
check(rise.strength(at: 0.55) > rise.strength(at: 0),
      "всходы набирают силу к середине")
check(rise.strength(at: 1) < rise.strength(at: 0.55),
      "и садятся к концу")
check("\(rise.strike)", "0.0",
      "без удара в начале: всходы ничем не вызваны, вздрагивать не с чего")
check("\(rise.hum)", "0.0", "и без гула — в руке только дробь")
check(rise.finish > 0, "зато с мягким хлопком, когда узор встал")

let sprouting = Pulse.bloom
check(sprouting.strength(at: 1) > sprouting.strength(at: 0),
      "посадка набирает силу")
check(sprouting.finish > 0.9, "и кончается хлопком")

let romp = Pulse.frenzy
check("\(romp.envelope.count)", "\(Frolic.beats * 2 + 1)",
      "у кутерьмы по паре точек на такт и одна на хвост")
var bumps: [Double] = []
for beat in 0 ..< Frolic.beats {
    let middle = (Double(beat) + 0.4) / Double(Frolic.beats + 1)
    bumps.append(romp.strength(at: middle))
}
check(zip(bumps, bumps.dropFirst()).allSatisfy { $0 < $1 },
      "каждый следующий бугор сильнее прежнего")
check(round2(romp.strength(at: 1)), "0.00",
      "а под конец, когда узор садится на место, отклик стихает")
let firstBump = 0.4 / Double(Frolic.beats + 1) * Frolic.seconds
check(round2(firstBump), round2(Frolic.beat * 0.4),
      "первый бугор приходится на первый такт")

var outOfRange = 0
for (_, pulse) in Pulse.all {
    for step in stride(from: -0.5, through: 1.5, by: 0.01) {
        let value = pulse.strength(at: step)
        if value < 0 || value > 1 || value.isNaN { outOfRange += 1 }
    }
    for span in [0.2, 0.55, 1.1, 2.4, 5.0] {
        let row = pulse.taps(over: span)
        if row.contains(where: { $0.at < 0 || $0.at > span + 1e-9
            || $0.strength < 0 || $0.strength > 1 }) { outOfRange += 1 }
    }
}
check("\(outOfRange)", "0", "сила и время тычков нигде не выходят за края")
check(Pulse.water.taps(over: 0).isEmpty, "на нулевом времени тычков нет")

// Негодный рисунок проверка обязана отвергнуть.
func bad(_ pulse: Pulse) -> Bool { !pulse.valid }
check(bad(Pulse(rate: 13, envelope: [Moment(0, 0.5)])),
      "одна точка — не огибающая")
check(bad(Pulse(rate: 13, envelope: [Moment(0, 0.5), Moment(0.6, 0.2)])),
      "огибающая обязана дойти до конца")
check(bad(Pulse(rate: 13, envelope: [Moment(0.2, 0.5), Moment(1, 0.2)])),
      "и начаться в начале")
check(bad(Pulse(rate: 13, envelope: [Moment(0, 0.5), Moment(0.7, 0.2),
                                     Moment(0.3, 0.9), Moment(1, 0)])),
      "и идти только вперёд")
check(bad(Pulse(rate: 13, strike: 1.4,
                envelope: [Moment(0, 0.5), Moment(1, 0)])),
      "сила больше единицы движку не годится")
check(bad(Pulse(rate: 13, envelope: [Moment(0, -0.2), Moment(1, 0)])),
      "и отрицательная тоже")
check(bad(Pulse(rate: 0, envelope: [Moment(0, 0.5), Moment(1, 0)])),
      "ряд без частоты — не ряд")
check(bad(Pulse(rate: 200, envelope: [Moment(0, 0.5), Moment(1, 0)])),
      "а двести тычков в секунду — уже не тычки")

print("кадр из снимка:")
let wide = CGSize(width: 4000, height: 3000)
let tall = CGSize(width: 3000, height: 4000)
let pane = 350.0

let centred = Crop.of(image: wide, window: pane, scale: 1, offset: .zero)
check(round2(centred.side), "3000.00", "из широкого берётся квадрат по высоте")
check(round2(centred.x), "500.00", "и стоит он ровно посередине")
check(round2(centred.y), "0.00", "по высоте резать нечего")
let upright = Crop.of(image: tall, window: pane, scale: 1, offset: .zero)
check(round2(upright.side), "3000.00", "из высокого — по ширине")
check(round2(upright.y), "500.00", "и тоже посередине")

let closer = Crop.of(image: wide, window: pane, scale: 2, offset: .zero)
check(round2(closer.side), "1500.00", "вдвое ближе — вдвое меньше кадр")
check(round2(closer.x), "1250.00", "и он всё так же посередине")

// Сдвиг двигает кадр в обратную сторону: тянут сам снимок.
let moved = Crop.of(image: wide, window: pane, scale: 1,
                    offset: CGSize(width: 100, height: 0))
check(moved.x < centred.x, "потянули снимок вправо — кадр ушёл влево")

let shoved = Crop.of(image: wide, window: pane, scale: 1,
                     offset: CGSize(width: 99_999, height: 99_999))
check(round2(shoved.x), "0.00", "как ни тяни, кадр упирается в край снимка")
check(shoved.inside(wide), "и остаётся внутри")
let pinned = Crop.of(image: tall, window: pane, scale: 1,
                     offset: CGSize(width: 0, height: -99_999))
check(round2(pinned.y + pinned.side), "4000.00", "с другой стороны — тоже")

check(round2(Crop.slack(image: wide, window: pane, scale: 1).height), "0.00",
      "у широкого снимка по высоте люфта нет")
check(Crop.slack(image: wide, window: pane, scale: 1).width > 0,
      "а по ширине есть")
check(Crop.slack(image: wide, window: pane, scale: 2).height > 0,
      "стоит увеличить — появляется и по высоте")

// Кадр всегда внутри снимка и квадратный.
var escaped = 0
for size in [wide, tall, CGSize(width: 1200, height: 1200),
             CGSize(width: 800, height: 60)] {
    for zoom in [0.2, 1.0, 1.7, 4.0, 9.0] {
        for dx in stride(from: -900.0, through: 900, by: 75) {
            for dy in stride(from: -900.0, through: 900, by: 75) {
                let crop = Crop.of(image: size, window: pane, scale: zoom,
                                   offset: CGSize(width: dx, height: dy))
                if !crop.inside(size) || crop.side <= 0 || crop.side.isNaN {
                    escaped += 1
                }
            }
        }
    }
}
check("\(escaped)", "0", "кадр нигде не вылезает за снимок")

// Меньше единицы снимок не закрыл бы окно, больше предела — рассыпался бы.
let tooFar = Crop.of(image: wide, window: pane, scale: 0.1, offset: .zero)
check(round2(tooFar.side), "3000.00", "уменьшить меньше «враспор» нельзя")
let tooClose = Crop.of(image: wide, window: pane, scale: 99, offset: .zero)
let deepest = Crop.of(image: wide, window: pane, scale: Crop.deepest,
                      offset: .zero)
check(round2(tooClose.side), round2(deepest.side),
      "и приблизить дальше предела тоже")

print("как приложение здоровается:")
check(Seed.greeting(for: "Святослав"), "Добро пожаловать, Святослав!",
      "назвавшегося встречаем по имени")
check(Seed.greeting(for: ""), "Добро пожаловать!",
      "а неназвавшегося — просто так, без хвоста из запятой")
check(Seed.greeting(for: "   "), "Добро пожаловать!",
      "пробелы именем не считаются")
check(Seed.greeting(for: "  Аня  "), "Добро пожаловать, Аня!",
      "а по краям обрезаются")
check(Seed.owner.isEmpty,
      "у нового сада имени нет: макетное «Святослав» встречало бы всех")

let nameless = Garden()
check(nameless.owner.isEmpty, "сад заводится безымянным")
check(nameless.signed, Seed.stranger, "но подписаться ему есть чем")
// Код с пустым именем обратно не разберётся.
let anon = Rival.mine(owner: nameless.signed, score: Score(), plants: 0)
check(Rival.read(anon.code)?.name ?? "—", Seed.stranger,
      "код неназвавшегося разбирается обратно")
let broken = Rival.mine(owner: "", score: Score(), plants: 0)
check(Rival.read(broken.code) == nil,
      "а с пустым именем — нет, потому подпись и нужна")

print("срок напоминания:")
func delay(_ moisture: Double, _ dryingDays: Double = 7,
           _ threshold: Double = 0.2) -> String {
    guard let seconds = Reminder.delay(
        for: plant(moisture: moisture, dryingDays: dryingDays),
        threshold: threshold)
    else { return "никогда" }
    return round2(seconds)
}
// Час сада за секунду: 0.3 от семи суток — 2.1 суток сада, то есть 50.4
// секунды.
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

print("код соперника:")
let mine = Rival(name: "Святослав", total: 142, streak: 5, best: 9,
                 plants: 27, day: 20_350)
check(mine.code.hasPrefix(Rival.mark), "код начинается меткой с версией")
check(!mine.code.contains("+") && !mine.code.contains("/")
      && !mine.code.contains("="),
      "в коде нет знаков, которые портит переписка")
let back = Rival.read(mine.code)
check(back?.name ?? "—", "Святослав", "кличка вернулась целой")
check("\(back?.total ?? -1)", "142", "и счёт тоже")
check("\(back?.streak ?? -1)", "5", "и череда")
check("\(back?.best ?? -1)", "9", "и лучшая череда")
check("\(back?.plants ?? -1)", "27", "и число растений")
check("\(back?.day ?? -1)", "20350", "и день, которым помечен счёт")

check(Rival.read(mine.card)?.name ?? "—", "Святослав",
      "код находится внутри всего сообщения")
check(Rival.read("Привет! \(mine.code). До связи")?.total ?? -1 == 142,
      "точка после кода в код не входит")
check(Rival.read("совсем не то") == nil, "в тексте без кода кода и нет")
check(Rival.read("\(Rival.mark)не-код") == nil, "битый код не разбирается")
check(mine.card.contains("142 полива"),
      "в человеческой части счёт склонён по числу")

print("таблица соперников:")
let box = UserDefaults(suiteName: "check.rivals")!
box.removePersistentDomain(forName: "check.rivals")
let table = Friends(store: box)
check("\(table.rivals.count)", "0", "пустая таблица на чистом месте")
table.add(Rival(name: "Аня", total: 10, streak: 1, best: 1, plants: 2,
                day: 20_350))
table.add(Rival(name: "Боря", total: 30, streak: 2, best: 4, plants: 5,
                day: 20_350))
check(table.rivals.map(\.name).joined(separator: ", "), "Боря, Аня",
      "порядок — от большего счёта к меньшему")
table.add(Rival(name: "аня", total: 99, streak: 3, best: 3, plants: 2,
                day: 20_351))
check("\(table.rivals.count)", "2", "тот же друг не заводит второй строки")
check(table.rivals.first?.name ?? "—", "аня", "новый счёт встал выше")
check(Friends(store: box).rivals.count == 2, "таблица пережила перезапуск")
check(table.take(mine.card, mine: "святослав") == nil,
      "свой собственный код в соперники не берётся")
check(table.take("тут кода нет", mine: "Аня") == nil,
      "и текст без кода тоже")
check(table.take(mine.card, mine: "Аня")?.name ?? "—", "Святослав",
      "а чужой — берётся")
table.remove("аня")
check(table.rivals.map(\.name).joined(separator: ", "), "Святослав, Боря",
      "убранный соперник уходит из таблицы")
box.removePersistentDomain(forName: "check.rivals")

print("что разглядел телефон:")
func guessed(_ seen: [(String, Double)]) -> String {
    Species.read(seen.map { Sighting(name: $0.0, confidence: $0.1) })?
        .species ?? "—"
}
check(guessed([("plant", 0.91), ("houseplant", 0.44), ("cactus", 0.21)]),
      "Кактус", "частное слово важнее уверенного общего")
check(guessed([("plant", 0.91), ("houseplant", 0.44)]),
      "Комнатное растение", "без частного берётся общее")
check(guessed([("flowering_plant", 0.5)]), "Цветок",
      "слово ищется внутри ярлыка, а не целиком")
check(guessed([("rosemary", 0.5)]), "Розмарин",
      "розмарин не путается с розой")
check(guessed([("tree_fern", 0.5)]), "Папоротник",
      "древовидный папоротник — папоротник")
check(guessed([("cactus", 0.01), ("plant", 0.9)]), "Комнатное растение",
      "слишком слабый ярлык в расчёт не идёт")
check(guessed([("dog", 0.9), ("sofa", 0.4)]), "—",
      "на снимке без растения вида нет")
check(guessed([]), "—", "и на пустом ответе тоже")
let prickly = Species.read([Sighting(name: "cactus", confidence: 0.3)])
check("\(prickly?.dryingDays ?? 0)", "30.0",
      "кактусу подставляется месяц, а не неделя")

print("сроки полива:")
check("\(Species.period(near: 30))", "30.0", "точное совпадение")
check("\(Species.period(near: 8))", "7.0", "восемь суток округляются к семи")
check("\(Species.period(near: 9))", "10.0", "девять — к десяти")
check("\(Species.period(near: 200))", "60.0", "запредельное упирается в потолок")
check(Species.periodLabel(1), "Раз в 1 день", "1 день")
check(Species.periodLabel(3), "Раз в 3 дня", "3 дня")
check(Species.periodLabel(7), "Раз в 7 дней", "7 дней")
check(Species.periodLabel(21), "Раз в 21 день", "21 день")

// Слово, внутри которого есть другое слово словаря, должно стоять выше него:
// «rose» выше «rosemary» — и розмарин навсегда роза.
print("порядок словаря видов:")
var shadowed: [String] = []
for (i, entry) in Species.table.enumerated() {
    for later in Species.table[(i + 1)...]
    where later.word.contains(entry.word) {
        shadowed.append("«\(later.word)» не достижимо из-за «\(entry.word)»")
    }
}
check(shadowed.isEmpty,
      "до каждого слова доходит очередь: \(shadowed)")

print("фигурки плывут в вязкой среде:")

check(Sway.layer(column: 3, row: 5, slot: 1, era: 2)
        == Sway.layer(column: 3, row: 5, slot: 1, era: 2),
      "внутри захода слой у фигурки один и тот же")

var swayByLayer = [Int](repeating: 0, count: Sway.eases.count)
var swayMoved = 0, swayCells = 0
for column in 0..<40 {
    for row in 0..<40 {
        for slot in 0..<2 {
            let here = Sway.layer(column: column, row: row, slot: slot, era: 0)
            swayByLayer[here] += 1
            if Sway.layer(column: column, row: row, slot: slot, era: 1) != here {
                swayMoved += 1
            }
            swayCells += 1
        }
    }
}
check(swayByLayer.allSatisfy { $0 > 0 }, "все слои кому-то достались: \(swayByLayer)")
let swayEvenly = swayByLayer.allSatisfy {
    abs(Double($0) / Double(swayCells) - 0.2) < 0.03
}
check(swayEvenly, "и достались поровну: \(swayByLayer.map { round2(Double($0) * 100 / Double(swayCells)) })")
check(Double(swayMoved) / Double(swayCells) > 0.6,
      "со сменой захода плывут другие: сменили слой "
      + "\(round2(Double(swayMoved) * 100 / Double(swayCells)))%")

// Качок: цель разгоняется полсекунды, дальше телефон держат ровно.
var swayCommon = CGSize.zero
var swayPlaces = Sway.rest(at: .zero)
var swayPeak = [Double](repeating: 0, count: Sway.eases.count)
var swayPeakFrame = [Int](repeating: 0, count: Sway.eases.count)
var swayAfter = 0.0
var swayLate = 0.0
let swayRamp = 30, swayHold = 90
for swayFrame in 0..<(swayRamp + swayHold) {
    let swayGoal = CGFloat(min(Double(swayFrame) / Double(swayRamp), 1) * 14)
    let swayTarget = CGSize(width: swayGoal, height: swayGoal)
    swayCommon = CGSize(width: swayCommon.width + (swayTarget.width - swayCommon.width) * 0.12,
                    height: swayCommon.height + (swayTarget.height - swayCommon.height) * 0.12)
    swayPlaces = Sway.settle(swayPlaces, toward: swayTarget)
    let swayStep = Sway.lag(swayPlaces, behind: swayCommon)
    for (i, value) in swayStep.enumerated() {
        let size = abs(Double(value.width))
        if size > swayPeak[i] { swayPeak[i] = size; swayPeakFrame[i] = swayFrame }
    }
    if swayFrame == swayRamp + 45 {
        swayAfter = swayStep.map { abs(Double($0.width)) }.max() ?? 0
    }
    if swayFrame == swayRamp + 90 {
        swayLate = swayStep.map { abs(Double($0.width)) }.max() ?? 0
    }
}
check(swayPeak[2] < 0.001,
      "слой вровень с узором никуда не уезжает: \(round2(swayPeak[2])) pt")
check(swayPeak[0] > 1.0 && swayPeak[4] > 2.5,
      "лёгкий уходит вперёд, тяжёлый отстаёт: "
      + "\(round2(swayPeak[0])) и \(round2(swayPeak[4])) pt")
check(swayPeak.allSatisfy { $0 <= Double(Sway.limit) + 0.001 },
      "и никто не выходит за упор в \(Int(Sway.limit)) pt")
check(swayPeakFrame[4] >= swayRamp - 6,
      "тяжёлый расходится сильнее всего на исходе наклона, а не в начале: "
      + "кадр \(swayPeakFrame[4]) из \(swayRamp)")
// Доплывание: у тяжёлого слоя постоянная ~22 кадра — через ¾ секунды ещё
// около пункта, через полторы почти ноль.
check(swayAfter > 0.3 && swayAfter < 1.5,
      "через три четверти секунды после наклона фигурки ещё плывут: "
      + "\(round2(swayAfter)) pt")
check(swayLate < 0.3,
      "а через полторы — уже сошлись: \(round2(swayLate)) pt")

let swayStill = Sway.lag(Sway.rest(at: CGSize(width: 9, height: -4)),
                     behind: CGSize(width: 9, height: -4))
check(swayStill.allSatisfy { $0.width == 0 && $0.height == 0 },
      "стоячий узор — ровная сетка")

print("убрать и вернуть:")
do {
    let yard = Garden()
    yard.rooms = Seed.rooms
    let roster = yard.roster
    let bedroom = yard.rooms[0].plants.map(\.id)
    let gone = yard.remove("tapok")!
    check(gone.room == "Спальня" && gone.index == 2 && gone.roomIndex == 0,
          "запомнилось, откуда взяли")
    check(yard.plant(id: "tapok") == nil, "убранного в саду нет")
    check(yard.roster > roster, "состав сада сменился — Siri узнает")
    yard.putBack(gone)
    check(yard.rooms[0].plants.map(\.id) == bedroom,
          "вернулось ровно на своё место")
    yard.putBack(gone)
    check(yard.rooms[0].plants.filter { $0.id == "tapok" }.count == 1,
          "второй раз не встаёт")
    let lone = yard.remove("murzik")!
    yard.deleteRoom("Кухня")
    yard.putBack(lone)
    check(yard.rooms.map(\.name) == ["Спальня", "Гостиная", "Кухня"],
          "комнату удалили, пока шёл отсчёт, — она заводится там, где стояла")
    check(yard.rooms[2].plants.map(\.id) == ["murzik"],
          "и в ней — вернувшееся растение")
    check(yard.remove("никого-нет") == nil, "чужой номер убрать нельзя")
}

print("комнаты:")
do {
    let yard = Garden()
    yard.rooms = Seed.rooms
    check(yard.addRoom("  Балкон "), "новая комната заводится")
    check(yard.rooms.last?.name == "Балкон"
          && yard.rooms.last?.plants.isEmpty == true,
          "пустой и с обрезанным именем")
    check(!yard.addRoom("балкон"), "занятое имя не годится — без оглядки на регистр")
    check(!yard.addRoom("   "), "пустое тоже")
    check(yard.renameRoom("Балкон", to: "Лоджия"), "переименовать можно")
    check(!yard.renameRoom("Лоджия", to: "кухня"), "в чужое имя — нельзя")
    check(yard.renameRoom("Лоджия", to: "Лоджия"), "своё имя заново — не ошибка")
    check(!yard.renameRoom("Лоджия", to: " "), "в пустое — нельзя")
    check(!yard.renameRoom("Чулан", to: "Кладовка"), "несуществующую — тоже")
    yard.moveRooms(from: IndexSet(integer: 3), to: 0)
    check(yard.rooms.map(\.name) == ["Лоджия", "Спальня", "Гостиная", "Кухня"],
          "последняя встала первой")
    yard.moveRooms(from: IndexSet(integer: 0), to: 4)
    check(yard.rooms.map(\.name) == ["Спальня", "Гостиная", "Кухня", "Лоджия"],
          "и обратно в конец — как в списке iOS")
    yard.moveRooms(from: IndexSet([0, 2]), to: 4)
    check(yard.rooms.map(\.name) == ["Гостиная", "Лоджия", "Спальня", "Кухня"],
          "две разом — в том же порядке, в каком стояли")
    yard.relocate("baksik", to: "Лоджия")
    check(yard.roomName(of: "baksik") == "Лоджия"
          && yard.rooms[1].plants.map(\.id) == ["baksik"],
          "переехал — в новую комнату")
    let before = yard.rooms.map { $0.plants.map(\.id) }
    yard.relocate("baksik", to: "Лоджия")
    check(yard.rooms.map { $0.plants.map(\.id) } == before,
          "в свою же комнату — ничего не меняется")
    yard.relocate("pr", to: "Чердак")
    check(yard.rooms.last?.name == "Чердак"
          && yard.rooms.last?.plants.map(\.id) == ["pr"],
          "в новую — комната заводится")
    let count = yard.plantCount
    yard.deleteRoom("Кухня")
    check(!yard.rooms.contains { $0.name == "Кухня" }
          && yard.plantCount == count - 11,
          "удалённая комната уносит свои растения")
}

print("порядок растений:")
do {
    let bedroom = Seed.rooms[0].plants
    check(Settings.Order.manual.arrange(bedroom).map(\.id) == bedroom.map(\.id),
          "вручную — как расставили")
    check(Settings.Order.thirsty.arrange(bedroom).map(\.id)
          == ["boris", "pr", "kompot", "vasilisa", "shuba", "tapok",
              "shnurok", "baksik"],
          "сначала сухие — по сроку полива, а не по процентам")
    check(Settings.Order.name.arrange(bedroom).map(\.name)
          == ["Баксик", "Борис", "Василиса", "Компот", "Пр", "Тапок",
              "Шнурок", "Шуба"],
          "по имени — по алфавиту")
    check(Settings.Order.newest.arrange(bedroom).map(\.id)
          == ["shuba", "kompot", "tapok", "vasilisa", "pr", "shnurok",
              "baksik", "boris"],
          "сначала новые — по дню посадки")
    let day = DateComponents(year: 2025, month: 1, day: 1)
    let twins = [
        Plant(id: "a", name: "Б", species: "", moisture: 0.5,
              dryingDays: 4, addedOn: day),
        Plant(id: "b", name: "А", species: "", moisture: 0.25,
              dryingDays: 8, addedOn: day),
    ]
    check(Settings.Order.thirsty.arrange(twins).map(\.id) == ["a", "b"],
          "равные сроки остаются, как стояли вручную")
    check(Settings.Order.newest.arrange(twins).map(\.id) == ["a", "b"],
          "и равные дни посадки тоже")
    check(Settings.Order.name.arrange(twins).map(\.id) == ["b", "a"],
          "а по имени — всё-таки по имени")
}

print("журнал растения:")
do {
    var moscow = Calendar(identifier: .gregorian)
    moscow.timeZone = TimeZone(identifier: "Europe/Moscow")!
    func at(_ day: Int, _ hour: Int, _ minute: Int,
            month: Int = 9, year: Int = 2026) -> Date {
        moscow.date(from: DateComponents(year: year, month: month, day: day,
                                         hour: hour, minute: minute))!
    }
    let now = at(23, 15, 30)
    check(Diary.label(at(23, 14, 5), now: now, calendar: moscow),
          "Сегодня, 14:05", "сегодня")
    check(Diary.label(at(22, 9, 12), now: now, calendar: moscow),
          "Вчера, 9:12", "вчера — и часы без нуля впереди")
    check(Diary.label(at(22, 0, 0), now: now, calendar: moscow),
          "Вчера, 0:00", "полночь")
    check(Diary.label(at(20, 18, 40), now: now, calendar: moscow),
          "20 сентября, 18:40", "в этом году — без года")
    check(Diary.label(at(2, 7, 0, month: 11, year: 2025), now: now,
                      calendar: moscow),
          "2 ноября 2025, 7:00", "в прошлом году — с годом")
    let log = [
        Watering(plant: "x", when: at(20, 12, 0)),
        Watering(plant: "y", when: at(21, 12, 0)),
        Watering(plant: "x", when: at(23, 12, 0)),
        Watering(plant: "x", when: at(22, 0, 0)),
    ]
    let diary = Diary.of(log, plant: "x")
    check(diary.entries == [at(23, 12, 0), at(22, 0, 0), at(20, 12, 0)],
          "только его поливы, от свежего к давнему")
    check(diary.total == 3, "всего три")
    check(diary.average == 1.5 * 86_400, "в среднем — раз в полтора дня")
    check(Diary.of(log, plant: "y").average == nil,
          "из одного полива среднего не посчитать")
    check(Diary.rhythm(30), "чаще раза в минуту", "совсем часто")
    check(Diary.rhythm(60), "раз в минуту", "минута")
    check(Diary.rhythm(20 * 60), "раз в 20 мин", "минуты")
    check(Diary.rhythm(3_600), "раз в час", "час")
    check(Diary.rhythm(5 * 3_600), "раз в 5 ч", "часы")
    check(Diary.rhythm(1.2 * 86_400), "раз в день", "день")
    check(Diary.rhythm(1.5 * 86_400), "раз в 2 дня", "полтора дня — уже два")
    check(Diary.rhythm(5 * 86_400), "раз в 5 дней", "дни")
}

print("кого полить сегодня:")
do {
    let due = Seed.due(in: Seed.rooms)
    check(due.map(\.id) == ["sumka", "kefir", "boris"],
          "те, у кого на карточке «сегодня», — от самого сухого")
    check(Seed.dueLine(due), "Сегодня ждут воды Сумка, Кефир и Борис.",
          "три имени")
    check(Seed.dueLine(Array(due.prefix(2))), "Сегодня ждут воды Сумка и Кефир.",
          "два имени")
    check(Seed.dueLine(Array(due.prefix(1))), "Сегодня ждёт воды Сумка.",
          "одно — и глагол в единственном")
    check(Seed.dueLine([]), "Сегодня поливать никого не нужно.", "никого")
    check(Seed.dueLine(Array(Seed.rooms[0].plants.prefix(7))),
          "Сегодня ждут воды Баксик, Пр, Тапок, Борис и ещё 3 растения.",
          "больше пяти — остальные числом")
}

print("растение по сказанному:")
do {
    func heard(_ phrase: String) -> [String] {
        Seed.spoken(phrase, in: Seed.rooms).map(\.id)
    }
    check(heard("Баксика") == ["baksik", "baksik-2"],
          "«Баксика» — оба Баксика, выбирать спросит Siri")
    check(heard("Василису") == ["vasilisa"], "«Василису»")
    check(heard("Соню") == ["sonya"], "«Соню»")
    check(heard("Петровича") == ["petrovich"], "«Петровича»")
    check(heard("полей грушу") == ["grusha"], "кличка внутри фразы")
    check(heard("Пр") == ["pr"], "короткая кличка — как есть")
    check(heard("снег") == ["sneg"], "несклоняемое — тоже")
    check(heard("").isEmpty && heard("   ").isEmpty, "пустое — никого")
}

if failed > 0 {
    print("\nне сошлось: \(failed)")
    exit(1)
}
print("\nвсё сошлось")
