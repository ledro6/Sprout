import AVFoundation
import SwiftUI

/// Планетарий сада. Живой: планеты плывут, пока сад сохнет, сухие ждут у
/// ворот. Ползунок уносит на дни вперёд — как будет, если поливать вовремя;
/// «Проиграть месяц» пролетает их за двадцать секунд, и каждый полив
/// звучит нотой. Небо тёмное в обеих темах.
struct OrreryView: View {
    @Environment(Garden.self) private var garden

    /// Дней сада вперёд; ноль — сейчас.
    @State private var ahead: Double = 0
    @State private var picked: Plant.ID?

    /// Когда началось проигрывание; пусто — не играет.
    @State private var playing: Date?
    @State private var preparing = false
    @State private var player = SpheresPlayer()

    /// Политые отсюда — у ворот расходится круг.
    @State private var splashed: [Plant.ID: Date] = [:]

    private var orbits: [Orrery.Orbit] {
        Orrery.orbits(garden.rooms.flatMap(\.plants))
    }

    var body: some View {
        let orbits = self.orbits
        let crossings = Orrery.crossings(orbits, within: Orrery.reach)
        ScrollViewReader { reader in
            ScrollView {
                VStack(spacing: Metrics.groupGap) {
                    dial(orbits, crossings: crossings)
                        .hintSpot(.orreryDial)
                    card(crossings)
                        .hintSpot(.orreryCard)
                    time(crossings)
                        .hintSpot(.orreryTime)
                    play(orbits, crossings: crossings)
                        .hintSpot(.orreryPlay)
                    parades(orbits)
                        .hintSpot(.orreryParades)
                }
                .padding(.horizontal, Metrics.contentMargin)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
            .background { StarField() }
            .walk(.orrery, scroll: reader)
        }
        .environment(\.colorScheme, .dark)
        .navigationTitle("Планетарий")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                WalkButton(walk: .orrery)
            }
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
        .onDisappear { stop() }
    }

    // MARK: - Циферблат

