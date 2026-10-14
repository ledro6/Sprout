import SwiftUI

/// Планетарий сада. Живой: планеты плывут, пока сад сохнет, сухие ждут у
/// ворот. Машина времени уносит на дни вперёд — как будет, если поливать
/// вовремя: пальцем по партитуре месяца или ползунком. «Проиграть месяц»
/// пролетает их за двадцать секунд, и каждый полив звучит нотой. Под
/// циферблатом — приметы неба: кто Меркурий сада, кто сойдётся у луча.
/// Небо тёмное в обеих темах — вместе с шапкой и строкой состояния.
struct OrreryView: View {
    @Environment(Garden.self) private var garden
    @Environment(\.dismiss) private var dismiss

    /// Дней сада вперёд; ноль — сейчас.
    @State private var ahead: Double = 0
    /// Панель вкладок спрятана, пока экран стоит, — см. `sproutPassage`.
    @State private var barHidden = true
    @State private var picked: Plant.ID?

    /// Когда началось проигрывание; пусто — не играет.
    @State private var playing: Date?
    @State private var preparing = false
    @State private var player = SpheresPlayer()

    /// Политые отсюда — у ворот расходится круг.
    @State private var splashed: [Plant.ID: Date] = [:]

    @Environment(\.accessibilityReduceMotion) private var still
    private let book = SkyBook.shared
    /// «Небесный журнал» открыт.
    @State private var journal = false
    /// Свежие поливы, у которых играет реакция: искра или спотыкание.
    @State private var echoes: [Echo] = []

    struct Echo: Hashable {
        var id: Plant.ID
        var hit: Precision.Hit
        var start: Date
    }

    private var side: Season.Side {
        Season.side(region: Locale.current.region?.identifier)
    }

    private var orbits: [Orrery.Orbit] {
        Orrery.orbits(garden.rooms.flatMap(\.plants))
    }

    var body: some View {
        let orbits = self.orbits
        let crossings = Orrery.crossings(orbits, within: Orrery.reach)
        ScrollViewReader { reader in
            ScrollView {
                VStack(spacing: Metrics.groupGap) {
                    chips
                    dial(orbits, crossings: crossings)
                        .hintSpot(.orreryDial)
                    card(crossings)
                        .hintSpot(.orreryCard)
                    time(crossings, count: orbits.count)
                        .hintSpot(.orreryTime)
                    play(orbits, crossings: crossings)
                        .hintSpot(.orreryPlay)
                    observatory(orbits)
                    omens(orbits)
                    parades(orbits)
                        .hintSpot(.orreryParades)
                }
                .padding(.horizontal, Metrics.contentMargin)
                .padding(.top, 8)
                .padding(.bottom, Metrics.barGap)
            }
            .background {
                ZStack {
                    StarField()
                    SkyEvents(kinds: Set(book.unseen.map(\.kind)))
                }
            }
            .walk(.orrery, scroll: reader)
        }
        // Панелью, а не поверх: прокрутка уходит под шапку мягким краем, как
        // под системную, и подсказки обходят её, как обходили ту.
        .safeAreaBar(edge: .top, spacing: 0) { header }
        .environment(\.colorScheme, .dark)
        .navigationTitle("Планетарий")
        .scrollEdgeEffectStyle(.soft, for: .top)
        .sproutSettledEdge()
        // Системная панель общая для стека и берёт его тему: в светлой
        // «назад», заголовок и «?» темнели на ночном небе. Тёмной её
        // `toolbarColorScheme` делает лишь с видимым фоном — полосой поверх
        // звёзд, а перекрашивать её саму пришлось бы посреди переходов, на
        // глазах у статистики и экрана растения. Поэтому панели здесь нет,
        // как и на статистике под нами, а шапка своя, в тёмном окружении;
        // жест назад возвращает `sproutSwipeBack`, строку состояния
        // светлит `sproutNight`.
        .toolbar(.hidden, for: .navigationBar)
        .sproutSwipeBack()
        .sproutNight()
        // Панель вкладок прячется на входе и возвращается с первым движением
        // свайпа назад, как в Telegram, а не после того, как экран ушёл.
        // Свайп бросили — прячется снова.
        .toolbar(barHidden ? .hidden : .visible, for: .tabBar)
        .sproutPassage { settled in
            withAnimation(Motion.edge) { barHidden = settled }
        }
        .onChange(of: ahead) { old, new in
            // Ведут ползунок — щелчок на каждом поливе, который проехали.
            guard playing == nil else { return }
            let low = min(old, new)
            let high = max(old, new)
            if crossings.contains(where: { $0.day > low && $0.day <= high }) {
                Feel.pick()
            }
        }
        .task(id: playing) {
            guard let started = playing else { return }
            let left = Spheres.seconds - Date().timeIntervalSince(started)
            try? await Task.sleep(for: .seconds(max(left, 0)))
            guard !Task.isCancelled, playing == started else { return }
            finish()
        }
        .onAppear {
            book.standing(garden.log, side: side)
            book.settle()
            discover()
            react()
        }
        .onChange(of: garden.ticked) {
            book.settle()
            discover()
        }
        .onChange(of: garden.log.count) {
            book.standing(garden.log, side: side)
            react()
        }
        .sheet(isPresented: $journal) {
            SkyJournal().environment(garden)
        }
        .onDisappear {
            stop()
            // Показанные события больше в «Небо сада» не вернутся.
            book.markShown()
        }
    }

