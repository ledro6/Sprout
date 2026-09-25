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

/// Каталог строк — так, как его прочитал бы телефон: без него русские
/// формы числа («1 день», «2 дня») не проверить. Формы выбираются по CLDR —
/// здесь только для языков, которые проверяются.
struct Catalog {
    let strings: [String: [String: Any]]

    init(_ path: String) {
        let data = (try? Data(contentsOf: URL(fileURLWithPath: path))) ?? Data()
        let json = (try? JSONSerialization.jsonObject(with: data))
            as? [String: Any]
        strings = json?["strings"] as? [String: [String: Any]] ?? [:]
    }

    static func form(_ lang: String, _ n: Int) -> String {
        switch lang {
        case "ru", "uk":
            if n % 10 == 1 && n % 100 != 11 { return "one" }
            if (2 ... 4).contains(n % 10) && !(12 ... 14).contains(n % 100) {
                return "few"
            }
            return "many"
        case "pl":
            if n == 1 { return "one" }
            if (2 ... 4).contains(n % 10) && !(12 ... 14).contains(n % 100) {
                return "few"
            }
            return "many"
        case "cs", "sk":
            if n == 1 { return "one" }
            return (2 ... 4).contains(n) ? "few" : "other"
        case "ar":
            switch n % 100 {
            case _ where n == 0: return "zero"
            case _ where n == 1: return "one"
            case _ where n == 2: return "two"
            case 3 ... 10: return "few"
            case 11 ... 99: return "many"
            default: return "other"
            }
        case "ja", "zh-Hans", "zh-Hant", "ko", "th", "vi", "id", "ms":
            return "other"
        default:
            return n == 1 ? "one" : "other"
        }
    }

    func resolve(_ key: String, _ values: [Lang.Value], lang: String) -> String {
        let local = (strings[key]?["localizations"] as? [String: Any])?[lang]
            as? [String: Any]
        var pattern = key
        if let unit = local?["stringUnit"] as? [String: Any],
           let value = unit["value"] as? String {
            pattern = value
        } else if let plural = (local?["variations"] as? [String: Any])?["plural"]
                    as? [String: Any] {
            let number = values.lazy.compactMap { value -> Int? in
                if case .whole(let n) = value { return n }
                return nil
            }.first ?? 0
            let pick = plural[Catalog.form(lang, number)] ?? plural["other"]
            if let unit = (pick as? [String: Any])?["stringUnit"] as? [String: Any],
               let value = unit["value"] as? String {
                pattern = value
            }
        }
        return Lang.fill(pattern, values)
    }
}

let catalog = Catalog("ios-native/Sprout/Localizable.xcstrings")
check(!catalog.strings.isEmpty, "каталог строк прочитан")
var language = "ru"
Lang.locale = Locale(identifier: "ru")
Lang.resolve = { catalog.resolve($0, $1, lang: language) }

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
check(bedroom.plants[0].addedLabel, "Добавлен 02.11.2024", "дата добавления")
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
// Ровно сутки сада — сколько бы ни длились они на часах.
garden.advance(to: start)
garden.advance(to: start.addingTimeInterval(86_400 / Garden.speed))
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
let seen = Array(lineup(0).reversed())
garden.line(seen)
check(lineup(0) == seen, "порядок с экрана становится ручным")
garden.line([seen[2], seen[0]])
check(lineup(0) == [seen[2], seen[0], seen[1]] + seen[3...],
      "неназванные встают в хвост, как стояли")
garden.line(["никого-нет"])
check(lineup(0) == [seen[2], seen[0], seen[1]] + seen[3...],
      "чужой номер порядок не трогает")
garden.line(Array(lineup(0).reversed()))
garden.line(seen)
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
            "hushedHaptics", "hapticStrength", "stillPattern", "stiffShapes",
            "plantLook", "plantOrder", "mutedSounds", "toured",
            "walkedScreens", "launches", "avatarShot", "plainPattern"]
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
check(round2(fresh.hapticStrength), "1.00", "и на полную силу")
check(fresh.sounds, "звуки по умолчанию включены")
check(fresh.parallax, "узор по умолчанию едет за наклоном")
check(fresh.sway, "и фигурки по умолчанию расходятся")
check(round2(fresh.threshold), "0.20", "порог по умолчанию — двадцать процентов")
check(fresh.toured == false, "знакомство по умолчанию ещё не показано")
check(!fresh.seen(.stats), "подсказки экранов по умолчанию не показаны")
check(fresh.avatarShot == nil, "фото хозяина по умолчанию нет — кружок с буквой")
check(fresh.seasonalPattern, "узор по времени года по умолчанию включён")
fresh.seasonalPattern = false
check(!Settings(store: store).seasonalPattern, "выключенный узор времени года записан")
fresh.seasonalPattern = true
fresh.launched()
check(fresh.firstRun, "первый запуск — первый")
check(Settings(store: store).launches == 1, "счётчик запусков записан")
let second = Settings(store: store)
second.launched()
check(!second.firstRun, "второй запуск — уже не первый")
store.removeObject(forKey: "launches")
store.set(true, forKey: "toured")
let veteran = Settings(store: store)
veteran.launched()
check(!veteran.firstRun,
      "сад с прошлых сборок: знакомство было — и запуск уже не первый")
store.removeObject(forKey: "toured")
store.removeObject(forKey: "launches")

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
fresh.threshold = 0.37
fresh.patternTint = .rose
fresh.waveTint = .amber
fresh.toured = true
fresh.avatarShot = "me.jpg"
fresh.mark(.stats)
fresh.mark(.plant)
let reopened = Settings(store: store)
check("\(reopened.theme)", "dark", "тема прочиталась обратно")
check("\(reopened.look)", "list", "и вид списком")
check("\(reopened.order)", "thirsty", "и порядок «сначала сухие»")
check("\(reopened.chosen)", "[2, 3]", "и набор фигурок")
check(reopened.reminders, "и переключатель напоминаний")
check(round2(reopened.threshold), "0.37", "и порог — любым процентом")
check("\(reopened.patternTint)", "rose", "и цвет узора")
check("\(reopened.waveTint)", "amber", "и цвет волны")
check(reopened.toured, "и то, что знакомство уже было")
check(reopened.avatarShot == "me.jpg", "и фото хозяина")
check(reopened.seen(.stats) && reopened.seen(.plant) && !reopened.seen(.add),
      "и какие подсказки уже показаны")
reopened.rewalk()
check(!Settings(store: store).seen(.stats), "«показать снова» забывает все")
fresh.parallax = false
fresh.sway = false
fresh.sounds = false
let stilled = Settings(store: store)
check(stilled.parallax == false, "выключенный параллакс прочитался обратно")
check(stilled.sway == false, "и выключенный разъезд")
check(stilled.sounds == false, "и выключенные звуки")
fresh.parallax = true
fresh.sway = true
fresh.sounds = true
check(Settings(store: store).parallax, "и включённый обратно тоже")
fresh.hapticStrength = 0.35
check(round2(Settings(store: store).hapticStrength), "0.35",
      "сила отклика прочиталась обратно")
fresh.hapticStrength = 0
check(Settings(store: store).haptics == false, "ноль — отклика нет")
store.removeObject(forKey: "hapticStrength")
store.set(true, forKey: "hushedHaptics")
check(round2(Settings(store: store).hapticStrength), "0.00",
      "выключенный прежним переключателем отклик не включается сам")
store.removeObject(forKey: "hushedHaptics")
check(round2(Settings(store: store).hapticStrength), "1.00",
      "без обеих настроек — полная сила")
store.set(3.5, forKey: "hapticStrength")
check(round2(Settings(store: store).hapticStrength), "1.00",
      "сила из файла не выходит за единицу")
store.removeObject(forKey: "hapticStrength")

print("оттенки:")
check("\(Tint.allCases.count)", "11", "одиннадцать оттенков на выбор")
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

// Полив — капли: удар и россыпь тычков, каждый раз новая.
let drops = Rain.drops(over: 2.4, seed: 7)
check(drops.count > 15 && drops.count < 60,
      "за волну в руку уходит не один тычок, а десятки (\(drops.count))")
check(drops.first?.at == 0 && (drops.first?.strength ?? 0) >= 0.85,
      "начинается сильным ударом")
check(drops.allSatisfy { $0.strength >= Pulse.faintest && $0.strength <= 1
    && $0.edge >= 0 && $0.edge <= 1 },
      "все капли в силах и резкости, которые движок покажет")
check(zip(drops, drops.dropFirst()).allSatisfy {
    $1.at - $0.at >= Rain.closest - 1e-9 },
      "идут по времени вперёд и не сливаются")
check(drops.allSatisfy { $0.at <= 2.4 + 1e-9 },
      "и ни одна не выпадает за отведённое время")
check(Rain.drops(over: 2.4, seed: 7) == drops,
      "то же зерно — тот же рисунок: его можно проверить")
var alike = 0
for seed in 1 ... 20 as ClosedRange<UInt64> {
    let other = Rain.drops(over: 2.4, seed: seed &* 7919)
    if other.map(\.at) == drops.map(\.at) { alike += 1 }
}
check("\(alike)", "0", "а другое зерно — другие капли: полив всегда разный")
let gaps = zip(drops, drops.dropFirst()).map { $1.at - $0.at }
let meanGap = gaps.reduce(0, +) / Double(gaps.count)
let spreadGap = sqrt(gaps.map { ($0 - meanGap) * ($0 - meanGap) }
    .reduce(0, +) / Double(gaps.count))
check(spreadGap / meanGap > 0.25, "промежутки неровные — это капли, а не дробь")
check(Set(drops.map { Int($0.edge * 10) }).count >= 5,
      "и резкость у капель разная")
func meanForce(_ taps: [Tap]) -> Double {
    taps.map(\.strength).reduce(0, +) / Double(max(taps.count, 1))
}
let earlyDrops = drops.filter { $0.at > 0 && $0.at < 0.8 }
let lateDrops = drops.filter { $0.at > 1.6 }
check(meanForce(earlyDrops) > meanForce(lateDrops) * 1.5,
      "к концу волны капли слабеют")
check(Rain.drops(over: 0, seed: 1).isEmpty, "на нулевом времени капель нет")

for (name, taps) in Knock.all {
    check(!taps.isEmpty && taps.first?.at == 0
          && zip(taps, taps.dropFirst()).allSatisfy { $0.at < $1.at }
          && taps.allSatisfy { $0.strength > 0 && $0.strength <= 1
              && $0.edge >= 0 && $0.edge <= 1 },
          "короткий отклик «\(name)» движок примет")
}
check(Knock.done.last!.strength > Knock.done.first!.strength,
      "«готово» — слабый и сильный, как системный успех")

print("сила отклика:")
check(round2(Pulse.scaled(0.8, by: 0)), "0.00", "на нуле отклика нет")
check(stride(from: 0.05, through: 1, by: 0.05).allSatisfy {
    Pulse.scaled($0, by: 1) >= $0 },
      "на полной силе каждый тычок не слабее задуманного")
check(Pulse.scaled(0.3, by: 1) - 0.3 > Pulse.scaled(0.9, by: 1) - 0.9,
      "слабые подтягиваются сильнее сильных")
check(Pulse.scaled(0.5, by: 0.4) < Pulse.scaled(0.5, by: 0.8),
      "ползунок больше — отклик сильнее")
check(Pulse.scaled(1, by: 1) <= 1 && Pulse.scaled(3, by: 7) <= 1
      && Pulse.scaled(-1, by: 1) == 0,
      "и никогда не выходит за 0…1")

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
check(Pulse.sprout.taps(over: 0).isEmpty, "на нулевом времени тычков нет")

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
// Сад втрое быстрее настоящего: 0.3 от семи суток — 2.1 суток сада, то есть
// 0.7 настоящих суток.
func real(days: Double) -> String { round2(days * 86_400 / Garden.speed) }
check(delay(0.50), real(days: 2.1),
      "с 50% до 20% при недельной сушке — 2.1 суток сада")
check(delay(0.50, 14), real(days: 4.2),
      "вдвое медленнее сохнет — вдвое дольше ждать")
check(delay(0.20), "0.00", "ровно на пороге — уже пора")
check(delay(0.05), "0.00", "ниже порога — тем более")
check(delay(0.50, 0), "никогда", "без скорости сушки срока нет")
check(delay(0.50, 7, 0.4), real(days: 0.7), "порог выше — ждать меньше")

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
check(round2(single.after), real(days: 1.5),
      "0.3 от пяти суток — полтора дня сада")
check(Reminder.text(for: single), "«Борис» просит воды", "строка про одного")

check(Reminder.next(in: [], threshold: 0.2) == nil,
      "в пустой квартире будить некого")
check(due.ids.count == 2 && due.ids.contains("Сумка") && due.ids.contains("Кефир"),
      "кнопка «Полил» польёт всех, кому к этому мигу сухо")

var fed = plantNamed("Фиалка", moisture: 1, dryingDays: 5)
fed.care = Care(feedEvery: 14, sinceFed: 10, repotEvery: 365, sinceRepot: 300)
var potted = plantNamed("Кактус", moisture: 1, dryingDays: 30)
potted.care = Care(feedEvery: 30, sinceFed: 0, repotEvery: 730, sinceRepot: 728)
let chores = [Room(name: "Кухня", plants: [fed, potted])]
Season.growing = true
let chore = Reminder.chore(in: chores)!
check(chore.plant.name == "Кактус" && chore.repot,
      "ближайший уход — пересадка кактуса через два дня")
check(Reminder.text(for: chore), "«Кактус» просится в горшок побольше",
      "строка уведомления о пересадке")
Season.growing = false
potted.care?.repotEvery = nil
check(Reminder.chore(in: [Room(name: "Кухня", plants: [fed, potted])])
      .map { $0.plant.name } == "Фиалка"
      && Reminder.chore(in: [Room(name: "Кухня", plants: [fed, potted])])!.repot,
      "зимой о подкормке не напоминают — только о пересадке")