    private func dial(_ orbits: [Orrery.Orbit],
                      crossings: [Orrery.Crossing]) -> some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60)) { context in
            let moment = context.date
            let day = shown(at: moment)
            let planets = sky(orbits, day: day, at: moment)
            OrreryDial(planets: planets,
                       flashes: flashes(orbits, crossings: crossings,
                                        day: day, at: moment),
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
                .foregroundStyle(Palette.water)
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
                    .foregroundStyle(.secondary)
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
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                Text(Stats.percent(level))
                    .font(Typography.figure)
                    .foregroundStyle(Palette.level(level))
                    .contentTransition(.numericText())
            }
            Text(live ? plant.wateringLabel
                 : next.map { Plant.wateringLabel(
                     days: Int(($0.day - ahead).rounded())) } ?? "")
                .font(Typography.settingNote)
                .foregroundStyle(.secondary)
                .contentTransition(.numericText())
            HStack(spacing: 10) {
                if live {
                    Button { water(plant.id) } label: {
                        Label("Полить", systemImage: "drop.fill")
                            .font(Typography.detail)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glassProminent)
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
        guard Bin.shared.water(id, in: garden) else { return }
        let now = Date()
        // Отыгравшие круги больше не нужны.
        splashed = splashed.filter { now.timeIntervalSince($0.value) < 2 }
        splashed[id] = now
        Feel.water()
    }

    // MARK: - Время

    private func time(_ crossings: [Orrery.Crossing]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Машина времени", systemImage: "clock.arrow.2.circlepath")
                    .font(Typography.detail)
                    .foregroundStyle(Palette.ink)
                Spacer(minLength: 8)
                Text(ahead == 0 ? Lang.text("Сейчас")
                     : Stats.day(Int(ahead.rounded())))
                    .font(Typography.settingNote)
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
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
                Button("Вернуться в сейчас") {
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
                }
                .font(Typography.detail)
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
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
            .foregroundStyle(.secondary)
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
            player.start()
            withAnimation(Motion.pill) { playing = Date() }
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
                    .foregroundStyle(.secondary)
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
                .background(Circle().fill(Palette.water))
            VStack(alignment: .leading, spacing: 2) {
                Text(Stats.day(parade.day))
                    .font(Typography.settingRow)
                    .foregroundStyle(Palette.ink)
                Text(Stats.names(parade.names))
                    .font(Typography.settingNote)
                    .foregroundStyle(.secondary)
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

/// Рисунок планетария: орбиты, ворота, следы, вспышки, солнце и планеты.
/// Холстом, а не вью: планет десятки, и двигаются они каждый кадр.
struct OrreryDial: View {
    let planets: [Orrery.Planet]
    var flashes: [Orrery.Flash] = []
    var picked: Plant.ID?
    var beat: Double = 0
    /// На обзоре — мелко и без подписей.
    var small = false

    /// Где планета в рамке размера `size` — общая мерка для рисунка и
    /// нажатий.
    static func point(_ planet: Orrery.Planet, in size: CGSize,
                      small: Bool = false) -> CGPoint {
        spot(radius: planet.radius, angle: planet.angle, in: size,
             small: small)
    }

    private static func reach(_ size: CGSize, small: Bool) -> CGFloat {
        min(size.width, size.height) / 2 - (small ? 5 : 16)
    }

    private static func spot(radius: Double, angle: Double, in size: CGSize,
                             small: Bool) -> CGPoint {
        let full = reach(size, small: small) * CGFloat(radius)
        return CGPoint(x: size.width / 2 + full * CGFloat(sin(angle)),
                       y: size.height / 2 - full * CGFloat(cos(angle)))
    }

    var body: some View {
        Canvas { context, size in
            let middle = CGPoint(x: size.width / 2, y: size.height / 2)
            let full = Self.reach(size, small: small)
            let sun = small ? Metrics.sun * 0.45 : Metrics.sun

            // Орбиты — тонкими кругами, выбранная — ярче.
            for planet in planets {
                let r = full * CGFloat(planet.radius)
                let lit = planet.id == picked
                context.stroke(
                    Path(ellipseIn: CGRect(x: middle.x - r, y: middle.y - r,
                                           width: r * 2, height: r * 2)),
                    with: .color(.white.opacity(lit ? 0.4 : 0.1)),
                    lineWidth: lit ? 1.4 : 0.6)
            }

            // Ворота: сектор и луч от солнца вверх.
            var wedge = Path()
            wedge.move(to: middle)
            for step in 0 ... 12 {
                let angle = -Orrery.gate + 2 * Orrery.gate * Double(step) / 12
                wedge.addLine(to: CGPoint(
                    x: middle.x + (full + 8) * CGFloat(sin(angle)),
                    y: middle.y - (full + 8) * CGFloat(cos(angle))))
            }
            wedge.closeSubpath()
            context.fill(wedge, with: .color(Palette.water.opacity(0.1)))
            var beam = Path()
            beam.move(to: CGPoint(x: middle.x, y: middle.y - sun / 2))
            beam.addLine(to: CGPoint(x: middle.x, y: middle.y - full - 6))
            context.stroke(beam, with: .linearGradient(
                Gradient(colors: [Palette.water.opacity(0.9),
                                  Palette.water.opacity(0.15)]),
                startPoint: middle,
                endPoint: CGPoint(x: middle.x, y: middle.y - full)),
                style: StrokeStyle(lineWidth: small ? 1.5 : 2.5,
                                   lineCap: .round))

            // Следы — пройденная часть круга: чем длиннее, тем суше.
            for planet in planets {
                let travelled = planet.angle - Orrery.gate
                let steps = max(Int(travelled / (2 * .pi) * 72), 1)
                var trail = Path()
                for step in 0 ... steps {
                    let angle = Orrery.gate
                        + travelled * Double(step) / Double(steps)
                    let at = Self.spot(radius: planet.radius, angle: angle,
                                       in: size, small: small)
                    if step == 0 { trail.move(to: at) } else {
                        trail.addLine(to: at)
                    }
                }
                context.stroke(trail,
                               with: .color(Palette.level(planet.moisture)
                                   .opacity(0.3)),
                               style: StrokeStyle(lineWidth: small ? 1.2 : 2,
                                                  lineCap: .round))
            }

            // Вспышки полива у ворот.
            for flash in flashes {
                let at = Self.spot(radius: flash.radius, angle: 0, in: size,
                                   small: small)
                let r = 5 + (1 - flash.strength) * 18
                context.stroke(
                    Path(ellipseIn: CGRect(x: at.x - r, y: at.y - r,
                                           width: r * 2, height: r * 2)),
                    with: .color(Palette.water.opacity(flash.strength)),
                    lineWidth: 2)
            }

            // Солнце — источник воды.
            context.drawLayer { layer in
                layer.addFilter(.blur(radius: sun / 3))
                layer.fill(Path(ellipseIn: CGRect(x: middle.x - sun * 0.7,
                                                  y: middle.y - sun * 0.7,
                                                  width: sun * 1.4,
                                                  height: sun * 1.4)),
                           with: .color(Palette.water.opacity(0.55)))
            }
            context.fill(Path(ellipseIn: CGRect(x: middle.x - sun / 2,
                                                y: middle.y - sun / 2,
                                                width: sun, height: sun)),
                         with: .radialGradient(
                             Gradient(colors: [.white, Palette.water]),
                             center: middle, startRadius: 0,
                             endRadius: sun / 2))
            var drop = context.resolve(Image(systemName: "drop.fill"))
            drop.shading = .color(Palette.space.opacity(0.8))
            let glyph = sun * 0.42
            context.draw(drop, in: CGRect(x: middle.x - glyph / 2,
                                          y: middle.y - glyph * 0.6,
                                          width: glyph, height: glyph * 1.2))

            // Свечение планет — одним слоем: размытие на каждую дорого.
            context.drawLayer { layer in
                layer.addFilter(.blur(radius: small ? 2 : 5))
                for planet in planets {
                    let at = Self.point(planet, in: size, small: small)
                    let r = diameter(of: planet) * 0.9
                    layer.fill(Path(ellipseIn: CGRect(x: at.x - r,
                                                      y: at.y - r,
                                                      width: r * 2,
                                                      height: r * 2)),
                               with: .color(Palette.level(planet.moisture)
                                   .opacity(0.8)))
                }
            }
            for planet in planets {
                let at = Self.point(planet, in: size, small: small)
                let r = diameter(of: planet) / 2
                let disc = Path(ellipseIn: CGRect(x: at.x - r, y: at.y - r,
                                                  width: r * 2, height: r * 2))
                context.fill(disc, with: .color(Palette.level(planet.moisture)))
                if planet.id == picked {
                    context.stroke(disc, with: .color(.white), lineWidth: 2)
                    let name = context.resolve(
                        Text(planet.name)
                            .font(Typography.cardCaption.weight(.semibold))
                            .foregroundStyle(.white))
                    let right = at.x < size.width * 0.7
                    context.draw(name,
                                 at: CGPoint(x: at.x + (right ? r + 6 : -r - 6),
                                             y: at.y),
                                 anchor: right ? .leading : .trailing)
                }
            }
        }
    }

    /// Выбранная — крупнее; сухие дышат.
    private func diameter(of planet: Orrery.Planet) -> CGFloat {
        let base = planet.id == picked ? Metrics.planetPicked : Metrics.planet
        let scaled = small ? base * 0.62 : base
        guard Thirst(moisture: planet.moisture) == .alarm else { return scaled }
        return scaled * (1 + 0.3 * CGFloat(beat))
    }
}

/// Звёзды планетария — неподвижные, мерцают вразнобой. Места — из
/// постоянного зерна: небо не перетасовывается при каждом открытии.
struct StarField: View {
    private static let stars: [(x: Double, y: Double, size: Double,
                                phase: Double)] = {
        var seed: UInt64 = 0x5EED
        func next() -> Double {
            seed = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return Double(seed >> 11) / Double(1 << 53)
        }
        return (0 ..< 90).map { _ in
            (next(), next(), 0.6 + next() * 1.6, next())
        }
    }()

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20)) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            Canvas { canvas, size in
                canvas.fill(Path(CGRect(origin: .zero, size: size)),
                            with: .radialGradient(
                                Gradient(colors: [Palette.spaceGlow,
                                                  Palette.space]),
                                center: CGPoint(x: size.width / 2,
                                                y: size.height * 0.3),
                                startRadius: 0,
                                endRadius: max(size.width, size.height) * 0.8))
                for star in Self.stars {
                    let twinkle = (sin((time / 2.6 + star.phase) * 2 * .pi)
                                   + 1) / 2
                    let r = star.size * (0.7 + 0.3 * twinkle)
                    canvas.fill(Path(ellipseIn: CGRect(
                                    x: star.x * size.width - r / 2,
                                    y: star.y * size.height - r / 2,
                                    width: r, height: r)),
                                with: .color(.white.opacity(0.25
                                                            + 0.55 * twinkle)))
                }
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

/// Вход в планетарий на обзоре статистики: маленький живой планетарий и
/// пара слов.
struct OrreryTeaser: View {
    @Environment(Garden.self) private var garden

    var body: some View {
        let orbits = Orrery.orbits(garden.rooms.flatMap(\.plants))
        HStack(spacing: 14) {
            TimelineView(.animation(minimumInterval: 1.0 / 30)) { context in
                let drift = context.date.timeIntervalSince(garden.ticked)
                    * Garden.speed / 86_400
                OrreryDial(planets: Orrery.sky(orbits, ahead: 0, drift: drift),
                           small: true)
            }
            .frame(width: Metrics.teaser, height: Metrics.teaser)
            .background(Circle().fill(Palette.space))
            .clipShape(Circle())
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text("Планетарий сада")
                        .font(Typography.detail)
                        .foregroundStyle(Palette.ink)
                    Image(systemName: "sparkles")
                        .font(Typography.settingNote)
                        .foregroundStyle(Palette.accent)
                }
                Text("Растения кружат по орбитам полива. Послушайте, как звучит месяц.")
                    .font(Typography.settingNote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(Typography.settingNote)
                .foregroundStyle(.tertiary)
        }
        .padding(Metrics.groupPadding)
        .contentShape(Rectangle())
        .sproutPlate(in: RoundedRectangle(cornerRadius: Metrics.cardRadius,
                                          style: .continuous))
    }
}

/// Проигрыватель музыки сфер. Звук собирается заранее, в фоне, и играет
/// из памяти — ровно столько, сколько летит месяц. Сессия та же, что у
/// звуков приложения: беззвучный режим глушит.
@MainActor
final class SpheresPlayer {
    private var player: AVAudioPlayer?

    func prepare(_ notes: [Spheres.Note]) async {
        let data = await Task.detached(priority: .userInitiated) {
            Spheres.wav(Spheres.render(notes))
        }.value
        try? AVAudioSession.sharedInstance().setCategory(.ambient)
        player = try? AVAudioPlayer(data: data,
                                    fileTypeHint: AVFileType.wav.rawValue)
        player?.prepareToPlay()
    }

    func start() { player?.play() }

    func stop() {
        player?.stop()
        player = nil
    }
}

extension CGPoint {
    fileprivate func distance(to other: CGPoint) -> CGFloat {
        hypot(x - other.x, y - other.y)
    }
}