    // MARK: - Редкие события

    private func discover() {
        book.discover(plants: garden.rooms.flatMap(\.plants),
                      log: garden.log)
    }

    // MARK: - Обсерватория

    /// Вопрос дня: кто первым дойдёт до луча. Ответ решает модель в миг
    /// выбора (`Observatory`), полив после него ничего не меняет.
    @ViewBuilder
    private func observatory(_ orbits: [Orrery.Orbit]) -> some View {
        let question = book.question(orbits)
        let answer = book.today()
        if !question.isEmpty || answer != nil {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("Обсерватория", systemImage: "binoculars")
                        .font(Typography.detail)
                        .foregroundStyle(Palette.ink)
                    Spacer(minLength: 8)
                    Label("\(book.state.stars)", systemImage: "star.fill")
                        .font(Typography.settingNote)
                        .foregroundStyle(Palette.waterGlow)
                }
                if let answer {
                    Text(Self.verdict(answer))
                        .font(Typography.settingNote)
                        .foregroundStyle(Palette.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("Кто первым дойдёт до луча?")
                        .font(Typography.settingRow)
                        .foregroundStyle(Palette.ink)
                    LazyVGrid(columns: [GridItem(.flexible()),
                                        GridItem(.flexible())], spacing: 8) {
                        ForEach(question, id: \.id) { candidate in
                            Button {
                                book.pick(candidate.id, from: question)
                                Feel.pick()
                            } label: {
                                Text(candidate.name)
                                    .font(Typography.settingRow)
                                    .lineLimit(1)
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.glass)
                        }
                    }
                }
                let streak = book.streak()
                if streak > 0 {
                    Text(Lang.format("Серия верных дней: %lld", streak))
                        .font(Typography.settingNote)
                        .foregroundStyle(Palette.secondaryText)
                }
            }
            .padding(Metrics.groupPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .sproutPlate(in: RoundedRectangle(cornerRadius: Metrics.cardRadius,
                                              style: .continuous))
        }
    }

    static func verdict(_ entry: Observatory.Entry) -> String {
        let first = entry.candidates.first { $0.id == entry.winner }?.name ?? ""
        switch entry.outcome {
        case .hit:
            return Lang.format("Верно! Первой дошла %@ — звезда наблюдателя.",
                               first)
        case .miss:
            return Lang.format("Не угадали: первой дошла %@.", first)
        case nil:
            let picked = entry.candidates.first { $0.id == entry.picked }?.name
                ?? ""
            let when = entry.reveal.formatted(date: .abbreviated,
                                              time: .shortened)
            return Lang.format("Вы выбрали: %1$@. Ответ узнаем %2$@.", picked,
                               when)
        }
    }

