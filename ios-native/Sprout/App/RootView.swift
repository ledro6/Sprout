import AppIntents
import SwiftUI
import UIKit

/// Корень приложения. Панель вкладок с отдельной капсулой поиска и её
/// анимации — системные, `TabView` с `Tab(role: .search)` в iOS 26.
struct RootView: View {
    /// Сад общий — см. `Garden.shared`: с ним говорит и Siri.
    @State private var garden = Garden.shared

    @State private var notch: CGFloat = 0

    /// Не в окружении — см. `Settings`.
    private let settings = Settings.shared

    /// Не в окружении: замок нужен и корню, а до корня окружение не достаёт.
    private let lock = Lock.shared

    @Environment(\.scenePhase) private var phase

    var body: some View {
        // Условия знакомства читаются в самом теле: изнутри привязки
        // SwiftUI мог бы не заметить, что вход доиграл.
        let _ = touring
        TabView {
            Tab("Главная", systemImage: "house.fill") {
                HomeView().sproutUndo()
            }
            Tab("Статистика", systemImage: "chart.bar.fill") {
                StatsView().sproutUndo()
            }
            Tab("Добавить", systemImage: "plus.circle.fill") {
                AddView().sproutUndo()
            }
            Tab("Профиль", systemImage: "person.fill") {
                ProfileView().sproutUndo()
            }
            Tab(role: .search) {
                SearchView().sproutUndo()
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .tint(Palette.accent)
        .environment(garden)
        // Глубину выреза знает только корень: окно видно только отсюда.
        .environment(\.notch, notch)
        .task { await runClock() }
        .task { await Launch.shared.run() }
        .task { Chime.warm() }
        // Состав сада сменился — пересказываем Siri клички.
        .onChange(of: garden.roster, initial: true) { _, _ in
            SproutShortcuts.updateAppShortcutParameters()
            // Картинки для виджета — тем же поводом: состав сада сменился.
            let rooms = garden.rooms
            Task(priority: .utility) { await Thumbs.export(rooms) }
            // И свои модели для AR: мастерская отмечает собранные и
            // выбрасывает модели и сканы ушедших растений. Сама она ничего
            // не собирает — готовые модели видов лежат в приложении.
            let plants = rooms.flatMap(\.plants)
            Task(priority: .utility) { await Workshop.shared.tend(plants) }
        }
        // Время года — при запуске, при возвращении (мог смениться месяц) и
        // когда его выключают в настройках.
        .onChange(of: settings.seasons, initial: true) { _, on in
            Season.settle(on: on)
        }
        // Узор времени года — до первого кадра, чтобы всходы шли уже им.
        // Переключатель в настройках ставит его сам, с волной.
        .onAppear { Festive.shared.settle(on: settings.seasonalPattern) }
        // Тема — в корне: она должна достать и до листа настроек, и до
        // заставки. Пусто — за системой.
        .preferredColorScheme(scheme)
        // Сперва заставка, плашка поверх неё: в макете плашка есть и на
        // приветственном экране.
        .overlay { welcome }
        .overlay(alignment: .top) { badge }
        // Замок поверх всего: запертый сад не должен мелькнуть даже под
        // заставкой.
        .overlay { padlock }
        // Знакомство — один раз, когда вход доиграл и сад не заперт. Ушло
        // под замок — не пройдено: откроют сад, и оно начнётся снова.
        .fullScreenCover(isPresented: Binding(
            get: { touring },
            set: { if !$0, !locked { settings.toured = true } })) {
            TourView()
        }
        // Наблюдатель касаний — тоже на окно, см. `Finger`.
        .onAppear {
            notch = Self.topInset()
            Finger.shared.watch()
        }
        // При первом появлении окна могло ещё не быть.
        .onChange(of: phase) { _, now in
            if now == .active {
                notch = Self.topInset()
                Finger.shared.watch()
                // Пока спали, сад мог полить виджет или кнопка в
                // уведомлении.
                garden.reload()
                Season.settle(on: settings.seasons)
                redress()
                Task { await lock.unlock() }
            } else {
                // Запираем на «неактивно», а не на «в фоне»: снимок для
                // переключателя программ делается раньше, и на нём остался бы
                // сад.
                lock.close()
                // Выгрузить приложение могут в любой момент.
                garden.save()
            }
            // Удалённое уходит насовсем только в фоне: на «неактивно»
            // попадают шторка, «Пункт управления» и Face ID.
            if now == .background { Bin.shared.commit() }
            remind(active: now == .active)
        }
    }

    private var touring: Bool {
        !settings.toured && Launch.shared.step >= Launch.last && !locked
    }

    private var locked: Bool { lock.on && !lock.open }

    private var scheme: ColorScheme? {
        switch settings.theme {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }

    /// Пока спали, мог наступить декабрь или Новый год: узор меняется
    /// волной сверху вниз, как в настройках.
    private func redress() {
        let chosen = settings.chosen
        guard let before = Festive.shared.settle(on: settings.seasonalPattern),
              Launch.shared.step >= Launch.last
        else { return }
        let after = Festive.shared.motif.dress(chosen)
        guard before.dress(chosen) != after else { return }
        Launch.shared.reshape(from: before.dress(chosen), to: after,
                              front: .sweep(Double.pi / 2))
    }

    /// Напоминание ставится при уходе с экрана и снимается при возвращении:
    /// пока на сад смотрят, оно было бы шумом. Слепок комнат снимается здесь,
    /// на главной очереди.
    private func remind(active: Bool) {
        guard settings.reminders, !active else {
            Notifier.clear()
            return
        }
        let rooms = garden.rooms
        let threshold = settings.threshold
        Task { await Notifier.schedule(in: rooms, threshold: threshold) }
    }

    /// Раз в секунду: даже у самого быстрого растения процент меняется за
    /// полторы.
    private func runClock() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(1))
            garden.advance()
        }
    }

    @ViewBuilder
    private var padlock: some View {
        if lock.on, !lock.open {
            LockView()
                .transition(.opacity)
        }
    }

    @ViewBuilder
    private var welcome: some View {
        if Launch.shared.greeting {
            // Нажатия забирает себе, иначе сквозь заставку можно ткнуть в
            // карточку.
            Splash(owner: garden.owner)
                .transition(.opacity)
        }
    }

    /// Глубина выреза — у окна: SwiftUI её не отдаёт (и нулевая рамка, и
    /// `GeometryReader` отвечали нулём). Приложение только вертикальное, так
    /// что за сеанс число не меняется.
    private static func topInset() -> CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }?
            .safeAreaInsets.top ?? 0
    }

    /// Плашка с логотипом — общая для всех вкладок, от верха самого экрана,
    /// поэтому в корне. Без прыжка на волне: это знак приложения, а не
    /// элемент экрана.
    private var badge: some View {
        SproutBadge()
            .padding(.top, Metrics.badgeTop)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .ignoresSafeArea()
            .allowsHitTesting(false)
    }
}