Season.growing = true

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
check(Species.table.allSatisfy { $0.days <= Double(Species.longest) },
      "срок любого вида помещается на барабан")
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
          "2 ноября 2025\u{202F}г., 7:00", "в прошлом году — с годом")
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
    check(Diary.rhythm(20 * 60), "раз в 20 минут", "минуты")
    check(Diary.rhythm(3 * 60), "раз в 3 минуты", "три минуты")
    check(Diary.rhythm(3_600), "раз в час", "час")
    check(Diary.rhythm(5 * 3_600), "раз в 5 часов", "часы")
    check(Diary.rhythm(2 * 3_600), "раз в 2 часа", "два часа")
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

print("новый срок полива:")
do {
    var fern = plant(moisture: 4.0 / 7, dryingDays: 7)
    fern.retime(14)
    check(round2(fern.moisture), round2(11.0 / 14),
          "сохло три дня из недели — из двух недель остаётся одиннадцать")
    check("\(fern.daysUntilWatering)", "11", "срок на карточке тоже")
    var cactus = plant(moisture: 0, dryingDays: 7)
    cactus.retime(28)
    check(round2(cactus.moisture), "0.75", "сухой при месячном сроке — не сухой")
    var basil = plant(moisture: 0.5, dryingDays: 10)
    basil.retime(4)
    check(round2(basil.moisture), "0.00", "короче, чем уже сохло, — досуха")
    var same = plant(moisture: 0.3, dryingDays: 7)
    same.retime(7)
    same.retime(0)
    check(round2(same.moisture) == "0.30" && same.dryingDays == 7,
          "тот же или нулевой срок ничего не меняет")
}

print("сроки в настройках растения:")
do {
    check(Species.periodLabel(7), "Раз в 7 дней", "целое")
    check(Species.periodLabel(3), "Раз в 3 дня", "целое, «дня»")
    check(Species.periodLabel(6.5), "Раз в 6,5 дня", "дробное")
    check(Species.periodLabel(10.4), "Раз в 10,4 дня", "дробное больше десяти")
    check(Species.usual(for: " кактус ") == 30, "обычный срок вида")
    check(Species.usual(for: "Баобаб") == nil, "незнакомый вид — без срока")
}

print("настройки растения:")
do {
    let garden = Garden()
    let roster = garden.roster
    garden.tune("baksik", name: "  Бакс ", species: "Роза", dryingDays: 18)
    let bax = garden.plant(id: "baksik")!
    check(bax.name, "Бакс", "кличка обрезается")
    check(bax.species, "Роза", "вид сменился")
    check(bax.dryingDays == 18, "срок сменился")
    check(garden.roster > roster, "новую кличку узнает и Siri")
    garden.tune("baksik", name: " ", species: "", dryingDays: 18)
    let kept = garden.plant(id: "baksik")!
    check(kept.name == "Бакс" && kept.species == "Роза",
          "пустые кличка и вид остаются прежними")
}

print("заметки:")
do {
    let garden = Garden()
    garden.note("pr", "  Пересадил в мае.\nУдобрять раз в месяц.  \n")
    check(garden.plant(id: "pr")!.note ?? "",
          "Пересадил в мае.\nУдобрять раз в месяц.", "обрезается по краям")
    check(garden.search("удобрять").map(\.id) == ["pr"],
          "поиск находит и по заметке")
    garden.note("pr", "   ")
    check(garden.plant(id: "pr")!.note == nil, "пустая — стёрта")
    var noted = Seed.rooms[0].plants[0]
    noted.note = "Любит свет"
    let file = try! JSONEncoder().encode(noted)
    let back = try! JSONDecoder().decode(Plant.self, from: file)
    check(back.note ?? "", "Любит свет", "заметка переживает запуск")
}

print("отмена полива:")
do {
    let garden = Garden()
    let before = garden.plant(id: "sumka")!.moisture
    let count = garden.log.count
    let moment = Date()
    let pour = garden.water("sumka", at: moment)!
    check(round2(pour.moisture), round2(before), "полив помнит, что было")
    check(pour.name, "Сумка", "и кличку — для плашки")
    garden.advance(to: Date().addingTimeInterval(2))
    let dried = 1 - garden.plant(id: "sumka")!.moisture
    garden.unwater(pour)
    check(round2(garden.plant(id: "sumka")!.moisture),
          round2(max(0, before - dried)),
          "влажность прежняя, за вычетом высохшего за отсчёт")
    check(garden.log.count == count, "запись ушла из журнала")
    check(garden.water("нет такого") == nil, "чужой номер не поливается")
    check(garden.log.count == count, "и в журнал не пишется")

    let first = Watering(plant: "pr", when: moment.addingTimeInterval(-60))
    garden.water("pr", at: first.when)
    garden.water("pr", at: moment)
    let wet = garden.plant(id: "pr")!.moisture
    garden.forget(first)
    check(Diary.of(garden.log, plant: "pr").entries == [moment],
          "ошибочная запись стёрта из истории, другая осталась")
    check(garden.plant(id: "pr")!.moisture == wet,
          "а влажность не тронута")
}

/// Доля граней, чей обход согласен с нормалями вершин, и всё ли в сетке
/// конечно, единично и в своих границах.
func sound(_ mesh: Mesh3D) -> (agree: Double, intact: Bool) {
    var agree = 0
    var faces = 0
    for face in stride(from: 0, to: mesh.indices.count, by: 3) {
        let a = Int(mesh.indices[face])
        let b = Int(mesh.indices[face + 1])
        let c = Int(mesh.indices[face + 2])
        let normal = (mesh.positions[b] - mesh.positions[a])
            .crossed(mesh.positions[c] - mesh.positions[a])
        guard normal.size > 1e-12 else { continue }
        faces += 1
        let average = mesh.normals[a] + mesh.normals[b] + mesh.normals[c]
        if normal.dotted(average) > 0 { agree += 1 }
    }
    let intact = mesh.indices.count % 3 == 0
        && mesh.normals.count == mesh.positions.count
        && mesh.uvs.count == mesh.positions.count
        && mesh.indices.allSatisfy { Int($0) < mesh.positions.count }
        && mesh.positions.allSatisfy { $0.x.isFinite && $0.y.isFinite
            && $0.z.isFinite }
        && mesh.normals.allSatisfy { abs($0.size - 1) < 1e-3 }
        && mesh.uvs.allSatisfy { $0.x.isFinite && $0.y.isFinite }
    return (faces == 0 ? 1 : Double(agree) / Double(faces), intact)
}

print("объёмные формы: сетки целы и смотрят наружу:")
do {
    let shapes: [(String, Mesh3D)] = [
        ("горшок", Sculpt.lathe(Grower.profile(.classic), segments: 48)),
        ("лист", Sculpt.card(length: 0.1, width: 0.07,
                             bend: Sculpt.Bend(arch: 0.2, fold: 0.2, wave: 0.02),
                             hug: { Leafart.half(.heart, $0) })),
        ("мясистый лист", Sculpt.fleshy(length: 0.1, width: 0.03,
                                        thickness: 0.01, arch: 0.1) {
            pow(sin(Float.pi * pow($0, 0.5)), 1.3)
        }),
        ("стебель", Sculpt.tube([Vec3(0, 0, 0), Vec3(0.02, 0.05, 0),
                                 Vec3(0.03, 0.1, 0.01)], sides: 6) { _ in 0.004 }),
        ("шарик", Sculpt.ball(radius: 0.01)),
        ("колючка", Sculpt.spike(radius: 0.001, height: 0.01)),
        ("кольцо", Sculpt.arc(inner: 0.1, outer: 0.11, sweep: 0.6)),
        ("лейка", WateringCan.mesh),
    ]
    for (name, mesh) in shapes {
        let (agree, intact) = sound(mesh)
        check(intact && agree > 0.97, "\(name): сетка цела, грани наружу")
    }
    let pot = Sculpt.lathe(Grower.profile(.classic), segments: 48)
    let wall = pot.positions.indices.first {
        let p = pot.positions[$0]
        return abs(p.y - 0.062) < 0.005 && (p.x * p.x + p.z * p.z) > 0.004
    }!
    check(pot.normals[wall].x * pot.positions[wall].x
          + pot.normals[wall].z * pot.positions[wall].z > 0,
          "стенка горшка светится снаружи")
    check(Sculpt.arc(inner: 0.1, outer: 0.11, sweep: 0).isEmpty,
          "пустое кольцо — пустая сетка")
    let spun = Vec3(1, 0, 0).turned(around: Vec3(0, 1, 0), by: Float.pi / 2)
    check(round2(Double(spun.z)), "-1.00",
          "поворот по правой руке, как у simd_quatf")
    let leaf = Sculpt.card(length: 0.1, width: 0.06, bend: Sculpt.Bend())
    let tangents = leaf.tangents()
    check(zip(tangents, leaf.normals).allSatisfy {
        abs($0.size - 1) < 1e-3 && abs($0.dotted($1)) < 1e-3
    }, "касательные единичные и лежат в плоскости листа")
    let pose = Pose(base: Vec3(1, 0, 0), yaw: Float.pi / 2, rise: 0.3, size: 2)
    check(abs(pose.place(Vec3(0, 0, 0)).x - 1) < 1e-6,
          "поза: начало детали встаёт в точку крепления")
}

print("текстуры рисуются своими руками:")
do {
    var square = Picture(width: 20, height: 20)
    square.fill([SIMD2(0.25, 0.25), SIMD2(0.75, 0.25), SIMD2(0.75, 0.75),
                 SIMD2(0.25, 0.75)], Ink(1, 0, 0, 1))
    check(abs(square.opaque - 0.25) < 0.01, "квадрат в четверть — четверть закрашена")
    check(square.ink(at: 10, 10).x > 0.99 && square.ink(at: 1, 1).w == 0,
          "внутри красное, снаружи пусто")
    var disc = Picture(width: 100, height: 100)
    disc.disc(SIMD2(0.5, 0.5), radius: 0.3, Ink(0, 1, 0, 1))
    check(abs(disc.opaque - Float.pi * 0.09) < 0.02, "круг — пи эр квадрат")
    disc.disc(SIMD2(0.5, 0.5), radius: 0.1, Ink(0, 0, 0, 1), blend: .erase)
    check(disc.ink(at: 50, 50).w < 0.01, "стирание оставляет дыру")
    let flat = Relief(width: 8, height: 8).normals(strength: 5)
    let middle = flat.ink(at: 4, 4)
    check(abs(middle.x - 0.5) < 0.01 && abs(middle.z - 1) < 0.01,
          "ровный рельеф — нормаль прямо вверх")
    var hill = Relief(width: 32, height: 32)
    hill.stroke([SIMD2(0.5, 0), SIMD2(0.5, 1)], width: { _ in 0.2 }, by: 1)
    let slope = hill.normals(strength: 5).ink(at: 12, 16)
    check(slope.x < 0.45, "слева от гребня нормаль смотрит влево")
    var tile = Picture(width: 64, height: 8)
    tile.shade { uv, _ in
        let n = Noise.fractal(uv.x, uv.y, cells: 4, seed: 3)
        return Ink(n, n, n, 1)
    }
    check(abs(tile.ink(at: 0, 4).x - tile.ink(at: 63, 4).x) < 0.1,
          "шум сходится на шве горшка")

    let monstera = LeafLook(outline: .heart, aspect: 0.9, veins: .pinnate(7),
                            base: Channels(34, 104, 50), slits: 6, holes: 4)
    var whole = monstera
    whole.slits = 0
    whole.holes = 0
    let cut = Leafart.leaf(monstera, seed: 1, height: 256)
    let solid = Leafart.leaf(whole, seed: 1, height: 256)
    check(solid.color.opaque > 0.35 && solid.color.opaque < 0.85,
          "лист занимает свою долю картинки: \(solid.color.opaque)")
    check(cut.color.opaque < solid.color.opaque - 0.03,
          "прорези и окошки монстеры — настоящие дыры")
    check(cut.normal.width == cut.color.width / 2, "рельеф вдвое мельче цвета")
    let fern = Leafart.frond(Channels(66, 136, 58), seed: 2)
    check(fern.opaque > 0.2 && fern.opaque < 0.8, "вайя — перышки, а не заливка")
}