    // MARK: - Точность

    /// Компактная строка под шапкой: счёт сезона; нажатие — журнал.
    private var chips: some View {
        let standing = Precision.standing(garden.log, side: side,
                                          kept: book.state.record)
        return HStack {
            Button { journal = true } label: {
                HStack(spacing: 6) {
                    Image(systemName: "scope")
                    Text(Lang.format("Точность: %@",
                                     standing.share.map { Stats.percent($0) }
                                        ?? "—"))
                }
                .font(Typography.settingNote)
                .foregroundStyle(Palette.ink)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Capsule().fill(Color.white.opacity(0.08)))
            }
            .buttonStyle(.plain)
            .accessibilityHint("Откроет небесный журнал")
            Spacer(minLength: 0)
        }
    }

    /// Свежие поливы, которых небо ещё не показывало: «в яблочко» —
    /// искра у ворот, «рано» — планета спотыкается. При «Уменьшить
    /// движение» — без анимации, но поливы считаются показанными.
    private func react() {
        let fresh = book.take(garden.log)
        guard !fresh.isEmpty, !still else { return }
        let now = Date()
        echoes = echoes.filter { now.timeIntervalSince($0.start) < 2 }
            + fresh.map { Echo(id: $0.plant, hit: $0.hit, start: now) }
    }

    /// Планета, которую только что полили рано, спотыкается один раз.
    private func stumbled(_ planets: [Orrery.Planet],
                          at moment: Date) -> [Orrery.Planet] {
        guard !still, !echoes.isEmpty else { return planets }
        return planets.map { planet in
            guard let echo = echoes.first(where: {
                $0.id == planet.id && $0.hit == .early
            }) else { return planet }
            let t = moment.timeIntervalSince(echo.start) / 1.2
            guard t >= 0, t < 1 else { return planet }
            var out = planet
            out.angle += 0.24 * (1 - t) * abs(sin(t * 6 * .pi))
            return out
        }
    }

    /// Искры у ворот на орбитах тех, кого полили «в яблочко».
    private func glints(_ orbits: [Orrery.Orbit],
                        at moment: Date) -> [Orrery.Flash] {
        guard !still, !echoes.isEmpty else { return [] }
        let radius = Dictionary(orbits.map { ($0.id, $0.radius) },
                                uniquingKeysWith: { first, _ in first })
        return echoes.compactMap { echo in
            let since = moment.timeIntervalSince(echo.start) / 1.0
            guard echo.hit == .bullseye, since >= 0, since < 1,
                  let place = radius[echo.id] else { return nil }
            return Orrery.Flash(radius: place, strength: 1 - since)
        }
    }

    // MARK: - Шапка

    /// Как системная строка панели: круги по 44 pt — те же, что на экране
    /// растения, — и заголовок посередине. В тёмном окружении стекло кругов
    /// тёмное, знаки и заголовок светлые.
    private var header: some View {
        HStack(spacing: 8) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.backward")
                    .modifier(NavCircle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Назад")
            Text("Планетарий")
                .font(Typography.navTitle)
                .foregroundStyle(Palette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity)
                .accessibilityAddTraits(.isHeader)
            // Он же противовес «назад»: заголовок стоит ровно посередине.
            Button { journal = true } label: {
                Image(systemName: "book.closed")
                    .modifier(NavCircle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Небесный журнал")
        }
        .padding(.horizontal, Metrics.contentMargin)
        // Пустое место шапки держит касания, как системная панель: под ним
        // размытая прокрутка, и нажатие не должно уходить к ней.
        .contentShape(Rectangle())
    }

    // MARK: - Циферблат

    private func dial(_ orbits: [Orrery.Orbit],
                      crossings: [Orrery.Crossing]) -> some View {
        // Бережём заряд — вдвое реже: звук идёт по своим часам и не
        // сбивается. См. `Power`.
        TimelineView(.animation(minimumInterval: Power.shared.calm
                                ? 1.0 / 30 : 1.0 / 60)) { context in
            let moment = context.date
            let day = shown(at: moment)
            let planets = stumbled(sky(orbits, day: day, at: moment),
                                   at: moment)
            OrreryDial(planets: planets,
                       flashes: flashes(orbits, crossings: crossings,
                                        day: day, at: moment),
                       glints: glints(orbits, at: moment),
                       dimmed: Set(planets.filter {
                           Precision.dried($0.moisture)
                       }.map(\.id)),
                       picked: picked,
                       beat: beat(at: moment))
                .overlay {
                    GeometryReader { geometry in
                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture { point in
                                pick(near: point, in: geometry.size,
                                     planets: planets)
                            }
                    }
                }
        }
        .aspectRatio(1, contentMode: .fit)
        .overlay(alignment: .top) {
            Image(systemName: "drop.fill")
                .font(Typography.settingNote)
                .foregroundStyle(Palette.waterGlow)
                .padding(4)
                .hintSpot(.orreryGate)
                .allowsHitTesting(false)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Планетарий")
        .accessibilityValue(Lang.format("%lld растений", orbits.count))
    }

    /// День, который сейчас показан: ползунок или проигрывание.
    private func shown(at moment: Date) -> Double {
        guard let playing else { return ahead }
        let done = moment.timeIntervalSince(playing) / Spheres.seconds
        return min(max(done, 0), 1) * Orrery.reach
    }

    /// Сейчас — живой сад с досчётом от последнего такта часов.
    private func sky(_ orbits: [Orrery.Orbit], day: Double,
                     at moment: Date) -> [Orrery.Planet] {
        let drift = moment.timeIntervalSince(garden.ticked)
            * Garden.speed / 86_400
        return Orrery.sky(orbits, ahead: day, drift: drift)
    }

    private func flashes(_ orbits: [Orrery.Orbit],
                         crossings: [Orrery.Crossing], day: Double,
                         at moment: Date) -> [Orrery.Flash] {
        if day > 0 {
            return Orrery.flashes(crossings, orbits: orbits, at: day)
        }
        let radius = Dictionary(orbits.map { ($0.id, $0.radius) },
                                uniquingKeysWith: { first, _ in first })
        return splashed.compactMap { id, when in
            let since = moment.timeIntervalSince(when) / 0.9
            guard since < 1, let place = radius[id] else { return nil }
            return Orrery.Flash(radius: place, strength: 1 - since)
        }
    }

    /// Сухие дышат, как тревожная тень карточки.
    private func beat(at moment: Date) -> Double {
        let phase = moment.timeIntervalSinceReferenceDate
            / (Motion.pulsePeriod * 2)
        return (sin(phase * 2 * .pi) + 1) / 2
    }

    private func pick(near point: CGPoint, in size: CGSize,
                      planets: [Orrery.Planet]) {
        let nearest = planets.min {
            OrreryDial.point($0, in: size).distance(to: point)
                < OrreryDial.point($1, in: size).distance(to: point)
        }
        guard let nearest,
              OrreryDial.point(nearest, in: size).distance(to: point) < 30
        else {
            withAnimation(Motion.pill) { picked = nil }
            return
        }
        withAnimation(Motion.pill) {
            picked = picked == nearest.id ? nil : nearest.id
        }
        Feel.pick()
    }

    // MARK: - Карточка планеты

    @ViewBuilder
    private func card(_ crossings: [Orrery.Crossing]) -> some View {
        Group {
            if let id = picked, let plant = garden.plant(id: id) {
                chosen(plant, crossings: crossings)
            } else {
                Label("Нажмите на планету — узнаете, кто это.",
                      systemImage: "hand.tap")
                    .font(Typography.settingNote)
                    .foregroundStyle(Palette.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(Metrics.groupPadding)
        .sproutPlate(in: RoundedRectangle(cornerRadius: Metrics.cardRadius,
                                          style: .continuous))
        .animation(Motion.pill, value: picked)
    }

    private func chosen(_ plant: Plant,
                        crossings: [Orrery.Crossing]) -> some View {
        let live = playing == nil && ahead == 0
        let orbit = orbits.first { $0.id == plant.id }
        let level = live ? plant.moisture
            : orbit.map { Orrery.moisture($0, after: ahead) } ?? plant.moisture
        let next = crossings.first { $0.id == plant.id && $0.day > ahead }
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(plant.name)
                        .font(Typography.detail)
                        .foregroundStyle(Palette.ink)
                    Text(plant.species)
                        .font(Typography.settingNote)
                        .foregroundStyle(Palette.secondaryText)
                }
                Spacer(minLength: 8)
                Text(Stats.percent(level))
                    .font(Typography.figure)
                    .foregroundStyle(Palette.level(level))
                    .contentTransition(.numericText())
            }
            // Вперёд по времени — тем же движком, от влажности того дня.
            Text(live ? plant.wateringLabel
                 : next.map { _ in MoistureStatus.nextWatering(
                     moisture: level, period: plant.period,
                     estimated: plant.estimated) } ?? "")
                .font(Typography.settingNote)
                .foregroundStyle(Palette.secondaryText)
                .contentTransition(.numericText())
            HStack(spacing: 10) {
                if live {
                    Button { water(plant.id) } label: {
                        Label("Полить", systemImage: "drop.fill")
                            .font(Typography.detail)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glassProminent)
                    .tint(Palette.accentFill)
                }
                NavigationLink(value: StatsRoute.plant(plant.id)) {
                    Label("Открыть растение", systemImage: "arrow.up.forward")
                        .font(Typography.detail)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glass)
            }
            .controlSize(.large)
        }
        .transition(.blurReplace)
    }

    private func water(_ id: Plant.ID) {
        Overflow.shared.water(id, in: garden, source: .orrery) {
            let now = Date()
            // Отыгравшие круги больше не нужны.
            splashed = splashed.filter { now.timeIntervalSince($0.value) < 2 }
            splashed[id] = now
            Feel.water()
        }
    }

    // MARK: - Время

    private func time(_ crossings: [Orrery.Crossing],
                      count: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Машина времени", systemImage: "clock.arrow.2.circlepath")
                    .font(Typography.detail)
                    .foregroundStyle(Palette.ink)
                Spacer(minLength: 8)
                Text(ahead == 0 ? Lang.text("Сейчас")
                     : Stats.day(Int(ahead.rounded())))
                    .font(Typography.settingNote)
                    .foregroundStyle(Palette.secondaryText)
                    .contentTransition(.numericText())
            }
            TimelineView(.animation(paused: playing == nil)) { context in
                OrreryScore(crossings: crossings, count: count,
                            day: shown(at: context.date),
                            seek: playing == nil ? { ahead = $0 } : nil)
            }
            Slider(value: $ahead, in: 0 ... Orrery.reach, step: 0.25) {
                Text("Машина времени")
            } minimumValueLabel: {
                // Подписи у краёв — одного типа: значок внутри текста.
                Text(Image(systemName: "clock"))
            } maximumValueLabel: {
                Text(Lang.format("%lld дней", Int(Orrery.reach)))
                    .font(Typography.figureCaption)
            }
            .disabled(playing != nil)
            if ahead > 0 && playing == nil {
                Button("Вернуться к сегодня") {
                    withAnimation(Motion.enter) { ahead = 0 }
                }
                .font(Typography.settingNote)
                .transition(.blurReplace)
            }
        }
        .padding(Metrics.groupPadding)
        .sproutPlate(in: RoundedRectangle(cornerRadius: Metrics.cardRadius,
                                          style: .continuous))
        .animation(Motion.pill, value: ahead == 0)
    }

    // MARK: - Музыка сфер

    private func play(_ orbits: [Orrery.Orbit],
                      crossings: [Orrery.Crossing]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                if playing != nil { stop() } else { start(orbits, crossings) }
            } label: {
                HStack(spacing: 10) {
                    if preparing {
                        ProgressView()
                    } else {
                        Image(systemName: playing == nil ? "play.fill"
                              : "stop.fill")
                            .contentTransition(.symbolEffect(.replace))
                    }
                    Text(playing == nil ? "Проиграть месяц" : "Остановить")
                        .lineLimit(1)
                }
                .font(Typography.detail)
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .tint(Palette.accentFill)
            .controlSize(.extraLarge)
            .disabled(preparing || orbits.isEmpty)
            HStack(spacing: 6) {
                if Settings.shared.sounds {
                    Image(systemName: "music.note")
                    Text("Каждый полив — нота: ближние планеты поют выше.")
                } else {
                    Image(systemName: "speaker.slash")
                    Text("Звуки выключены в настройках — будет без музыки.")
                }
            }
            .font(Typography.settingNote)
            .foregroundStyle(Palette.secondaryText)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func start(_ orbits: [Orrery.Orbit],
                       _ crossings: [Orrery.Crossing]) {
        picked = nil
        let notes = Spheres.notes(crossings, count: orbits.count)
        guard Settings.shared.sounds else {
            withAnimation(Motion.pill) { playing = Date() }
            return
        }
        preparing = true
        Task { @MainActor in
            await player.prepare(notes)
            preparing = false
            // Картинка трогается, когда звук дойдёт до ушей, и чуть
            // раньше — на путь кадра до глаз: нота — ровно когда планета на
            // луче.
            let delay = player.start()
            withAnimation(Motion.pill) {
                playing = Date().addingTimeInterval(delay - Spheres.lead)
            }
        }
    }

    private func stop() {
        player.stop()
        guard playing != nil else { return }
        let reached = shown(at: Date())
        withAnimation(Motion.pill) {
            playing = nil
            ahead = (reached * 4).rounded() / 4
        }
    }

    private func finish() {
        withAnimation(Motion.pill) {
            playing = nil
            ahead = Orrery.reach
        }
    }

    // MARK: - Приметы

    /// Небо сада — приметы строками: кто у луча, кто быстрее всех, кто с
    /// кем сойдётся и кто напротив кого.
    @ViewBuilder
    private func omens(_ orbits: [Orrery.Orbit]) -> some View {
        let drift = Date().timeIntervalSince(garden.ticked) * Garden.speed
            / 86_400
        let omens = Orrery.omens(orbits, drift: drift)
        let events = book.unseen
        if !omens.isEmpty || !events.isEmpty {
            VStack(alignment: .leading, spacing: Metrics.rowGap) {
                Label("Небо сада", systemImage: "sparkles")
                    .font(Typography.detail)
                    .foregroundStyle(Palette.ink)
                ForEach(events, id: \.key) { event in
                    let line = Self.caption(event)
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Image(systemName: line.icon)
                            .foregroundStyle(Palette.waterGlow)
                            .frame(width: 22)
                        Text(line.text)
                            .font(Typography.settingNote)
                            .foregroundStyle(Palette.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .transition(.blurReplace)
                }
                ForEach(omens, id: \.self) { omen in
                    let line = Self.line(omen)
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Image(systemName: line.icon)
                            .foregroundStyle(Palette.waterGlow)
                            .frame(width: 22)
                        Text(line.text)
                            .font(Typography.settingNote)
                            .foregroundStyle(Palette.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .transition(.blurReplace)
                }
            }
            .padding(Metrics.groupPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .sproutPlate(in: RoundedRectangle(cornerRadius: Metrics.cardRadius,
                                              style: .continuous))
            .animation(Motion.pill, value: omens)
        }
    }

    /// Строка о редком событии для «Неба сада» и журнала.
    static func caption(_ event: Rare.Event) -> (icon: String, text: String) {
        switch event.kind {
        case .aurora:
            ("moon.stars",
             Lang.text("Северное сияние: неделю в саду никто не пересыхал."))
        case .comet:
            ("sparkle",
             Lang.format("Комета: %@ только что прилетела в сад.",
                         event.subject))
        case .meteor:
            ("sparkles",
             Lang.text("Метеорный дождь: у парада все напились вовремя."))
        }
    }

    static func line(_ omen: Orrery.Omen) -> (icon: String, text: String) {
        switch omen {
        case .zenith(let name, let waiting):
            ("arrow.up.circle",
             waiting ? Lang.format("%@ ждёт у луча — пора полить.", name)
                : Lang.format("Ближе всех к лучу — %@: попросит воды первым.",
                              name))
        case .swift(let name, let period):
            ("hare", Lang.format("Меркурий сада — %1$@: пьёт %2$@.", name,
                                 Lang.format("раз в %lld дней", period)))
        case .patient(let name, let period):
            ("tortoise", Lang.format("Нептун сада — %1$@: пьёт %2$@.", name,
                                     Lang.format("раз в %lld дней", period)))
        case .conjunction(let names, let day):
            ("circle.circle",
             Lang.format("Соединение: %1$@ попросят воды вместе — %2$@.",
                         Stats.names(names),
                         Stats.day(day).lowercased(with: Lang.locale)))
        case .opposition(let first, let second):
            ("arrow.left.and.right.circle",
             Lang.format("Противостояние: %1$@ и %2$@ — по разные стороны солнца.",
                         first, second))
        }
    }

    // MARK: - Парады

    private func parades(_ orbits: [Orrery.Orbit]) -> some View {
        let parades = Array(Orrery.parades(orbits).prefix(3))
        return VStack(alignment: .leading, spacing: Metrics.rowGap) {
            HStack(spacing: 6) {
                Text("Парады")
                    .font(Typography.detail)
                    .foregroundStyle(Palette.ink)
                TermHint(.parade)
            }
            if parades.isEmpty {
                Text("В ближайший месяц парадов нет: растения просят воды вразнобой.")
                    .font(Typography.settingNote)
                    .foregroundStyle(Palette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            ForEach(Array(parades.enumerated()), id: \.element.id) { item in
                if item.offset > 0 { SproutDivider() }
                Button {
                    stop()
                    withAnimation(Motion.enter) {
                        ahead = Double(item.element.day)
                    }
                } label: {
                    parade(item.element)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(Metrics.groupPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .sproutPlate(in: RoundedRectangle(cornerRadius: Metrics.cardRadius,
                                          style: .continuous))
    }

    private func parade(_ parade: Orrery.Parade) -> some View {
        HStack(spacing: 12) {
            Text("\(parade.ids.count)")
                .font(Typography.detail)
                .foregroundStyle(Palette.space)
                .frame(width: 34, height: 34)
                .background(Circle().fill(Palette.waterGlow))
            VStack(alignment: .leading, spacing: 2) {
                Text(Stats.day(parade.day))
                    .font(Typography.settingRow)
                    .foregroundStyle(Palette.ink)
                Text(Stats.names(parade.names))
                    .font(Typography.settingNote)
                    .foregroundStyle(Palette.secondaryText)
                    .lineLimit(2)
            }
            Spacer(minLength: 8)
            Image(systemName: "chevron.right")
                .font(Typography.settingNote)
                .foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

extension CGPoint {
    fileprivate func distance(to other: CGPoint) -> CGFloat {
        hypot(x - other.x, y - other.y)
    }
}
