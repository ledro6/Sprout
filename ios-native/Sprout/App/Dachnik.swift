import CoreLocation
import Foundation
import Observation
import UserNotifications
import WeatherKit

/// Дача: место, напоминание по приезде и дождь на участке. Арифметика — в
/// `Dacha`.
///
/// Место узнаётся один раз — когда хозяин сам нажимает «Отметить дачу
/// здесь», — и только точное: с примерной геопозицией iOS геозоны не ведёт,
/// и напоминание не пришло бы. О приезде узнаёт сама система — уведомление
/// по геозоне, `UNLocationNotificationTrigger`: приложению не нужны ни
/// «Всегда», ни работа в фоне, хватает «при использовании». Дождь — через
/// WeatherKit, как погода за окном (`Weatherman`); без WeatherKit дождевая
/// часть молчит, остальное работает.
@MainActor
@Observable
final class Dachnik: NSObject {
    static let shared = Dachnik()

    /// Что приложению можно с геопозицией.
    enum Access: Equatable {
        /// Ещё не спрашивали — спросим по нажатию.
        case unasked
        /// Запрещено — разрешают только в Настройках.
        case denied
        /// Только примерно: ни отметить дачу, ни заметить приезд.
        case approximate
        case fine
    }

    private(set) var spot: Dacha.Spot?
    private(set) var access = Access.unasked
    /// Место узнаётся прямо сейчас.
    private(set) var locating = false
    /// Место не далось или вышло слишком грубым.
    private(set) var missed = false
    /// Дождь на даче — пусто, пока погода там ни разу не пришла.
    private(set) var rain: Dacha.Rainfall?

    /// «Напоминать о дачных растениях только на даче».
    var only = false {
        didSet { store.set(only, forKey: Key.only) }
    }

    @ObservationIgnored private var manager: CLLocationManager?
    /// Разрешение спросили по нажатию «Отметить» — как придёт ответ, сразу
    /// узнаём место.
    @ObservationIgnored private var asking = false
    @ObservationIgnored private var raining = false
    /// Неудачная попытка узнать погоду — не повторять её на каждом
    /// возвращении.
    @ObservationIgnored private var tried: Date?
    @ObservationIgnored private let store = UserDefaults.standard

    private enum Key {
        static let spot = "dachaSpot"
        static let only = "dachaOnly"
        static let rain = "dachaRain"
    }

    /// Свежий снимок места, не старше этого, — иначе телефон отдал бы
    /// запомненное где-то по дороге.
    private static let freshest: TimeInterval = 120

    private override init() {
        super.init()
        spot = take(Dacha.Spot.self, Key.spot)
        rain = take(Dacha.Rainfall.self, Key.rain)
        only = store.bool(forKey: Key.only)
        // Без дачи геопозицию не трогаем вовсе.
        if spot != nil { look() }
    }

    // MARK: - Место

    /// Разрешение могли поменять в Настройках — спрашиваем телефон заново.
    func look() {
        let now = Self.access(of: ensure())
        if access != now { access = now }
        // Геопозицию запретили или оставили примерной — приезд не заметить:
        // «только на даче» выключается само, напоминания идут как обычно.
        if only, now == .denied || now == .approximate {
            only = Dacha.onlyThere(only, located: false)
        }
    }

    /// Без геопозиции «только на даче» не включить, см. `look`.
    var located: Bool { access == .fine }

    /// «Отметить дачу здесь»: разрешение, если его ещё не спрашивали, потом
    /// одно место — с той точностью, какую даст телефон.
    func mark() {
        missed = false
        look()
        switch access {
        case .unasked:
            asking = true
            ensure().requestWhenInUseAuthorization()
        case .fine:
            locate()
        case .denied, .approximate:
            break
        }
    }

    /// Место отмечено, а разрешение пропало («Разрешить однажды» кончилось):
    /// спросить снова, не трогая места.
    func allow() {
        look()
        guard access == .unasked else { return }
        ensure().requestWhenInUseAuthorization()
    }