print("готовые виды в объёме:")
do {
    check(Preset.of("Монстера") == .monstera, "монстера")
    check(Preset.of("Каменная роза") == .echeveria, "каменная роза — суккулент")
    check(Preset.of("Розмарин") == .rosemary, "розмарин — свой, хоть и с «роз»")
    check(Preset.of("Роза") == .rose, "роза — своя модель")
    check(Preset.of("Розы чайные") == .rose, "и во множественном числе")
    check(Preset.of("Тюльпан") == .tulip, "тюльпан")
    check(Preset.of("Лилия") == .lily, "лилия")
    check(Preset.of("Хойя карноза") == .hoya, "хойя — не плющ")
    check(Preset.of("Мята перечная") == .mint, "мята — не просто травы")
    check(Preset.of("Каланхоэ Блоссфельда") == .kalanchoe,
          "каланхоэ — не толстянка")
    check(Preset.of("Лимон") == .citrus, "лимон — дерево с плодами")
    check(Preset.of("Опунция") == .opuntia && Preset.of("Юкка") == .yucca
            && Preset.of("Калатея") == .calathea
            && Preset.of("Алоказия") == .alocasia,
          "новые виды узнаются по названию")
    check(Preset.of("Баобаб") == .spathiphyllum, "незнакомый — спатифиллум")
    check(Preset.of("Monstera deliciosa") == .monstera, "латинское имя")
    check(Preset.of("Snake plant") == .sansevieria, "английское название")
    check(Preset.of("Peace lily") == .spathiphyllum,
          "«peace lily» — спатифиллум, а не лилия")
    check(Preset.of("Rosemary") == .rosemary, "rosemary — не роза")
    check(Preset.of("Sunflower") == .sunflower, "sunflower — не просто flower")
    check(Preset.of("Kaktus") == .cactus, "кактус по-немецки и по-польски")
    check(Preset.allCases.allSatisfy { Preset.of($0.title) == $0 },
          "своё же название каждый вид узнаёт")
    check(Preset.allCases.count == 37, "готовых видов — тридцать семь")
    let species = Set(Seed.rooms.flatMap(\.plants).map(\.species))
    check(species.allSatisfy { name in
        Preset.allCases.contains(Preset.of(name))
    }, "каждый вид сада сводится к одному из готовых")

    // Готовые модели лежат в приложении — выращенные tool/make_stock.py.
    // Рецепт поменялся, а их не пересобрали — телефон показал бы прежние.
    let summary = (try? Data(contentsOf: URL(
        fileURLWithPath: "tool/stock-models/manifest.json")))
        .flatMap { try? JSONSerialization.jsonObject(with: $0) }
        as? [String: Any]
    let bundled = Dictionary(
        ((summary?["kits"] as? [[String: Any]]) ?? []).compactMap { row in
            (row["preset"] as? String).map { ($0, row) }
        }, uniquingKeysWith: { first, _ in first })
    check(summary?["version"] as? Int == Int(Kit.version),
          "готовые модели — той же версии, что и сборка")
    var stale: [String] = []
    var slow: [String] = []
    var odd: [String] = []
    var total = 0
    for preset in Preset.allCases {
        let started = Date()
        let kit = Botany.grow(.stock(preset), species: preset.title)
        let spent = Date().timeIntervalSince(started)
        total += kit.triangles
        let row = bundled[preset.rawValue]
        let file = "ios-native/Sprout/Assets.xcassets/Stock/stock-"
            + "\(preset.rawValue).dataset/stock-\(preset.rawValue).kit"
        if row?["triangles"] as? Int != kit.triangles
            || row?["pieces"] as? Int != kit.pieces.count
            || row?["pictures"] as? Int != kit.pictures.count
            || !FileManager.default.fileExists(atPath: file) {
            stale.append(preset.rawValue)
        }
        if spent > 1.5 { slow.append("\(preset) \(round2(spent)) с") }
        let meshes = kit.meshes.map(sound)
        let broken = meshes.filter { !$0.intact || $0.agree < 0.9 }.count
        let indexed = kit.pieces.allSatisfy {
            $0.mesh < kit.meshes.count && $0.look < kit.looks.count
        } && kit.looks.allSatisfy {
            ($0.color ?? 0) < kit.pictures.count
                && ($0.normal ?? 0) < kit.pictures.count
        }
        if broken > 0 || !indexed || kit.triangles < 8_000
            || kit.triangles > 400_000 || kit.height < 0.14
            || kit.height > 0.75 || kit.spread > 0.45 {
            odd.append("\(preset): треугольников \(kit.triangles), высота "
                + "\(round2(Double(kit.height))), размах "
                + "\(round2(Double(kit.spread))), битых сеток \(broken)")
        }
        print("    \(preset.title): \(kit.triangles) треугольников, "
              + "\(kit.pieces.count) деталей, \(kit.pictures.count) картинок, "
              + "\(round2(spent)) с")
    }
    check(stale.isEmpty,
          "готовые модели в приложении свежие — иначе tool/make_stock.py: "
              + "\(stale)")
    check(bundled.count == Preset.allCases.count,
          "и лишних среди них нет")
    check(odd.isEmpty, "каждый вид вырастает целым и в разумных размерах: \(odd)")
    check(slow.isEmpty, "и быстро: \(slow)")
    let kinds = Preset.allCases.count
    check(total > kinds * 15_000,
          "и детально: в среднем \(total / kinds) треугольников")

    // Роза — свой рецепт внутри цветущего куста: спираль лепестков.
    let rose = Botany.grow(.stock("Роза"), species: "Роза")
    let geranium = Botany.grow(.stock(.pelargonium), species: "Пеларгония")
    check(rose != geranium, "роза вырастает розой, а не пеларгонией")
    check(rose.meshes.map(sound).allSatisfy { $0.intact && $0.agree >= 0.9 }
          && rose.triangles >= 8_000 && rose.triangles <= 400_000
          && rose.height >= 0.14 && rose.height <= 0.75 && rose.spread <= 0.45,
          "и целой: \(rose.triangles) треугольников, высота "
              + "\(round2(Double(rose.height)))")
    // Цветок — не один круг лепестков: у каждого цветущего вида есть
    // тычинки или пыльники — детали цветка, которые не вянут и не вырезаны.
    for preset in [Preset.orchid, .violet, .begonia, .pelargonium, .tulip,
                   .lily, .chrysanthemum, .kalanchoe, .citrus, .hoya] {
        let kit = Botany.grow(.stock(preset), species: preset.title)
        let petals = Set(kit.pieces.filter {
            kit.looks[$0.look].cutout && !kit.looks[$0.look].wilts
        }.map(\.mesh))
        let solid = kit.pieces.filter {
            !kit.looks[$0.look].cutout && !kit.looks[$0.look].wilts
                && kit.looks[$0.look].color == nil
        }
        check(petals.count >= 1 && solid.count > petals.count,
              "у цветов «\(preset.title)» есть серединка и тычинки")
    }

    let one = Botany.grow(.stock("Монстера"), species: "Монстера")
    let again = Botany.grow(.stock("Монстера"), species: "Монстера")
    check(one == again, "один чертёж — одна и та же модель")
    let traits = Traits(leaf: Channels(90, 160, 60), variegation: nil,
                        flower: Channels(250, 200, 40), pot: Channels(40, 40, 44),
                        density: 1.3, stretch: 1.2)
    let mine = Botany.grow(Blueprint(preset: .monstera, traits: traits,
                                     seed: "мой"), species: "Монстера")
    check(mine.pieces.count > one.pieces.count, "густая листва со снимка — гуще")
    check(mine.height > one.height, "вытянутая со снимка — выше")

    let file = one.encoded()
    check(Kit(file) == one, "модель переживает файл: \(file.count / 1024) КБ")
    check(Kit(file.prefix(100)) == nil, "обрезанный файл — нет модели, а не падение")
    var foreign = file
    foreign[4] = 99
    check(Kit(foreign) == nil, "файл другой версии не читается")

    let stock = Blueprint.stock("Монстера")
    check(stock.traits == nil && stock.preset == .monstera, "готовая модель вида")
    check(Blueprint.stock("Кактус").fingerprint != stock.fingerprint,
          "у разных чертежей разные имена файлов")
}

print("снимок для модели:")
do {
    /// Горшок терракотой внизу, зелёная листва сверху, красные цветы и
    /// шахматная рябь листьев — чтобы снимок был резким.
    func photo(blur: Int = 0, dark: Bool = false) -> [UInt8] {
        let size = 96
        var pixels = [UInt8](repeating: 235, count: size * size * 4)
        for y in 0 ..< size {
            for x in 0 ..< size {
                let at = (y * size + x) * 4
                var color: (UInt8, UInt8, UInt8) = (235, 235, 235)
                let dx = x - size / 2
                if y > 64 && abs(dx) < 22 {
                    color = (190, 100, 64)
                } else if y > 12 && y <= 64 && abs(dx) < 34 {
                    let ripple = (x / 3 + y / 3) % 2 == 0
                    color = ripple ? (46, 128, 52) : (70, 160, 70)
                    if (x - 30) * (x - 30) + (y - 24) * (y - 24) < 30 {
                        color = (220, 30, 50)
                    }
                }
                if dark { color = (color.0 / 12, color.1 / 12, color.2 / 12) }
                pixels[at] = color.0
                pixels[at + 1] = color.1
                pixels[at + 2] = color.2
                pixels[at + 3] = 255
            }
        }
        guard blur > 0 else { return pixels }
        var out = pixels
        for y in 0 ..< size {
            for x in 0 ..< size {
                for channel in 0 ..< 3 {
                    var sum = 0
                    var count = 0
                    for yy in max(y - blur, 0) ... min(y + blur, size - 1) {
                        for xx in max(x - blur, 0) ... min(x + blur, size - 1) {
                            sum += Int(pixels[(yy * size + xx) * 4 + channel])
                            count += 1
                        }
                    }
                    out[(y * size + x) * 4 + channel] = UInt8(sum / count)
                }
            }
        }
        return out
    }
    var mask = [UInt8](repeating: 0, count: 96 * 96)
    for y in 12 ..< 96 {
        for x in 0 ..< 96 where abs(x - 48) < 34 { mask[y * 96 + x] = 255 }
    }
    let sharp = Sample.read(rgba: photo(), mask: mask, width: 96, height: 96)
    check(sharp.verdict == .fine, "резкий снимок годится")
    if let traits = sharp.traits {
        check(traits.leaf.green > traits.leaf.red + 40, "лист зелёный")
        check((traits.pot?.red ?? 0) > 150, "горшок терракотовый")
        check((traits.flower?.red ?? 0) > 180
              && (traits.flower?.green ?? 255) < 90, "цветы красные")
        check(traits.density >= 0.75 && traits.density <= 1.35
              && traits.stretch >= 0.8 && traits.stretch <= 1.3,
              "густота и вытянутость в своих границах")
    } else {
        check(false, "черты сняты")
    }
    let blurry = Sample.read(rgba: photo(blur: 4), mask: mask, width: 96,
                             height: 96)
    check(blurry.verdict == .blurry && blurry.traits == nil,
          "мыльный — готовая модель")
    check(Sample.read(rgba: photo(dark: true), mask: mask, width: 96,
                      height: 96).verdict == .dark, "тёмный — тоже")
    let gray = [UInt8](repeating: 128, count: 96 * 96 * 4)
    check(Sample.read(rgba: gray, mask: nil, width: 96, height: 96).traits == nil,
          "на сером растения нет")
    check(Sample.read(rgba: photo(), mask: nil, width: 96, height: 96)
          .verdict == .fine, "без маски — середина кадра")
}

print("растение носит свой чертёж:")
do {
    let traits = Traits(leaf: Channels(90, 160, 60), variegation: nil,
                        flower: nil, pot: nil, density: 1, stretch: 1)
    let planted = Plant.new(name: "Новый", species: "Фикус", dryingDays: 7,
                            traits: traits, id: "новый-1")
    check(planted.plan?.seed == "новый-1" && planted.plan?.preset == .ficus,
          "по снимку — чертёж с зерном из номера")
    check(Plant.new(name: "Без", species: "Фикус", dryingDays: 7).plan == nil,
          "без снимка чертежа нет")
    check(Plant.new(name: "Без", species: "Фикус", dryingDays: 7)
          .blueprint == .stock("Фикус"), "и растёт готовая модель вида")
    let file = try! JSONEncoder().encode(planted)
    check(try! JSONDecoder().decode(Plant.self, from: file).plan == planted.plan,
          "чертёж переживает запуск")
    let garden = Garden()
    garden.add(planted, to: "Кабинет")
    garden.tune("новый-1", name: "Новый", species: "Кактус", dryingDays: 7)
    let changed = garden.plant(id: "новый-1")!.plan
    check(changed?.preset == .cactus && changed?.traits == traits,
          "сменили вид — меняется модель, черты со снимка остаются")
}

print("объёмное растение живёт влажностью:")
do {
    check(Greenhouse.sag(1) == 0 && Greenhouse.sag(0.5) == 0,
          "политое не никнет")
    check(Greenhouse.sag(0) == 1, "сухое никнет до конца")
    var steady = true
    var last: Float = -1
    for step in 0 ... 20 {
        let now = Greenhouse.sag(1 - Double(step) / 20)
        if now < last { steady = false }
        last = now
    }
    check(steady, "и никнет всё сильнее, без скачков назад")
    check(Greenhouse.wilt(0.5) == 0 && round2(Greenhouse.wilt(0)) == "0.70",
          "желтеет с порога тревоги и не до конца")
    check(Greenhouse.wetTint(1) == Greenhouse.wetShade, "политая земля тёмная")
    check(Greenhouse.wetTint(0) == Channels(255, 255, 255), "сухая — как нарисована")
    check(Greenhouse.wither(1) == 0 && Greenhouse.wither(0.5) == 0,
          "политый лист не вянет")
    check(Greenhouse.wither(0) == 1, "сухой — до конца")
    check(Greenhouse.wither(0.3) > 0 && Greenhouse.wither(0.3) < 1,
          "между ними — ступенью")
    let green = Picture(width: 2, height: 2, fill: Ink(0.2, 0.55, 0.22, 1))
    let dry = green.withered(1).ink(at: 0, 0)
    check(dry.x > dry.z && dry.x > 0.3 && dry.w == 1,
          "увядший рисунок — в солому, прозрачность та же")
    check(Greenhouse.ringColor(0.8) == Greenhouse.calmRing, "кольцо голубое")
    check(Greenhouse.ringColor(0.05).red > 250, "у сухого — красное")
    check(Greenhouse.unfurl(0) == 0 && Greenhouse.unfurl(1) == 1,
          "появление от нуля до единицы")
    let peak = (0 ... 100).map { Greenhouse.unfurl(Double($0) / 100) }.max()!
    check(peak > 1.05 && peak < 1.15, "с перелётом, но небольшим")
}

