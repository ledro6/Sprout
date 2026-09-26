import CoreLocation
import Foundation
import Observation
import WeatherKit

/// Погода за окном — для сроков полива, см. `Climate`. Место — примерное:
/// погоде хватает города, и точное хозяину отдавать незачем. Снимается не
/// чаще раза в три часа и только при включённой настройке. WeatherKit
/// требует возможности «WeatherKit» у приложения в Xcode и включённой
/// службы у App ID; без них погода не приходит, а настройки говорят, что
/// включить.
@MainActor
@Observable
final class Weatherman {
    static let shared = Weatherman()

    enum Trouble: Equatable {
        /// Место не дали — погоду не узнать.
        case place
        /// Служба погоды не отвечает или не включена у приложения.
        case service
    }

    private(set) var trouble: Trouble?
    private(set) var busy = false

    /// Знак Apple Weather и страница источников — WeatherKit требует
    /// показывать их рядом с погодой.
    private(set) var mark: (light: URL, dark: URL)?
    private(set) var legal: URL?

    /// Чаще погода почти не меняется, а запрос стоит заряда.
    static let gap: TimeInterval = 3 * 3_600

    private let settings = Settings.shared

    private init() {}

    /// Свежая погода есть — ничего не делаем; нет — узнаём место и погоду.
    func refresh(force: Bool = false) async {
        guard settings.weather, !busy else { return }
        if !force, let last = settings.climate,
           Date().timeIntervalSince(last.taken) < Self.gap {
            Climate.settle(last, on: true)
            return
        }
        busy = true
        defer { busy = false }
        guard let place = await place() else {
            trouble = .place
            return
        }
        do {
            let current = try await WeatherService.shared.weather(
                for: place, including: .current)
            let climate = Climate(
                temperature: current.temperature.converted(to: .celsius).value,
                humidity: current.humidity,
                symbol: current.symbolName,
                taken: current.date)
            settings.climate = climate
            Climate.settle(climate, on: true)
            trouble = nil
            await sign()
        } catch {
            trouble = .service
        }
    }

    /// Знак и ссылка — один раз за запуск.
    private func sign() async {
        guard legal == nil,
              let attribution = try? await WeatherService.shared.attribution
        else { return }
        mark = (attribution.combinedMarkLightURL,
                attribution.combinedMarkDarkURL)
        legal = attribution.legalPageURL
    }

    /// Первое место из обновлений — не дольше пятнадцати секунд. Разрешение
    /// спрашивает сессия службы: «при использовании», можно примерное.
    private func place() async -> CLLocation? {
        let session = CLServiceSession(authorization: .whenInUse)
        defer { session.invalidate() }
        let deadline = Date().addingTimeInterval(15)
        do {
            for try await update in CLLocationUpdate.liveUpdates() {
                if let location = update.location { return location }
                if update.authorizationDenied
                    || update.authorizationDeniedGlobally {
                    return nil
                }
                if Date() > deadline { return nil }
            }
        } catch {
            return nil
        }
        return nil
    }
}