    func forget() {
        spot = nil
        rain = nil
        missed = false
        store.removeObject(forKey: Key.spot)
        store.removeObject(forKey: Key.rain)
        Notifier.leaveDacha()
    }

    private func ensure() -> CLLocationManager {
        if let manager { return manager }
        let made = CLLocationManager()
        made.delegate = self
        manager = made
        return made
    }

    private static func access(of manager: CLLocationManager) -> Access {
        switch manager.authorizationStatus {
        case .notDetermined:
            return .unasked
        case .denied, .restricted:
            return .denied
        case .authorizedAlways, .authorizedWhenInUse:
            return manager.accuracyAuthorization == .fullAccuracy
                ? .fine : .approximate
        @unknown default:
            return .denied
        }
    }

    private func locate() {
        guard !locating else { return }
        let manager = ensure()
        locating = true
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.requestLocation()
    }

    private func settle(_ place: Dacha.Spot) {
        spot = place
        put(place, Key.spot)
        // Новое место — и дожди у него свои.
        rain = nil
        tried = nil
        store.removeObject(forKey: Key.rain)
        let rooms = Garden.shared.rooms
        Task {
            await post(rooms)
            await refresh(force: true)
        }
    }

    // MARK: - Напоминания

    /// Уведомление по приезде — по нынешнему саду. Зовётся, когда приложение
    /// уходит с экрана и возвращается, и когда место отметили; то же самое
    /// заново не ставится, см. `Notifier.expect`. Напоминания выключены,
    /// места или доступа нет, на даче нечего поливать — уведомление
    /// снимается.
    func post(_ rooms: [Room]) async {
        if spot != nil { look() }
        guard Settings.shared.reminders, let spot, access == .fine,
              let arrival = Dacha.arrival(in: rooms)
        else {
            Notifier.leaveDacha()
            return
        }
        await Notifier.expect(Dacha.text(for: arrival), plants: arrival.ids,
                              latitude: spot.latitude,
                              longitude: spot.longitude)
    }

    /// Комнаты для обычных напоминаний: без дачных, если о них напоминают
    /// только на даче, — но лишь пока напоминание по приезде и правда
    /// придёт. Место забыли или доступ отобрали — дачные снова в общем
    /// счёте, чтобы о них не забыли совсем.
    func reminded(_ rooms: [Room]) -> [Room] {
        if spot != nil { look() }
        return armed ? Dacha.home(rooms) : rooms
    }

    /// Напоминание по приезде придёт, и обычные о даче молчат.
    var armed: Bool { only && spot != nil && access == .fine }

    // MARK: - Дождь

    /// Дождь на даче — не чаще раза в три часа, только при «Учитывать
    /// погоду» и когда на даче есть комнаты без крыши. Прошедший дождь
    /// поднимает там влажность, обещанный на завтра — подсказка на карточке
    /// дня. WeatherKit не отвечает — молчим.
    func refresh(force: Bool = false) async {
        let garden = Garden.shared
        guard Settings.shared.weather, let spot, !raining,
              !Dacha.open(garden.rooms).isEmpty
        else { return }
        let now = Date()
        if !force,
           let last = [rain?.checked, tried].compactMap({ $0 }).max(),
           now.timeIntervalSince(last) < Weatherman.gap {
            return
        }
        raining = true
        defer { raining = false }
        let calendar = Calendar.current
        let from = max(rain?.counted ?? now.addingTimeInterval(-86_400),
                       now.addingTimeInterval(-2 * 86_400))
        let end = calendar.date(byAdding: .day, value: 2,
                                to: calendar.startOfDay(for: now))
            ?? now.addingTimeInterval(2 * 86_400)
        let place = CLLocation(latitude: spot.latitude,
                               longitude: spot.longitude)
        let forecast: Forecast<HourWeather>
        do {
            forecast = try await WeatherService.shared.weather(
                for: place, including: .hourly(startDate: from, endDate: end))
        } catch {
            tried = now
            return
        }
        // Пока ждали погоду, место могли забыть или отметить заново.
        guard self.spot == spot else { return }
        let hours = forecast.forecast.map { hour in
            // Снег горшков не польёт — в счёт только жидкое.
            Dacha.Hour(start: hour.date,
                       millimeters: hour.precipitation == .snow ? 0
                           : hour.precipitationAmount
                               .converted(to: .millimeters).value,
                       chance: hour.precipitationChance)
        }
        var next = rain ?? Dacha.Rainfall(counted: from, checked: now)
        let fell = Dacha.fallen(hours, from: from, to: now)
        let gain = Dacha.gain(fell.millimeters)
        if gain > 0 {
            garden.soak(Set(Dacha.open(garden.rooms).map(\.name)), by: gain)
            next.soaked = now
            next.millimeters = fell.millimeters
        }
        if let until = fell.until { next.counted = until }
        next.promised = Dacha.promised(hours, now: now, calendar: calendar)
        next.checked = now
        rain = next
        put(next, Key.rain)
    }