print("полив лейкой:")
do {
    check(Pouring.pose(at: 0).size == 0, "лейка появляется из ничего")
    let middle = Pouring.pose(at: Pouring.arrive + Pouring.tiltIn + 1)
    check(middle.emit && middle.tilt == Pouring.angle, "в середине льёт")
    check(Pouring.pose(at: Pouring.total).size == 0, "и улетает")
    var jumps = 0
    var previous = Pouring.pose(at: 0)
    for step in 1 ... 1_000 {
        let now = Pouring.pose(at: Pouring.total * Double(step) / 1_000)
        if abs(now.tilt - previous.tilt) > 0.1
            || abs(now.travel - previous.travel) > 0.1 { jumps += 1 }
        previous = now
    }
    check(jumps == 0, "без рывков")

    var generator = Seeded("полив")
    for (scale, clearance) in [(Float(0.35), Pouring.lowest),
                               (1, Pouring.lowest), (2.5, Pouring.lowest),
                               (1, Pouring.clearance(over: 0.45))] {
        let origin = Pouring.origin(scale: scale, clearance: clearance)
        let tip = Pouring.spout(from: origin, tilt: Pouring.angle,
                                scale: scale)
        let want = Pouring.tip(scale: scale, clearance: clearance)
        check(abs(tip.x - want.x) < 1e-5 && abs(tip.y - want.y) < 1e-5,
              "кончик носика там, где задумано (размер \(scale))")
        var inside = 0
        let floor = Greenhouse.soil * scale
        for _ in 0 ..< 300 {
            let launch = Pouring.launch(scale: scale)
                * Float.random(in: 0.94 ... 1.06, using: &generator)
            let side = Float.random(in: -0.03 ... 0.03, using: &generator)
                * Pouring.speed * scale.squareRoot()
            var drop = Droplet(
                position: Vec3(tip.x, tip.y,
                               Float.random(in: -0.004 ... 0.004,
                                            using: &generator) * scale),
                velocity: Vec3(launch.x, launch.y, side))
            while drop.position.y > floor && drop.age < 3 { drop.fall(1 / 240) }
            let reach = (drop.position.x * drop.position.x
                + drop.position.z * drop.position.z).squareRoot()
            if reach < Greenhouse.potInner * scale * 0.85 { inside += 1 }
        }
        check(inside >= 294,
              "струя попадает в горшок: \(inside) из 300 (размер \(scale))")
    }
    let origin = Pouring.origin(scale: 1, clearance: Pouring.clearance(over: 0.4))
    check(origin.y - 0.06 > 0.4 - Greenhouse.soil,
          "над высоким растением лейка висит выше листвы")

    // Струйки сеточки: у каждой свой сдвиг и разлёт, и все — в горшок.
    let rose = Pouring.jets(7)
    check(rose.count == 7 && rose[0].hole == .zero && rose[0].width == 1,
          "средняя струйка — в середине и толще")
    check(Set(rose.dropFirst().map { $0.hole }).count == 6,
          "остальные — каждая из своей дырочки")
    check(Pouring.jets(0).isEmpty, "без струек — без воды")
    for scale in [Float(0.35), 1, 2.5] {
        let clearance = Pouring.clearance(over: 0.45)
        let tip = Pouring.tip(scale: scale, clearance: clearance)
        let launch = Pouring.launch(scale: scale)
        let pace = (launch * launch).sum().squareRoot()
        let heading = launch / pace
        let across = SIMD2(-heading.y, heading.x)
        var landed = 0
        for jet in rose {
            let start = tip + across * jet.hole.y * Pouring.rose * scale
            let bent = launch + across * jet.lean.y * pace
            var drop = Droplet(
                position: Vec3(start.x, start.y,
                               jet.hole.x * Pouring.rose * scale),
                velocity: Vec3(bent.x, bent.y, jet.lean.x * pace))
            while drop.position.y > Greenhouse.soil * scale && drop.age < 3 {
                drop.fall(1 / 240)
            }
            let reach = (drop.position.x * drop.position.x
                + drop.position.z * drop.position.z).squareRoot()
            if reach < Greenhouse.potInner * scale * 0.9 { landed += 1 }
        }
        check(landed == rose.count,
              "все струйки сеточки — в горшок (размер \(scale))")
    }
    let low = Pouring.tip(scale: 1, clearance: 0.2, soil: 0.3)
    check(abs(low.y - 0.5) < 1e-5, "у скана земля выше — и лейка выше")

    // Струя целиком: сеточка льёт две секунды, кадры по 1/60.
    for scale in [Float(0.5), 1, 2] {
        let clearance = Pouring.clearance(over: 0.3)
        var rill = Rill(jets: 7)
        let flight = Rill.flight(scale: scale, clearance: clearance)
        rill.begin(scale: scale, flight: flight)
        let tip = Pouring.tip(scale: scale, clearance: clearance)
        let launch = Pouring.launch(scale: scale)
        var first: Double?
        var hits = 0
        var widest = 0
        var broken = false
        var clock = 0.0
        let dt = 1.0 / 60
        while clock < 4 {
            if clock < 2 {
                rill.pour(from: Vec3(tip.x, tip.y, 0),
                          jet: Vec3(launch.x, launch.y, 0),
                          side: Vec3(0, 0, 1), dt: dt)
            } else {
                rill.stop()
            }
            clock += dt
            if let hit = rill.fly(Float(dt),
                                  ground: Greenhouse.soil * scale,
                                  center: .zero,
                                  mouth: Greenhouse.potInner * scale,
                                  floor: -0.02) {
                first = first ?? clock
                hits += 1
                let reach = (hit.x * hit.x + hit.z * hit.z).squareRoot()
                if reach > Greenhouse.potInner * scale { broken = true }
            }
            let mesh = rill.geometry()
            widest = max(widest, mesh.vertices.count)
            if mesh.indices.contains(where: { Int($0) >= mesh.vertices.count })
                || mesh.vertices.contains(where: { $0.position.x.isNaN }) {
                broken = true
            }
            if widest > rill.room.vertices { broken = true }
        }
        check(first.map { $0 < Double(flight) + 0.1 } ?? false,
              "струя долетает до земли за время полёта (размер \(scale))")
        check(hits > 60 && !broken,
              "льётся в горшок, сетка целая и в своих буферах "
                  + "(размер \(scale), точек до \(widest))")
        check(rill.idle, "лейка выпрямилась — струя долетела и кончилась")
    }
}

print("время года:")
do {
    check(Season.side(region: "RU") == .north, "Россия — север")
    check(Season.side(region: "au") == .south, "Австралия — юг")
    check(Season.side(region: "SG") == .tropics, "Сингапур — у экватора")
    check(Season.side(region: nil) == .north, "страна неизвестна — север")
    check(Season.stretch(month: 1, side: .north) > 1.3,
          "январь на севере: срок на треть длиннее")
    check(Season.stretch(month: 7, side: .north) < 0.9,
          "июль на севере: короче")
    check(Season.stretch(month: 7, side: .south)
          == Season.stretch(month: 1, side: .north),
          "южный июль — северный январь")
    check((1 ... 12).allSatisfy { Season.stretch(month: $0, side: .tropics) == 1 },
          "у экватора срок круглый год тот же")
    check(Season.growing(month: 5, side: .north)
          && !Season.growing(month: 12, side: .north)
          && Season.growing(month: 12, side: .south),
          "пора роста: весна и лето своего полушария")
    let steps = (1 ... 12).map { Season.stretch(month: $0, side: .north) }
    check(zip(steps, steps.dropFirst() + [steps[0]]).allSatisfy {
        abs($0 - $1) < 0.25 }, "от месяца к месяцу срок не прыгает")

    var wintry = plant(moisture: 1, dryingDays: 10)
    Season.stretch = 1.35
    check(round2(wintry.period), "13.50", "зимой срок длиннее записанного")
    wintry.dry(days: 13.5)
    check(round2(wintry.moisture), "0.00", "и земля сохнет за зимний срок")
    check(wintry.dryingDays == 10, "записанный срок при этом не меняется")
    Season.stretch = 1
}