    // MARK: - Хранение

    private func take<Value: Decodable>(_ type: Value.Type,
                                        _ key: String) -> Value? {
        guard let data = store.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    private func put<Value: Encodable>(_ value: Value, _ key: String) {
        store.set(try? JSONEncoder().encode(value), forKey: key)
    }
}

// MARK: - Геопозиция

extension Dachnik: @preconcurrency CLLocationManagerDelegate {
    /// Приходит и сразу после создания, и когда разрешение или точность
    /// поменяли в Настройках.
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        look()
        guard asking, access != .unasked else { return }
        asking = false
        if access == .fine { locate() }
    }

    func locationManager(_ manager: CLLocationManager,
                         didUpdateLocations locations: [CLLocation]) {
        guard locating else { return }
        locating = false
        guard let fix = locations.last, fix.horizontalAccuracy >= 0,
              fix.horizontalAccuracy <= Dacha.roughest,
              abs(fix.timestamp.timeIntervalSinceNow) < Self.freshest
        else {
            missed = true
            return
        }
        settle(Dacha.Spot(latitude: fix.coordinate.latitude,
                          longitude: fix.coordinate.longitude,
                          marked: Date()))
    }

    func locationManager(_ manager: CLLocationManager,
                         didFailWithError error: any Error) {
        guard locating else { return }
        locating = false
        missed = true
    }
}

// MARK: - Уведомление по приезде

extension Notifier {
    /// Одно на дачу, по геозоне; приходит при каждом приезде, пока его не
    /// снимут. «Полил» в нём — тот же, что в обычном напоминании.
    static let dacha = "dacha"

    /// Такое же уже стоит — не трогаем: поставленное заново прямо на
    /// участке могло бы сработать сразу.
    static func expect(_ body: String, plants: [String], latitude: Double,
                       longitude: Double) async {
        let centre = UNUserNotificationCenter.current()
        guard await allowed() else {
            leaveDacha()
            return
        }
        let pending = await centre.pendingNotificationRequests()
        if let old = pending.first(where: { $0.identifier == dacha }),
           old.content.body == body,
           (old.content.userInfo["plants"] as? [String]) == plants,
           let trigger = old.trigger as? UNLocationNotificationTrigger,
           let region = trigger.region as? CLCircularRegion,
           region.center.latitude == latitude,
           region.center.longitude == longitude {
            return
        }
        let note = UNMutableNotificationContent()
        note.body = body
        note.sound = .default
        note.categoryIdentifier = category
        note.userInfo = ["plants": plants]
        let region = CLCircularRegion(
            center: CLLocationCoordinate2D(latitude: latitude,
                                           longitude: longitude),
            radius: Dacha.radius, identifier: dacha)
        region.notifyOnEntry = true
        region.notifyOnExit = false
        let request = UNNotificationRequest(
            identifier: dacha, content: note,
            trigger: UNLocationNotificationTrigger(region: region,
                                                   repeats: true))
        try? await centre.add(request)
    }

    static func leaveDacha() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [dacha])
    }
}