print("срок по привычке:")
do {
    var often = plant(moisture: 0.5, dryingDays: 9)
    func entries(_ left: [Double]) -> [Watering] {
        left.enumerated().map {
            Watering(plant: "x", when: Date(timeIntervalSince1970: Double($0.offset)),
                     left: $0.element)
        }
    }
    check(Rhythm.suggest(for: often, log: entries([0.4, 0.3, 0.35])) == 6,
          "поливают при трети воды — срок 9 дней стоит сократить до 6")
    check(Rhythm.suggest(for: often, log: entries([0.4, 0.3])) == nil,
          "двух поливов мало — это ещё не привычка")
    check(Rhythm.suggest(for: often, log: entries([0.05, 0.1, 0.0, 0.15])) == nil,
          "поливают у сухой земли — срок верный")
    check(Rhythm.suggest(for: often,
                         log: entries([0.4, 0.3, 0.35]) + [Watering(
                             plant: "y", when: Date(), left: 0.9)]) == 6,
          "чужие поливы в счёт не идут")
    check(Rhythm.suggest(for: often, log: [
        Watering(plant: "x", when: Date()), Watering(plant: "x", when: Date()),
        Watering(plant: "x", when: Date())]) == nil,
          "журнал прежних сборок без доли воды ничего не предлагает")
    often.quiet = 6
    check(Rhythm.suggest(for: often, log: entries([0.4, 0.3, 0.35])) == nil,
          "отклонённое предложение не повторяется")
    check(Rhythm.suggest(for: often, log: entries([0.6, 0.55, 0.62])) == 4,
          "а новое — предлагается")

    let yard = Garden()
    let id = yard.rooms[0].plants[0].id
    let before = yard.plant(id: id)!.moisture
    let pour = yard.water(id)!
    check(round2(yard.log.last?.left ?? -1) == round2(before),
          "полив пишет в журнал, сколько воды оставалось")
    yard.unwater(pour)
    check(!yard.log.contains { $0.plant == id && $0.when == pour.when },
          "отмена находит запись и с долей воды")
    let old = try! JSONDecoder().decode(
        Watering.self, from: Data(#"{"plant":"a","when":0}"#.utf8))
    check(old.left == nil, "запись прежней сборки читается без доли воды")
}

print("подкормка и пересадка:")
do {
    check(Care.usual(for: .cactus).feedEvery == 30
          && Care.usual(for: .violet).feedEvery == 14
          && Care.usual(for: .monstera).repotEvery == 365,
          "сроки ухода — по виду")
    var care = Care(feedEvery: 14, repotEvery: 365)
    care.pass(days: 10, growing: false)
    check(care.sinceFed == 0 && care.sinceRepot == 10,
          "зимой подкормка не считается, а пересадка — да")
    care.pass(days: 14, growing: true)
    check(care.feedDue && !care.repotDue, "за две недели роста — пора подкормить")
    check(Care(feedEvery: nil).feedIn == nil && !Care(feedEvery: nil).feedDue,
          "выключенная подкормка не напоминает")

    let yard = Garden()
    let id = yard.rooms[0].plants[0].id
    Season.growing = true
    yard.advance(to: Date().addingTimeInterval(20 * 86_400 / Garden.speed))
    let grown = yard.plant(id: id)!.tending
    check(round2(grown.sinceFed) == "20.00" && round2(grown.sinceRepot) == "20.00",
          "дни ухода идут вместе с влажностью")
    yard.feed(id)
    check(yard.plant(id: id)!.tending.sinceFed == 0
          && yard.plant(id: id)!.tending.sinceRepot > 0,
          "подкормили — счёт подкормки заново")
    yard.advance(to: Date().addingTimeInterval(40 * 86_400 / Garden.speed))
    yard.repot(id)
    check(yard.plant(id: id)!.tending.sinceFed == 0
          && yard.plant(id: id)!.tending.sinceRepot == 0,
          "пересадили — заново оба счёта")
    yard.tend(id, feedEvery: nil, repotEvery: Care.days(months: 18))
    check(yard.plant(id: id)!.tending.feedEvery == nil
          && Care.months(days: yard.plant(id: id)!.tending.repotEvery!) == 18,
          "сроки ухода правятся из настроек")
    let file = try! JSONEncoder().encode(yard.state)
    let back = try! JSONDecoder().decode(GardenState.self, from: file)
    check(back.rooms[0].plants[0].care == yard.plant(id: id)!.care,
          "уход ложится в файл сада")
}

print("сад в общей папке:")
do {
    let folder = FileManager.default.temporaryDirectory
        .appendingPathComponent("sprout-store-\(UUID().uuidString)")
    try! FileManager.default.createDirectory(at: folder,
                                             withIntermediateDirectories: true)
    Store.testing = folder
    defer {
        Store.testing = nil
        try? FileManager.default.removeItem(at: folder)
    }
    let home = Garden()
    home.save()
    let other = Garden()
    check(other.plantCount == home.plantCount, "второй сад читает тот же файл")
    let id = other.rooms[0].plants[0].id
    other.advance(to: Date().addingTimeInterval(3 * 86_400 / Garden.speed))
    _ = other.water(id)
    check(home.log.count != other.log.count, "пока не перечитал — не знает")
    home.reload()
    check(home.log.count == other.log.count
          && round2(home.plant(id: id)!.moisture) == "1.00",
          "перечитал — видит полив, сделанный мимо него (виджетом)")
    let roster = home.roster
    home.reload()
    check(home.roster == roster, "файл не менялся — перечитывать нечего")
}

print("сила телефона:")
do {
    let a14 = Rig.Hardware(gpu: 7, memory: 4, lidar: false)
    let a15 = Rig.Hardware(gpu: 8, memory: 6, lidar: false)
    let a16pro = Rig.Hardware(gpu: 8, memory: 6, lidar: true)
    let a17pro = Rig.Hardware(gpu: 9, memory: 8, lidar: true)
    let a19 = Rig.Hardware(gpu: 9, memory: 8, lidar: false)
    let a19pro = Rig.Hardware(gpu: 9, memory: 12, lidar: true)
    check(Rig.tier(of: a14) == .lite, "A14 — бережно")
    check(Rig.tier(of: a15) == .standard && Rig.tier(of: a16pro) == .standard,
          "A15 и A16 — обычная сила")
    check(Rig.tier(of: a17pro) == .pro && Rig.tier(of: a19) == .pro
          && Rig.tier(of: a19pro) == .pro,
          "A17 Pro и новее — полная сила: iPhone 15 Pro, 16, 17 и Air")
    let full = Rig.of(a19pro)
    let lite = Rig.of(a14)
    check(full.plants > Rig.of(a15).plants && Rig.of(a15).plants > lite.plants,
          "чем сильнее телефон, тем больше растений в саду разом")
    check(full.jets > lite.jets && full.effects && !lite.effects && full.hdr,
          "и больше капель, и дорогие эффекты только на сильных")
    check(Rig.of(a17pro).room && !Rig.of(a19).room,
          "сетка комнаты — только с LiDAR")
    var hot = a19pro
    hot.strained = true
    let cooled = Rig.of(hot)
    check(cooled.tier == .standard && cooled.plants < full.plants,
          "перегрелся — нагрузка ниже")
    check(cooled.detail == full.detail,
          "а детализация моделей та же: иначе горячий телефон пересобирал бы их")

    let stock = Blueprint.stock(.monstera)
    let normal = Botany.grow(stock, species: "Монстера")
    let sharp = Botany.grow(stock, species: "Монстера",
                            detail: Rig.detail(of: a19pro))
    let soft = Botany.grow(stock, species: "Монстера",
                           detail: Rig.detail(of: a14))
    func pixels(_ kit: Kit) -> Int {
        kit.pictures.reduce(0) { $0 + $1.width * $1.height }
    }
    check(sharp.triangles > normal.triangles && normal.triangles > soft.triangles,
          "сетки гуще на сильном телефоне: \(soft.triangles) → "
              + "\(normal.triangles) → \(sharp.triangles)")
    check(pixels(sharp) > pixels(normal) && pixels(normal) > pixels(soft),
          "и рисунки чётче")
    check(sharp.pieces.count == normal.pieces.count
          && abs(sharp.height - normal.height) < 0.001,
          "а само растение то же: те же листья на тех же местах")
    check(Rig.Detail.standard.key != Rig.detail(of: a19pro).key,
          "детализация — часть ключа кэша моделей")
}

print("сад в AR:")
do {
    let spreads: [Float] = [0.2, 0.1, 0.15, 0.3, 0.12, 0.25]
    let heights: [Float] = [0.5, 0.2, 0.3, 0.7, 0.15, 0.4]
    let spots = Plot.layout(spreads: spreads, heights: heights)
    check(spots.count == 6, "у каждого растения своё место")
    var apart = true
    for i in spots.indices {
        for j in spots.indices where j > i {
            let d = spots[i] - spots[j]
            if (d.x * d.x + d.y * d.y).squareRoot() < spreads[i] + spreads[j] {
                apart = false
            }
        }
    }
    check(apart, "листья соседей не залезают друг в друга")
    check(spots[3].y > spots[4].y && spots[0].y > spots[1].y,
          "высокие — дальше низких, не заслоняют")
    let front = spots.indices.filter { spots[$0].y == spots[4].y }
    check(front.count == 4, "в ряду по четыре")
    let middle = front.map { spots[$0].x }.reduce(0, +) / Float(front.count)
    check(abs(middle) < 0.2, "ряд стоит посередине взгляда")
    check(Plot.layout(spreads: [], heights: []).isEmpty, "пустой сад — пусто")
}

print("модель для AR: проценты сборки:")
do {
    // Таблица работы сходится с настоящей сборкой: иначе проценты замирали
    // бы или прыгали к концу. Разошлась — печатаем новую для Effort.swift.
    func grouped(_ value: Int) -> String {
        var digits = String(value)
        var groups: [String] = []
        while digits.count > 3 {
            groups.insert(String(digits.suffix(3)), at: 0)
            digits.removeLast(3)
        }
        return ([digits] + groups).joined(separator: "_")
    }
    var drift = false
    var table: [String] = []
    for preset in Preset.allCases {
        var row: [Int] = []
        for tier in Rig.Tier.allCases {
            let meter = Meter(expected: 1)
            _ = Meter.$current.withValue(meter) {
                Botany.grow(.stock(preset), species: preset.title,
                            detail: .of(tier))
            }
            row.append(meter.done)
            let want = Effort.expected(preset, .of(tier))
            if abs(Double(meter.done - want)) > Double(want) / 100 {
                drift = true
            }
        }
        table.append("        .\(preset.rawValue): ["
            + row.map(grouped).joined(separator: ", ") + "],")
    }
    check(!drift, "таблица работы сходится со сборкой всех видов")
    if drift { print(table.joined(separator: "\n")) }

    var shares: [Double] = []
    let meter = Meter(expected: Effort.expected(.monstera, .standard)) {
        shares.append($0)
    }
    _ = Meter.$current.withValue(meter) {
        Botany.grow(.stock(.monstera), species: "Монстера")
    }
    check(!shares.isEmpty
          && zip(shares, shares.dropFirst()).allSatisfy { $0 < $1 },
          "проценты только растут")
    check(shares.count <= 101,
          "и зовут экран не чаще, чем раз на процент: \(shares.count)")
    check((shares.last ?? 0) > 0.99, "готовая модель доходит до конца")
    check(Meter.current == nil, "вне сборки счётчика нет")
    let heavy = Meter(expected: 1_000)
    _ = Meter.$current.withValue(heavy) {
        Botany.grow(.stock(.fern), species: "Папоротник")
    }
    check(heavy.share == 1,
          "работы больше, чем ждали, — доля упирается в единицу")
}

print("модель для AR: выбор хозяина:")
do {
    let yard = Garden()
    let id = yard.rooms[0].plants[0].id
    let colours = Traits(leaf: Channels(90, 160, 60), variegation: nil,
                         flower: nil, pot: nil, density: 1.1, stretch: 1)
    check(yard.plant(id: id)?.plan == nil && yard.plant(id: id)?.scan == nil,
          "в саду по умолчанию — готовые модели видов")
    yard.imagine(id, traits: colours)
    let plan = yard.plant(id: id)?.plan
    check(plan?.traits == colours && plan?.seed == id
            && plan?.preset == Preset.of(yard.plant(id: id)!.species),
          "придумать по снимку — чертёж с чертами снимка и видом растения")
    yard.scanned(id, file: "скан.usdz")
    check(yard.plant(id: id)?.scan == "скан.usdz"
            && yard.plant(id: id)?.plan == nil,
          "скан сменяет модель по снимку: в силе последний выбор")
    yard.imagine(id, traits: colours)
    check(yard.plant(id: id)?.scan == nil, "и наоборот")
    yard.unmodel(id)
    check(yard.plant(id: id)?.plan == nil && yard.plant(id: id)?.scan == nil,
          "вернуть готовую модель вида")
    yard.tune(id, name: "", species: "Комнатное растение",
              dryingDays: yard.plant(id: id)!.dryingDays)
    yard.imagine(id, traits: colours, kind: .fern)
    check(yard.plant(id: id)?.plan?.preset == .fern,
          "вид не узнан по названию — берётся узнанный на снимке")
    check(Preset.known("Комнатное растение") == nil
            && Preset.known("Фикус Бенджамина") == .ficus,
          "по названию узнаётся не всякий вид — и это видно")
    let saved = try? JSONEncoder().encode(Plant.new(name: "Скан",
                                                    species: "Фикус",
                                                    dryingDays: 7))
    check(saved.flatMap { try? JSONDecoder().decode(Plant.self, from: $0) }?
            .scan == nil,
          "растения прежних сборок читаются без скана")
}

print("модель для AR: своя по снимку:")
MainActor.assumeIsolated {
    let bench = Bench()
    let stock = plantNamed("Раз", moisture: 0.5, dryingDays: 7)
    var own = stock
    own.plan = Blueprint(preset: .monstera, traits: Traits(
        leaf: Channels(90, 160, 60), variegation: nil, flower: nil, pot: nil,
        density: 1, stretch: 1), seed: stock.id)
    let stamp = own.plan!.fingerprint
    bench.queue(stock)
    check(bench.share(stock) == nil,
          "без своей модели — ничего не собирается: AR берёт готовую вида")
    check(bench.share(own) == nil, "о ком мастерская не знает — ничего")
    bench.queue(own)
    check(bench.share(own) == 0, "свою модель заказали — сразу ноль")
    bench.note(own.id, stamp: stamp, share: 0.4)
    bench.note(own.id, stamp: stamp, share: 0.3)
    check(bench.share(own) == 0.4, "запоздавший отчёт долю не убавляет")
    check(!bench.built(own), "пока собирается — AR показывает модель вида")
    bench.note(own.id, stamp: stamp, share: 1)
    check(bench.built(own), "собралась — AR покажет её")
    bench.queue(own)
    check(bench.built(own), "повторный заказ собранную не сбрасывает")
    own.plan?.preset = .ficus
    check(bench.share(own) == nil, "сменился вид — прежняя сборка не в счёт")
    check(Bench.percent(0.426), "42%", "проценты — вниз, до целого")
    check(Bench.percent(1.3), "100%", "и не больше сотни")
    check(Bench.preparing(nil), "Модель готовится",
          "пока мастерская не дошла — без процентов")
    check(Bench.preparing(0.5), "Модель готовится: 50%", "дошла — с процентами")
}

print("знакомство и словарик:")
do {
    let terms = Term.allCases
    check(terms.allSatisfy { !$0.title.isEmpty && !$0.meaning.isEmpty
                             && !$0.icon.isEmpty },
          "у каждого слова есть название, пояснение и знак")
    check(Set(terms.map(\.title)).count == terms.count,
          "названия слов не повторяются")
    check(Set(terms.map(\.meaning)).count == terms.count,
          "и пояснения тоже")
    let pages = Tour.pages
    check(pages.count == 7, "в знакомстве семь страниц")
    check(pages.map(\.id) == Array(0 ..< pages.count),
          "страницы идут по порядку с нуля — по ним листает TabView")
    check(pages.allSatisfy { !$0.icon.isEmpty && !$0.title.isEmpty
                             && !$0.text.isEmpty },
          "у каждой страницы есть знак, заголовок и текст")
    // Названия не сверяются: «Замок» и «Пересадка» по-украински те же.
    let russian = terms.map(\.meaning) + pages.flatMap { [$0.title, $0.text] }
    let tongues = ((catalog.strings["Словарик"]?["localizations"]
                    as? [String: Any])?.keys).map { $0.sorted() } ?? []
    check(tongues.count == 47, "словарик переведён на все языки")
    defer { language = "ru" }
    for tongue in tongues {
        language = tongue
        let local = Term.allCases.map(\.meaning)
            + Tour.pages.flatMap { [$0.title, $0.text] }
        let same = zip(local, russian).filter { $0 == $1 }.map(\.0)
        check(same.isEmpty,
              "\(tongue): знакомство и словарик переведены \(same)")
    }
    language = "en"
    check(Lang.format("Что значит «%@»", "AR"), "What “AR” means",
          "английский: подпись у «?»")
    check(Term.wave.title, "Wave", "английский: слово из словарика")
}

print("статистика за период:")
do {
    let stretch = Season.stretch
    Season.stretch = 1
    defer { Season.stretch = stretch }
    var week = clock
    week.firstWeekday = 2
    func poured(_ plant: String, _ back: Int, _ hour: Int,
                left: Double?) -> Watering {
        Watering(plant: plant, when: day(back, hour), left: left)
    }
    let yard = [
        Room(name: "Спальня", plants: [
            plantNamed("Баксик", moisture: 0.9, dryingDays: 9),
            plantNamed("Борис", moisture: 0.08, dryingDays: 5),
        ]),
        Room(name: "Кухня", plants: [
            plantNamed("Мурзик", moisture: 0.3, dryingDays: 7),
        ]),
    ]
    let log = [
        poured("Баксик", 0, 9, left: 0.3),
        poured("Борис", 1, 19, left: 0.05),
        poured("Мурзик", 2, 19, left: 0),
        poured("Баксик", 3, 8, left: 0.55),
        poured("Борис", 6, 19, left: 0.25),
        poured("Мурзик", 7, 19, left: 0.3),
        poured("Баксик", 10, 10, left: nil),
        poured("Борис", 40, 10, left: 0.35),
        poured("Борис", 400, 10, left: 0.2),
    ]
    let book = Almanac.of(log, rooms: yard, period: .week, since: day(500),
                          now: noon, calendar: week)
    check(book.total == 5, "за неделю — семь дней с сегодняшним")
    check(book.previous == 2 && book.change == 3,
          "прошлая неделя — два полива, разница плюс три")
    check(book.active == 5 && book.length == 7, "пять дней с поливом из семи")
    check(book.bars.count == 7 && !book.byMonth, "неделя — семь столбиков")
    check(book.bars.first!.start < book.bars.last!.start
          && book.bars.last!.count == 1 && book.bars.first!.count == 1,
          "от старого к новому, с сегодняшним в конце")
    check(book.streak == 4 && book.best == 4,
          "череда — четыре дня подряд до сегодня")
    check(book.aim.count(.early) == 1 && book.aim.count(.onTime) == 2
          && book.aim.count(.lastMoment) == 1 && book.aim.count(.dry) == 1,
          "поливы по зонам тени: заранее, вовремя, в последний миг, досуха")
    check(round2(book.aim.share(.onTime)), "0.40", "вовремя — две пятых")
    check(round2(book.aim.typical ?? -1), "0.25",
          "обычно поливают при четверти воды — медиана")
    check(book.aim.usual == .onTime, "чаще всего — вовремя")
    check(book.aim.bins == [2, 0, 1, 1, 0, 1, 0, 0, 0, 0],
          "корзины по десять процентов")
    check(Almanac.Aim.zone(0.4) == .early && Almanac.Aim.zone(0.2) == .onTime
          && Almanac.Aim.zone(0.19) == .lastMoment
          && Almanac.Aim.zone(0.005) == .dry,
          "границы зон — как у тени карточки")
    check(Almanac.Aim([Watering(plant: "x", when: noon)]).known == 0,
          "записи без остатка воды в точность не идут")
    check(book.peakHour == 19 && book.hours[19] == 3,
          "чаще всего поливают в семь вечера")
    check(book.cells.last?.day == week.startOfDay(for: noon)
          && book.cells.last?.count == 1,
          "календарь кончается сегодняшним днём")
    check(week.component(.weekday, from: book.cells.first!.day) == 2,
          "и начинается с начала недели")
    check(book.cells.count > (Almanac.weeks - 1) * 7
          && book.cells.count <= Almanac.weeks * 7,
          "шестнадцать недель, текущая — не целиком")
    check(book.cells.reduce(0) { $0 + $1.count } == 8,
          "в календаре все поливы, кроме прошлогоднего")
    check(book.records.total == 9 && book.records.longest == 4,
          "рекорды — за всё время")
    check(book.records.busiest?.count == 1
          && book.records.busiest?.day == week.startOfDay(for: noon),
          "день с наибольшим числом поливов — последний из равных")
    check(book.records.earliest == 8 * 60 && book.records.latest == 19 * 60,
          "самый ранний полив — в восемь, самый поздний — в семь вечера")
    check(book.weekdays.first?.number == 2,
          "неделя с понедельника, если так в календаре")
    check(book.weekdays.map(\.count) == [0, 1, 1, 1, 1, 1, 0],
          "по дням недели — вторник…суббота")
    check(book.peakDay?.number == 3, "из равных — первый по порядку недели")
    check(book.rooms.map(\.name) == ["Спальня", "Кухня"]
          && book.rooms[0].waterings == 4 && book.rooms[1].waterings == 1,
          "комнаты — по нынешним жильцам")
    check(round2(book.rooms[0].moisture ?? -1), "0.49",
          "средняя влажность комнаты — сейчас")
    check(book.rooms[0].onTime == 0.5 && book.rooms[1].onTime == 0,
          "доля вовремя — по комнате")
    let baksik = book.plants.first { $0.id == "Баксик" }!
    check(baksik.waterings == 2 && baksik.total == 3 && baksik.due == 8
          && baksik.last == day(0, 9),
          "растение: за период, всего, срок и последний полив")
    check(abs((baksik.typical ?? -1) - 0.425) < 1e-9,
          "обычный остаток — по всем поливам с записью")
    check(book.now.calm == 1 && book.now.warn == 1 && book.now.alarm == 1,
          "сейчас: по одному в каждой зоне")
    check(book.now.driest == "Борис" && book.now.levels == [0.08, 0.3, 0.9],
          "самый сухой и полоска от сухого")
    check(round2(book.now.content), "0.33", "довольна треть")
    check(book.ahead.count == Almanac.horizon, "прогноз на две недели сада")
    check(book.ahead.map(\.count)
            == [1, 0, 1, 0, 0, 1, 0, 0, 1, 1, 1, 0, 0, 0],
          "прогноз: первый полив по карточке, дальше через срок")
    check(book.ahead[8].names == ["Баксик"], "в прогнозе — клички")

    let month = Almanac.of(log, rooms: yard, period: .month, since: day(500),
                           now: noon, calendar: week)
    check(month.total == 7 && month.previous == 1 && month.bars.count == 30,
          "месяц — тридцать дней по дням")
    let year = Almanac.of(log, rooms: yard, period: .year, since: day(500),
                          now: noon, calendar: week)
    check(year.byMonth && year.bars.count == 12 && year.total == 8,
          "год — двенадцать месяцев с текущим")
    check(year.bars.last!.count == 7 && year.bars[10].count == 1,
          "столбик месяца — все поливы месяца")
    let all = Almanac.of(log, rooms: yard, period: .all, since: day(500),
                         now: noon, calendar: week)
    check(all.byMonth && all.total == 9 && all.previous == nil,
          "всё время — по месяцам и без сравнения")
    let young = Almanac.of(Array(log.prefix(3)), rooms: yard, period: .all,
                           since: day(10), now: noon, calendar: week)
    check(!young.byMonth && young.bars.count == 11,
          "молодой сад — по дням, с первого дня")
    let empty = Almanac.of([], rooms: [], period: .week, since: day(3),
                           now: noon, calendar: week)
    check(empty.total == 0 && empty.peakHour == nil && empty.peakDay == nil
          && empty.now.average == nil && empty.tallest == 0,
          "пустой сад — без выдумок")

    let card = PlantBook.of(yard[0].plants[0], log: log, period: .week,
                            since: day(500), now: noon, calendar: week)
    check(card.total == 3 && card.inPeriod == 2 && card.last == day(0, 9),
          "растение в статистике: всего и за период")
    check(card.dues == [8, 17, 26], "три ближайших полива в днях сада")
    check(card.recent.map(\.when) == [day(3, 8), day(0, 9)],
          "поливы периода — от старого к новому")
}

print("планетарий:")
do {
    let stretch = Season.stretch
    Season.stretch = 1
    defer { Season.stretch = stretch }
    let sky = Orrery.orbits([
        plantNamed("Кактус", moisture: 0.5, dryingDays: 57),
        plantNamed("Борис", moisture: 0.5, dryingDays: 5),
        plantNamed("Алоэ", moisture: 0.5, dryingDays: 5),
        plantNamed("Баксик", moisture: 0.5, dryingDays: 9),
    ])
    check(sky.map(\.name) == ["Алоэ", "Борис", "Баксик", "Кактус"],
          "орбиты от быстрых к терпеливым, равные — по кличке")
    check(sky.first!.radius == Orrery.inner && sky.last!.radius == Orrery.outer,
          "ближняя и дальняя — по краям")
    check(sky.map(\.rank) == [0, 1, 2, 3], "номера по порядку")
    check(Orrery.angle(moisture: 1) == 0, "политая — на луче")
    check(abs(Orrery.angle(moisture: 0) - 2 * .pi) < 1e-9,
          "сухая — снова на луче, круг спустя")
    check(abs(Orrery.angle(moisture: 0.5) - .pi) < 1e-9,
          "половина воды — внизу")
    check(abs((Orrery.angle(moisture: 0.9) - Orrery.angle(moisture: 1))
              - (Orrery.angle(moisture: 0) - Orrery.angle(moisture: 0.1)))
              < 1e-9,
          "ход ровный: у луча не быстрее, чем внизу")
    let half = Orrery.Orbit(id: "x", name: "x", period: 10, moisture: 0.5,
                            radius: 0.5, rank: 0)
    let coming = Orrery.sky([half], ahead: 4.999)[0].angle
    let gone = Orrery.sky([half], ahead: 5.001)[0].angle
    check(2 * .pi - coming < 0.01 && gone < 0.01,
          "луч планета проходит в миг полива, не перескакивая")
    check(Spheres.notes(Orrery.crossings([half], within: 30), count: 1)
            .map { round2($0.at) } == ["3.33", "10.00", "16.67"],
          "нота — когда планета на луче")
    check(round2(Orrery.moisture(half, after: 3)), "0.20",
          "до сухой земли — сохнет по сроку")
    check(round2(Orrery.moisture(half, after: 5)), "1.00",
          "высохла — полили, снова полная")
    check(round2(Orrery.moisture(half, after: 7)), "0.80", "и сохнет заново")
    check(Orrery.crossings([half], within: 30).map(\.day) == [5, 15, 25],
          "поливы — когда высохнет, потом через срок")
    var dry = half
    dry.moisture = 0
    dry.period = 7
    check(Orrery.crossings([dry], within: 30).map(\.day) == [0, 7, 14, 21, 28],
          "сухую ждут уже сейчас")
    let crowd = Orrery.orbits([
        plantNamed("Раз", moisture: 0.4, dryingDays: 5),
        plantNamed("Два", moisture: 0.2, dryingDays: 10),
        plantNamed("Три", moisture: 0.1, dryingDays: 20),
        plantNamed("Четыре", moisture: 0.9, dryingDays: 30),
    ])
    let parades = Orrery.parades(crowd, within: 30)
    check(parades.first?.day == 2 && parades.first?.ids.count == 3,
          "парад — трое в один день")
    check(Set(parades.first?.names ?? []) == ["Раз", "Два", "Три"],
          "с кличками")
    check(Orrery.parades(crowd, within: 30, least: 5).isEmpty,
          "пятерых в один день не бывает")
}

print("музыка сфер:")
do {
    let top = Spheres.pitch(rank: 0, of: 5)
    let low = Spheres.pitch(rank: 4, of: 5)
    check(round2(low), "220.00", "дальняя орбита — ля малой октавы")
    check(top > 900 && top < 1_000, "ближняя — на две с лишним октавы выше")
    check((0 ..< 5).map { Spheres.pitch(rank: $0, of: 5) }
            == (0 ..< 5).map { Spheres.pitch(rank: $0, of: 5) }
                .sorted(by: >),
          "чем ближе орбита, тем выше")
    let notes = Spheres.notes([Orrery.Crossing(id: "x", day: 15, rank: 0)],
                              count: 1)
    check(round2(notes.first?.at ?? -1), "10.00",
          "середина месяца — на десятой секунде")
    let sound = Spheres.render([Spheres.Note(at: 1, pitch: 440)])
    let second = Spheres.rate * Spheres.channels
    let length = Int((Spheres.seconds + Spheres.tail) * Double(Spheres.rate))
        * Spheres.channels
    check(sound.count == length, "длина — месяц и хвост, оба канала")
    check(sound.prefix(second).allSatisfy { $0 == 0 },
          "до первой ноты тишина")
    let ring = sound[second ..< second + second / 10]
    check(ring.contains { abs($0) > 0.3 }, "нота звучит")
    check(sound.allSatisfy { abs($0) <= 0.91 }, "громкость с запасом")
    check(abs(sound.last ?? 1) < 0.001, "к концу — стихает, без щелчка")
    let crowd = (0 ..< 12).map {
        Spheres.Note(at: 2, pitch: Spheres.pitch(rank: $0, of: 12))
    }
    check(Spheres.render(crowd).allSatisfy { abs($0) <= 0.91 },
          "плотный парад не зашкаливает")
    let wide = Spheres.render([Spheres.Note(at: 1, pitch: 440, pan: -1)])
    let heard = wide[second ..< second + second / 10]
    let left = stride(from: heard.startIndex, to: heard.endIndex, by: 2)
        .map { abs(heard[$0]) }.max() ?? 0
    let right = stride(from: heard.startIndex + 1, to: heard.endIndex, by: 2)
        .map { abs(heard[$0]) }.max() ?? 0
    check(left > 0.3 && right < left / 4, "нота слева — в левом канале")
    let file = Spheres.wav(sound)
    check(file.count == 44 + 2 * sound.count, "WAV: заголовок и 16 бит")
    check(String(decoding: file.prefix(4), as: UTF8.self) == "RIFF"
          && String(decoding: file[8 ..< 12], as: UTF8.self) == "WAVE",
          "WAV: метки на месте")
    check(file[22] == UInt8(Spheres.channels) && file[23] == 0,
          "WAV: стерео")
}

print("подсказки экранов:")
do {
    let all = Walk.allCases.flatMap(\.hints)
    check(Walk.allCases.allSatisfy { !$0.hints.isEmpty },
          "у каждого экрана есть подсказки")
    check(all.allSatisfy { !$0.title.isEmpty && !$0.text.isEmpty },
          "у каждой — заголовок и текст")
    check(all.count == Hint.Target.allCases.count
          && Set(all.map(\.target)).count == all.count,
          "каждое место подсвечивается ровно одной подсказкой")
    check(all.allSatisfy { $0.target.rawValue.contains(".") },
          "имя места — «экран.место»")
    let russian = all.map(\.text)
    let tongues = ((catalog.strings["Словарик"]?["localizations"]
                    as? [String: Any])?.keys).map { $0.sorted() } ?? []
    defer { language = "ru" }
    for tongue in tongues {
        language = tongue
        let local = Walk.allCases.flatMap(\.hints).map(\.text)
        let same = zip(local, russian).filter { $0 == $1 }.map(\.0)
        check(same.isEmpty, "\(tongue): подсказки переведены \(same)")
    }
}

print("уезжаю:")
do {
    let rooms = [Room(name: "Кухня", plants: [
        plantNamed("папоротник", moisture: 0.2, dryingDays: 5),
        plantNamed("кактус", moisture: 0.9, dryingDays: 30),
        plantNamed("фикус", moisture: 0.5, dryingDays: 8),
    ])]
    let needs = Trip.needs(in: rooms, days: 12)
    check(needs.map(\.plant.id) == ["папоротник", "фикус"],
          "соседу — те, кто не дождётся, от самого быстрого")
    check(needs[0].visits == [4, 8], "папоротник: полить на 4-й и 8-й день")
    check(needs[1].visits == [7], "фикус: на 7-й")
    check(needs.allSatisfy { need in
        let stops = [0] + need.visits + [12]
        return zip(stops, stops.dropFirst()).allSatisfy {
            Double($1 - $0) <= need.dries }
    }, "ни одно растение не остаётся без воды дольше своего срока")
    check(Trip.fine(in: rooms, days: 12).map(\.id) == ["кактус"],
          "кактус дождётся сам")
    check(Trip.needs(in: rooms, days: 3).isEmpty, "на три дня — никого")
    let leave = Date(timeIntervalSince1970: 1_750_000_000)
    let back = Calendar.current.date(byAdding: .day, value: 12, to: leave)!
    check(Trip.days(from: leave, to: back) == 12, "дни поездки — по календарю")
    let memo = Trip.memo(needs, leave: leave, back: back)
    check(memo.contains("папоротник") && memo.contains("фикус")
          && !memo.contains("кактус"),
          "в памятке — только те, кого надо полить")
    check(Trip.memo([], leave: leave, back: back).contains("поливать никого"),
          "никого — так и написано")

    var utc = Calendar(identifier: .gregorian)
    utc.timeZone = TimeZone(identifier: "UTC")!
    func at(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        utc.date(from: DateComponents(year: 2026, month: 9, day: day,
                                      hour: hour, minute: minute))!
    }
    check(Trip.departure(after: at(25, 14, 37), calendar: utc) == at(26, 15),
          "уезжают по умолчанию завтра, в начале следующего часа")
    check(Trip.countdownStart(to: at(25, 21), now: at(25, 14)) == at(25, 14),
          "за семь часов до отъезда отсчёт начинается сразу")
    check(Trip.countdownStart(to: at(26, 9), now: at(25, 14)) == at(26, 1),
          "за девятнадцать — за восемь часов до отъезда: раньше погас бы")
    check(Trip.countdownStart(to: at(25, 13), now: at(25, 14)) == nil,
          "уехавшему отсчитывать нечего")
    let now = at(25, 20)
    let fresh = rooms.flatMap(\.plants).map {
        Watering(plant: $0.id, when: at(25, 9))
    }
    check(Trip.watered(rooms, log: fresh, now: now),
          "все политы утром — к вечернему отъезду готовы")
    check(!Trip.watered(rooms, log: Array(fresh.dropLast()), now: now),
          "одного не полили — не готовы")
    check(!Trip.watered(rooms, log: fresh, now: at(26, 10)),
          "полив суточной давности — уже не перед отъездом")
    check(Trip.firstVisit(needs, leave: at(25, 20), calendar: utc) == at(29, 0),
          "сосед придёт впервые на четвёртый день, в полночь дня")
    check(Trip.firstVisit([], leave: at(25, 20), calendar: utc) == nil,
          "соседу никого — и приходить незачем")
}

print("обход сада:")
do {
    let rooms = [
        Room(name: "Кухня", plants: [
            plantNamed("папоротник", moisture: 0.15, dryingDays: 5),
            plantNamed("кактус", moisture: 0.9, dryingDays: 30),
        ]),
        Room(name: "Спальня", plants: [
            plantNamed("фикус", moisture: 0.35, dryingDays: 8),
            plantNamed("фиалка", moisture: 0.05, dryingDays: 4),
        ]),
    ]
    let stops = Round.stops(in: rooms) { "\($0.id).jpg" }
    check(stops.map(\.id) == ["фиалка", "папоротник", "фикус"],
          "в обходе — кто просит воды, от самого сухого")
    check(stops.map(\.room) == ["Спальня", "Кухня", "Спальня"],
          "у каждого — своя комната")
    check(stops[0].percent == 5 && stops[0].thumb == "фиалка.jpg",
          "проценты и картинка — с начала обхода")
    let many = [Room(name: "Зал", plants: (0 ..< 20).map {
        plantNamed("растение \($0)", moisture: 0.01 * Double($0),
                   dryingDays: 5)
    })]
    check(Round.stops(in: many).count == Round.limit,
          "больше дюжины в обход не берём")
    let long = String(repeating: "о", count: 50)
    check(Round.clip(long).count == Round.nameLimit
          && Round.clip(long).hasSuffix("…"),
          "длинное имя режется многоточием")
    check(Round.clip("Баксик") == "Баксик", "короткое — как есть")

    let start = Date(timeIntervalSince1970: 1_790_000_000)
    let alive = Set(rooms.flatMap(\.plants).map(\.id))
    var log = [Watering(plant: "фиалка", when: start.addingTimeInterval(-60))]
    var marked = Round.mark(stops, log: log, since: start, alive: alive)
    check(Round.passed(marked) == 0,
          "полив до начала обхода — не полив обхода")
    log.append(Watering(plant: "фиалка", when: start.addingTimeInterval(60)))
    marked = Round.mark(marked, log: log, since: start, alive: alive)
    check(marked[0].mark == .watered && Round.next(marked)?.id == "папоротник",
          "полили первого — следующий на очереди")
    marked = Round.skip("папоротник", in: marked)
    check(marked[1].mark == .skipped && Round.next(marked)?.id == "фикус",
          "пропустили — дальше, не поливая")
    check(Round.passed(marked) == 2 && Round.watered(marked) == 1,
          "пройдено двое, полит один")
    log.append(Watering(plant: "папоротник", when: start.addingTimeInterval(90)))
    marked = Round.mark(marked, log: log, since: start, alive: alive)
    check(marked[1].mark == .watered,
          "пропущенного полили с экрана растения — полит")
    marked = Round.mark(marked, log: Array(log.dropLast()), since: start,
                        alive: alive)
    check(marked[1].mark == .waiting, "полив отменили — снова ждёт")
    marked = Round.mark(marked, log: log, since: start,
                        alive: alive.subtracting(["фикус"]))
    check(marked[2].mark == .skipped && Round.next(marked) == nil,
          "растение убрали из сада — пропущено, обход пройден")

    func crowd(_ letter: String) -> [Round.Stop] {
        Round.stops(in: [Room(
            name: String(repeating: letter, count: 40),
            plants: (0 ..< 12).map { _ in
                Plant(id: UUID().uuidString,
                      name: String(repeating: letter, count: 40),
                      species: "x", moisture: 0.1, dryingDays: 5,
                      addedOn: DateComponents(year: 2024, month: 1, day: 1))
            })]) { _ in String(repeating: "f", count: 16) + ".jpg" }
    }
    let plain = crowd("я")
    check(plain.count == Round.limit && Round.weight(plain) <= Round.budget,
          "дюжина длинных русских имён влезает: \(Round.weight(plain)) байт")
    let heavy = crowd("🌵")
    check(!heavy.isEmpty && heavy.count < Round.limit
          && Round.weight(heavy) <= Round.budget,
          "имена из эмодзи тяжелее — остановок меньше, но в пределах: "
          + "\(heavy.count), \(Round.weight(heavy)) байт")
    let back = try? JSONDecoder().decode([Round.Stop].self,
                                         from: JSONEncoder().encode(marked))
    check(back == marked, "остановки обхода переживают упаковку")
}

print("кошкам и собакам:")
do {
    func harm(_ species: String) -> String {
        Toxicity.of(species).map { "\($0)" } ?? "—"
    }
    check(harm("Монстера"), "toxic", "монстера ядовита")
    check(harm("Фаленопсис"), "safe", "орхидея безопасна")
    check(harm("Лилия"), "lily", "лилия — смертельно для кошек")
    check(harm("Спатифиллум (лилия мира)"), "toxic",
          "спатифиллум — не лилия, хоть и зовётся")
    check(harm("Calla lily"), "toxic", "калла — не лилия")
    check(harm("Бамбук"), "toxic", "бамбук в горшке — драцена")
    check(harm("Нолина"), "safe", "нолина безопасна, хоть модель — юкка")
    check(harm("Саговая пальма"), "deadly", "саговник смертелен, хоть и пальма")
    check(harm("Пальма хамедорея"), "safe", "хамедорея безопасна")
    check(harm("Роза пустыни"), "toxic", "адениум — не роза")
    check(harm("Роза"), "safe", "роза безопасна")
    check(harm("Восковой плющ"), "safe", "хойя — не плющ")
    check(harm("Плющ"), "toxic", "плющ ядовит")
    check(harm("Альпийская фиалка"), "toxic", "цикламен — не фиалка")
    check(harm("Фиалка"), "safe", "фиалка безопасна")
    check(harm("Гербера"), "safe", "гербера безопасна, хоть модель — хризантема")
    check(harm("Цветущий кактус"), "safe", "общее слово не прячет вид")
    check(harm("Кустик мяты"), "toxic", "мята ядовита")
    check(harm("Зелень"), "—", "зелень — неизвестно, молчим")
    check(harm("Цветок"), "—", "цветок — неизвестно")
    check(harm("Суккулент"), "—", "суккулент бывает всякий")
    check(harm("Пряные травы"), "—", "травы — всякие")
    check(harm("Кошачья трава"), "safe", "кошачья трава — для кошек")
    check(harm("Базилик"), "safe", "базилик безопасен")
    check(harm("Snake plant"), "toxic", "сансевиерия по-английски")
    check(harm("Кракозябра"), "—", "незнакомое — молчим")
    check(Preset.allCases.filter { $0.toxicity == nil } == [.herbs],
          "у каждой модели, кроме трав, ответ есть")
    check(Toxicity.lily.line == "Смертельно опасно для кошек",
          "строка про лилию")
}

print("узор по времени года:")
do {
    func motif(_ month: Int, _ day: Int, _ side: Season.Side) -> String {
        "\(Season.motif(month: month, day: day, side: side))"
    }
    check(motif(12, 20, .north), "garland", "гирлянда — с 20 декабря")
    check(motif(1, 10, .north), "garland", "и по 10 января")
    check(motif(12, 19, .north), "snow", "до неё — снежинки")
    check(motif(1, 11, .north), "snow", "после неё — снова снежинки")
    check(motif(2, 28, .north), "snow", "февраль — снежинки")
    check(motif(3, 1, .north), "plain", "весной узор обычный")
    check(motif(7, 15, .north), "plain", "летом тоже")
    check(motif(9, 1, .north), "leaves", "сентябрь — кленовые листья")
    check(motif(11, 30, .north), "leaves", "ноябрь — листья")
    check(motif(7, 1, .south), "snow", "на юге июль — зима")
    check(motif(4, 15, .south), "leaves", "а апрель — осень")
    check(motif(12, 31, .south), "garland", "Новый год на юге — тоже гирлянда")
    check(motif(1, 20, .south), "plain", "январь на юге — лето")
    check(motif(1, 20, .tropics), "plain", "у экватора ни снега")
    check(motif(10, 20, .tropics), "plain", "ни листопада")
    check(motif(12, 25, .tropics), "garland", "а гирлянда есть")
    check("\(Motif.snow.dress([0, 1]))", "[0, 1, 4]",
          "зимой к выбранному добавляется снежинка")
    check("\(Motif.leaves.dress([3, 2]))", "[2, 3, 5]",
          "осенью — клён, набор по порядку")
    check("\(Motif.garland.dress([0]))", "[0, 1]",
          "гирлянде нужны капли — добавляются")
    check("\(Motif.garland.dress([0, 1]))", "[0, 1]",
          "капли уже есть — набор тот же")
    check("\(Motif.plain.dress([2]))", "[2]", "без времени года — как выбрано")
    let festive = Festive()
    var winter = DateComponents()
    winter.year = 2026
    winter.month = 2
    winter.day = 3
    winter.hour = 12
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    let february = calendar.date(from: winter)!
    let first = festive.settle(on: true, now: february, region: "RU",
                               calendar: calendar)
    check(first.map { "\($0)" } ?? "—", "plain",
          "первая установка отвечает прежним узором")
    check("\(festive.motif)", "snow", "в феврале в России — снежинки")
    check(festive.settle(on: true, now: february, region: "RU",
                         calendar: calendar) == nil,
          "тот же день — ничего не меняется")
    check("\(festive.settle(on: true, now: february, region: "AU", calendar: calendar).map { "\($0)" } ?? "—")",
          "snow", "в Австралии февраль — лето: прежние снежинки уходят")
    check("\(festive.motif)", "plain", "и узор обычный")
    festive.settle(on: false, now: february, region: "RU", calendar: calendar)
    check("\(festive.motif)", "plain", "выключено — узор обычный круглый год")
}

print("сроки в календаре:")
do {
    var utc = Calendar(identifier: .gregorian)
    utc.timeZone = TimeZone(identifier: "UTC")!
    let noon = utc.date(from: DateComponents(year: 2026, month: 5, day: 10,
                                             hour: 12))!
    func day(_ number: Int) -> Date {
        utc.date(from: DateComponents(year: 2026, month: 5, day: number))!
    }
    let stretch = Season.stretch, growing = Season.growing
    Season.stretch = 1
    Season.growing = true
    // Шесть дней сада — двое настоящих суток: сад идёт втрое быстрее.
    var baksik = Plant.new(name: "Баксик", species: "Монстера",
                           dryingDays: 6, id: "b", on: noon, calendar: utc)
    baksik.moisture = 0.5
    baksik.care = Care()
    var lera = Plant.new(name: "Лера", species: "Фикус", dryingDays: 6,
                         id: "l", on: noon, calendar: utc)
    lera.moisture = 0.5
    lera.care = Care(feedEvery: 30, sinceFed: 27)
    // Полтора дня сада — двенадцать часов: два полива в сутки.
    var prickly = Plant.new(name: "Колючка", species: "Кактус",
                            dryingDays: 1.5, id: "k", on: noon, calendar: utc)
    prickly.moisture = 0
    var still = Plant.new(name: "Камень", species: "Литопс", dryingDays: 0,
                          id: "s", on: noon, calendar: utc)
    still.moisture = 0.5
    let rooms = [Room(name: "Гостиная", plants: [baksik, lera]),
                 Room(name: "Кухня", plants: [prickly, still])]
    let plan = Agenda.plan(rooms, now: noon, horizon: 7, calendar: utc)
    let water = plan.filter { $0.chore == .water }
    let feed = plan.filter { $0.chore == .feed }
    check("\(water.count)", "7", "полив — событие на каждый день недели")
    check("\(feed.count)", "1", "подкормка — одна, через сутки")
    check(water.first?.day == day(10), "сухая колючка — сегодня")
    check(water.first?.pots.map(\.name) == ["Колючка"],
          "а больше сегодня никого")
    let second = water.first { $0.day == day(11) }
    check(second?.title ?? "—", "Полить: Баксик, Лера, Колючка",
          "половина из шести дней сада — завтра, в порядке сада")
    check(second?.notes ?? "—", "Гостиная: Баксик, Лера\nКухня: Колючка",
          "в заметке — по строке на комнату")
    check(feed.first?.title ?? "—", "Подкормить: Лера",
          "подкормка в тот же день отдельным событием")
    check(water.allSatisfy { entry in
        Set(entry.pots.map(\.id)).count == entry.pots.count
    }, "два полива за сутки — одна строка")
    check(water.filter { $0.pots.contains { $0.name == "Баксик" } }
        .map(\.day) == [day(11), day(13), day(15)],
          "дальше — через двое суток, пока не кончится неделя")
    check(!plan.contains { $0.pots.contains { $0.name == "Камень" } },
          "без срока в календаре не бывает")
    Season.growing = false
    check(!Agenda.plan(rooms, now: noon, horizon: 7, calendar: utc)
        .contains { $0.chore == .feed }, "зимой подкормки в календаре нет")
    Season.stretch = stretch
    Season.growing = growing
}

print("награды:")
do {
    var utc = Calendar(identifier: .gregorian)
    utc.timeZone = TimeZone(identifier: "UTC")!
    func at(_ day: Int, _ hour: Int, month: Int = 3) -> Date {
        utc.date(from: DateComponents(year: 2026, month: month, day: day,
                                      hour: hour))!
    }
    let stretch = Season.stretch
    Season.stretch = 1
    let since = at(1, 0)
    // Неделя подряд, каждый день в полдень, вовремя — 30% воды.
    var log = (1 ... 7).map { Watering(plant: "a", when: at($0, 12), left: 0.3) }
    var trophies = Trophies.of(log, rooms: [], since: since, now: at(8, 12),
                               calendar: utc)
    check(trophies.reached[.firstDrop] == at(1, 12), "первая капля — с первым поливом")
    check(trophies.reached[.week] == at(7, 12), "неделя подряд — на седьмой день")
    check(trophies.reached[.tenDrops] == nil, "до десяти поливов далеко")
    check("\(trophies.count(.tenDrops))", "7", "набрано семь из десяти")
    check("\(trophies.count(.bullseye))", "7", "семь поливов вовремя подряд")
    check(trophies.reached[.earlyBird] == nil, "в полдень — не жаворонок")
    // Пропуск дня рвёт череду, поздний полив — серию вовремя.
    log.append(Watering(plant: "a", when: at(9, 12), left: 0.1))
    log += (10 ... 19).map { Watering(plant: "a", when: at($0, 12), left: 0.25) }
    trophies = Trophies.of(log, rooms: [], since: since, now: at(20, 12),
                           calendar: utc)
    check(trophies.reached[.tenDrops] == at(11, 12), "десятый полив — одиннадцатого")
    check(trophies.reached[.bullseye] == at(19, 12),
          "десять вовремя подряд — считая после позднего полива")
    check("\(trophies.count(.week))", "7", "череда длиннее цели — полная полоска")
    check(trophies.reached[.month] == nil, "месяца подряд ещё нет")
    // Особые дни.
    let dawn = [Watering(plant: "a", when: at(3, 5), left: 0.5)]
    check(Trophies.of(dawn, rooms: [], since: since, now: at(4, 12),
                      calendar: utc).reached[.earlyBird] == at(3, 5),
          "полив в пять утра — жаворонок")
    let night = [Watering(plant: "a", when: at(3, 2), left: 0.5)]
    check(Trophies.of(night, rooms: [], since: since, now: at(4, 12),
                      calendar: utc).reached[.nightOwl] == at(3, 2),
          "полив в два ночи — сова")
    let eve = [Watering(plant: "a", when: at(31, 23, month: 12), left: 0.5)]
    check(Trophies.of(eve, rooms: [], since: since,
                      now: at(31, 23, month: 12),
                      calendar: utc).reached[.newYear] != nil,
          "полив 31 декабря — с Новым годом")
    // Месяц без засухи: полив досуха 10 марта — отсчёт заново.
    let dry = [Watering(plant: "a", when: at(10, 12), left: 0)]
    let april = at(15, 12, month: 4)
    let clean = Trophies.of(dry, rooms: [], since: since, now: april,
                            calendar: utc)
    check(clean.reached[.noDrought] == at(9, 12, month: 4),
          "тридцать дней после засухи — девятого апреля")
    check("\(clean.count(.noDrought))", "30", "полоска полная")
    // Растение сухое сейчас: высохло через срок после последнего полива.
    var parched = Plant.new(name: "Сухарик", species: "Фикус", dryingDays: 3,
                            id: "d", on: since, calendar: utc)
    parched.moisture = 0
    let water = dry + [Watering(plant: "d", when: at(1, 12, month: 4), left: 0.3)]
    let thirsty = Trophies.of(water, rooms: [Room(name: "Кухня", plants: [parched])],
                              since: since, now: april, calendar: utc)
    check(thirsty.reached[.noDrought] == nil,
          "сухое растение сбивает отсчёт — месяца нет")
    check("\(thirsty.count(.noDrought))", "13",
          "высохло второго апреля: тринадцать дней без засухи")
    // Сад: десять растений и пять видов.
    let kinds = ["Монстера", "Кактус", "Фикус", "Орхидея", "Алоэ"]
    let plants = (0 ..< 10).map { index in
        Plant.new(name: "Р\(index)", species: kinds[index % 5],
                  dryingDays: 7, id: "p\(index)", on: since, calendar: utc)
    }
    let garden = Trophies.of([], rooms: [Room(name: "Зал", plants: plants)],
                             since: since, now: april, calendar: utc)
    check(garden.reached[.jungle] == april, "десять растений — джунгли")
    check(garden.reached[.botanist] == april, "пять видов — ботаник")
    let small = Trophies.of([], rooms: [Room(name: "Зал",
                                             plants: Array(plants.prefix(4)))],
                            since: since, now: april, calendar: utc)
    check(small.reached[.botanist] == nil && small.count(.botanist) == 4,
          "четыре вида — ещё не ботаник")
    Season.stretch = stretch

    // Полка: первая сверка молча, дальше — праздник.
    let shelf = UserDefaults(suiteName: "sprout-awards-check")!
    shelf.removePersistentDomain(forName: "sprout-awards-check")
    let cabinet = Cabinet(store: shelf)
    cabinet.review(Trophies.of(Array(log.prefix(3)), rooms: [], since: since,
                               now: at(4, 12), calendar: utc))
    check(cabinet.has(.firstDrop), "первая капля на полке")
    check(cabinet.fresh.isEmpty, "первая сверка — без праздника")
    cabinet.review(trophies)
    check(cabinet.fresh.contains(.tenDrops) && cabinet.fresh.contains(.week),
          "новые награды ждут праздника")
    check(!cabinet.fresh.contains(.firstDrop), "старая второй раз не празднуется")
    cabinet.deed(.feeder)
    cabinet.deed(.feeder)
    check(cabinet.fresh.filter { $0 == .feeder }.count == 1,
          "подкормка — одна награда, сколько ни подкармливай")
    cabinet.shown(.tenDrops)
    check(!cabinet.fresh.contains(.tenDrops), "показанная уходит из очереди")
    let reopened = Cabinet(store: shelf)
    check(reopened.has(.tenDrops) && reopened.has(.feeder),
          "полка переживает перезапуск")
    check(reopened.earned[.tenDrops] == at(11, 12),
          "дата — когда условие выполнилось, а не когда заметили")
    cabinet.review(Trophies.of([], rooms: [], since: since, now: april,
                               calendar: utc))
    check(cabinet.has(.week), "награды не отбираются")
    shelf.removePersistentDomain(forName: "sprout-awards-check")

    // Медаль: барельеф вида, прозрачные углы, металл ярче стали.
    let size = 64
    let kit = Botany.grow(.stock(.cactus), species: "Кактус")
    let relief = Emboss.relief(kit, size: size)
    let covered = relief.filter { $0 > 0 }
    check(!covered.isEmpty, "барельеф есть")
    check(covered.allSatisfy { $0 >= 0.35 && $0 <= 1 },
          "высоты барельефа — от 0.35 до 1")
    let share = Double(covered.count) / Double(size * size)
    check(share > 0.05 && share < 0.4, "растение занимает поле, а не всю медаль")
    var columns: [Int] = []
    for (index, value) in relief.enumerated() where value > 0 {
        columns.append(index % size)
    }
    let middle = Double(columns.min()! + columns.max()!) / 2
    check(abs(middle - Double(size) / 2) < 3, "растение по середине медали")
    let medal = Emboss.medal(relief, size: size, alloy: .gold)
    check(medal.ink(at: 0, 0).w == 0, "угол картинки прозрачный")
    check(medal.ink(at: size / 2, size / 2).w == 1, "середина медали непрозрачная")
    let steel = Emboss.medal(relief, size: size, alloy: .gold, earned: false)
    func warmth(_ picture: Picture) -> Float {
        let ink = picture.ink(at: size / 2, size * 3 / 4)
        return ink.x - ink.z
    }
    check(warmth(medal) > warmth(steel) + 0.1, "золото теплее стали")
    check(Emboss.flipped(Emboss.flipped(relief, size: size), size: size) == relief,
          "переворот дважды — как было")
    let normals = Emboss.normals(relief, size: size)
    let flat = normals.ink(at: 1, 1)
    check(abs(flat.x - 0.5) < 0.01 && abs(flat.y - 0.5) < 0.01 && flat.z > 0.99,
          "поле без барельефа — ровная нормаль")
    check(Award.Group.allCases.flatMap(\.awards).count == Award.allCases.count,
          "каждая награда — в своей группе")
}

print("итоги года:")
do {
    var utc = Calendar(identifier: .gregorian)
    utc.timeZone = TimeZone(identifier: "UTC")!
    func at(_ month: Int, _ day: Int, _ hour: Int, year: Int = 2026) -> Date {
        utc.date(from: DateComponents(year: year, month: month, day: day,
                                      hour: hour))!
    }
    let baksik = Plant.new(name: "Баксик", species: "Монстера", dryingDays: 7,
                           id: "a", on: at(1, 5, 12), calendar: utc)
    let lera = Plant.new(name: "Лера", species: "Фикус", dryingDays: 7,
                         id: "b", on: at(2, 1, 12), calendar: utc)
    let kesha = Plant.new(name: "Кеша", species: "Кактус", dryingDays: 20,
                          id: "c", on: at(3, 1, 12), calendar: utc)
    let old = Plant.new(name: "Дед", species: "Фикус", dryingDays: 9,
                        id: "d", on: at(6, 1, 12, year: 2025), calendar: utc)
    let rooms = [Room(name: "Зал", plants: [baksik, lera, kesha, old])]
    var log = [Watering(plant: "a", when: at(12, 31, 8, year: 2025), left: 0.3)]
    log += (10 ... 14).map { Watering(plant: "a", when: at(1, $0, 8), left: 0.3) }
    log += [
        Watering(plant: "b", when: at(3, 3, 8), left: 0.5),
        Watering(plant: "b", when: at(3, 4, 8), left: 0.5),
        Watering(plant: "c", when: at(3, 5, 21), left: 0.1),
        Watering(plant: "a", when: at(3, 6, 8), left: 0.3),
        Watering(plant: "x", when: at(3, 7, 13)),
    ]
    let recap = Recap.of(log, rooms: rooms,
                         awards: [.firstDrop: at(1, 10, 8),
                                  .week: at(12, 31, 8, year: 2025)],
                         year: 2026, now: at(9, 25, 12), calendar: utc)
    check("\(recap.waterings)", "10", "поливы года — без прошлогоднего")
    check("\(recap.days)", "10", "десять дней с поливом")
    check("\(recap.streak)", "5", "самая длинная череда за год — пять дней")
    check(recap.favorite?.name ?? "—", "Баксик", "любимчик — кого поливали чаще")
    check("\(recap.favorite?.count ?? 0)", "6", "шесть поливов любимчика")
    check(recap.podium.map(\.name) == ["Баксик", "Лера", "Кеша"],
          "пьедестал — по числу поливов; ушедшего растения нет")
    check("\(recap.peakHour ?? -1)", "8", "чаще всего — в восемь утра")
    check(recap.persona == .lark, "восемь утра — жаворонок")
    check(round2(recap.onTime ?? 0), "0.67",
          "вовремя — шесть из девяти, где известен остаток")
    check("\(recap.bestMonth ?? -1)", "0", "поровну — первый из лучших месяцев")
    check("\(recap.added)", "3", "добавлены в этом году — трое")
    check("\(recap.plants)", "4", "в саду — четверо")
    check(recap.awards == [.firstDrop], "награды года — без прошлогодних")
    check(recap.lit.contains(9) && !recap.lit.contains(8),
          "десятое января — десятый день года")
    check("\(recap.length)", "365", "2026 — не високосный")
    check(recap.deck == [.intro, .waterings, .favorite, .podium, .streak,
                         .rhythm, .aim, .months, .garden, .awards, .outro],
          "все слайды, когда есть о чём рассказать")
    let blank = Recap.of([], rooms: rooms, awards: [:], year: 2026,
                         now: at(9, 25, 12), calendar: utc)
    check(blank.deck == [.intro, .garden, .outro],
          "пустой год — вступление, сад и прощание")
    check(Recap.Persona(hour: 23) == .owl && Recap.Persona(hour: 2) == .owl,
          "ночью — сова")
    check(Recap.Persona(hour: 13) == .day && Recap.Persona(hour: 19) == .evening,
          "днём — дневной, вечером — вечерний")
    let notes = recap.melody()
    check("\(notes.count)", "26", "такт на месяц: два полных и десять по ноте")
    check(notes.allSatisfy { $0.at >= 0 && $0.at < Recap.length() },
          "все ноты — внутри мелодии")
    check(notes.allSatisfy { $0.pitch >= 220 && $0.pitch < 1_800 },
          "ноты — в мягком регистре шкатулки")
    let sound = Spheres.render(notes, seconds: Recap.length())
    let loud = sound.map { abs($0) }.max() ?? 0
    check(loud > 0.05 && loud <= 1, "мелодия звучит и не хрипит")
    check("\(sound.count)",
          "\(Int((Recap.length() + Spheres.tail) * Double(Spheres.rate)) * 2)",
          "длина — такты и хвост зала, стерео")
}

print("другие языки:")
do {
    defer { language = "ru" }
    language = "en"
    check(Lang.format("%lld растений", 1), "1 plant", "английский: одно")
    check(Lang.format("%lld растений", 5), "5 plants", "английский: много")
    check(Plant.wateringLabel(days: 2), "Next watering: in 2 days",
          "английский: срок полива")
    check(Species.periodLabel(1), "Every 1 day", "английский: барабан")
    check(Bench.preparing(0.5), "Preparing model: 50%",
          "английский: модель готовится")
    language = "pl"
    check(Lang.format("%lld растений", 2), "2 rośliny", "польский: few")
    check(Lang.format("%lld растений", 5), "5 roślin", "польский: many")
    check(Lang.format("%lld растений", 22), "22 rośliny", "польский: 22")
    language = "cs"
    check(Lang.format("%lld растений", 3), "3 rostliny", "чешский: few")
    check(Lang.format("%lld растений", 7), "7 rostlin", "чешский: other")
    language = "ar"
    check(Lang.format("%lld растений", 2), "2 نبتتان", "арабский: два")
    check(Lang.format("%lld растений", 7), "7 نبتات", "арабский: few")
    check(Lang.format("%lld растений", 11), "11 نبتة", "арабский: many")
    language = "ja"
    check(Lang.format("%lld растений", 3), "3株", "японский: одна форма")
    language = "tr"
    check(Lang.format("%lld%%", 50), "%50", "турецкий: знак процента впереди")
    language = "de"
    check(Lang.format("%lld%%", 50), "50\u{00A0}%", "немецкий: неразрывный пробел")
    language = "fr"
    check(Seed.dueLine([]), "Aucune plante à arroser aujourd’hui.",
          "французский: Siri")
}

if failed > 0 {
    print("\nне сошлось: \(failed)")
    exit(1)
}
print("\nвсё сошлось")
