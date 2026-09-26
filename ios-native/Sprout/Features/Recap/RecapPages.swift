import SwiftUI

/// Один слайд «Итогов года»: живой фон своего цвета, подпись мелко, число
/// или слово огромным и строка пояснения. Всё проявляется по очереди:
/// подпись, потом число набегает от нуля, потом строка и рисунок.
struct RecapPage: View {
    let slide: Recap.Slide
    let recap: Recap

    /// Что делать на последнем слайде: смотреть снова.
    var again: () -> Void = {}

    @State private var shown = false
    @State private var grow = 0.0
    @State private var poster: Image?

    var body: some View {
        ZStack {
            Backdrop(colors: RecapTheme.colors(slide))
            decoration
            VStack(alignment: .leading, spacing: 14) {
                Spacer(minLength: 96)
                content
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 56)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .foregroundStyle(.white)
        .task {
            // Кадр на то, чтобы слайд встал: иначе SwiftUI склеил бы
            // появление с первым кадром, и проявления не было бы видно.
            try? await Task.sleep(for: .milliseconds(60))
            shown = true
            withAnimation(.easeOut(duration: 1.8).delay(0.5)) { grow = 1 }
            if slide == .outro { poster = RecapPoster.image(recap) }
        }
    }

    // MARK: - Содержимое

    @ViewBuilder
    private var content: some View {
        switch slide {
        case .intro: intro
        case .waterings: waterings
        case .favorite: favorite
        case .podium: podium
        case .streak: streak
        case .rhythm: rhythm
        case .aim: aim
        case .months: months
        case .garden: garden
        case .awards: awards
        case .outro: outro
        }
    }

    private func caption(_ text: String) -> some View {
        Text(text)
            .font(RecapTheme.caption)
            .textCase(.uppercase)
            .opacity(0.85)
            .revealed(shown)
    }

    private func line(_ text: String, delay: Double = 1.2) -> some View {
        Text(text)
            .font(RecapTheme.line)
            .fixedSize(horizontal: false, vertical: true)
            .revealed(shown, delay: delay)
    }

    private func number(_ value: Int, size: CGFloat = 124,
                        format: @escaping (Int) -> String = { $0.formatted() })
        -> some View {
        CountUp(value: shown ? Double(value) : 0, format: format)
            .font(RecapTheme.huge(size))
            .lineLimit(1)
            .minimumScaleFactor(0.4)
            .animation(.easeOut(duration: 1.6).delay(0.35), value: shown)
    }

    private func word(_ text: String, size: CGFloat = 64) -> some View {
        Text(verbatim: text)
            .font(RecapTheme.huge(size))
            .lineLimit(2)
            .minimumScaleFactor(0.5)
            .revealed(shown, delay: 0.3, seconds: 1.3)
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 14) {
            SproutLogo(height: 110, aspect: SproutLogo.plain, reveal: grow)
                .padding(.bottom, 18)
            caption(Lang.text("Итоги года"))
            word(String(recap.year), size: 132)
            line(recap.empty
                 ? Lang.text("Сад только начинается — самое интересное впереди.")
                 : Lang.text("Как жил ваш сад в этом году. Нажмите справа — дальше, слева — назад."),
                 delay: 1)
        }
    }

    private var waterings: some View {
        VStack(alignment: .leading, spacing: 14) {
            caption(Lang.text("Поливы за год"))
            number(recap.waterings)
            line(Lang.format("Это около %@ л воды — если по стакану за раз.",
                             recap.liters.formatted(
                                 .number.precision(.fractionLength(0 ... 1))
                                     .locale(Lang.locale))))
            line(Lang.format("Дней с поливом: %lld", recap.days), delay: 1.6)
                .opacity(0.8)
        }
    }

    @ViewBuilder
    private var favorite: some View {
        if let star = recap.favorite {
            VStack(alignment: .leading, spacing: 14) {
                caption(Lang.text("Любимчик года"))
                StarPhoto(star: star)
                    .frame(width: 220, height: 220)
                    .shadow(color: .black.opacity(0.3), radius: 24, y: 12)
                    .scaleEffect(shown ? 1 : 0.6)
                    .rotationEffect(.degrees(shown ? -3 : -18))
                    .opacity(shown ? 1 : 0)
                    .animation(.spring(duration: 0.9, bounce: 0.35).delay(0.3),
                               value: shown)
                word(star.name)
                line(Lang.format("Поливов: %lld", star.count))
            }
        }
    }

    private var podium: some View {
        VStack(alignment: .leading, spacing: 18) {
            caption(Lang.text("Тройка самых политых"))
            HStack(alignment: .bottom, spacing: 12) {
                ForEach([1, 0, 2], id: \.self) { place in
                    if recap.podium.indices.contains(place) {
                        step(recap.podium[place], place: place)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            line(Lang.text("Чем выше ступень, тем чаще лейка."), delay: 1.4)
        }
    }

    private func step(_ star: Recap.Star, place: Int) -> some View {
        let heights: [CGFloat] = [190, 140, 105]
        return VStack(spacing: 8) {
            StarPhoto(star: star)
                .frame(width: 72, height: 72)
                .opacity(grow)
            Text(verbatim: star.name)
                .font(.headline.weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.white.opacity(place == 0 ? 0.95 : 0.55))
                .frame(height: heights[place] * grow)
                .overlay(alignment: .top) {
                    Text(verbatim: star.count.formatted())
                        .font(RecapTheme.huge(28))
                        .foregroundStyle(.black.opacity(0.7))
                        .padding(.top, 10)
                        .opacity(grow)
                }
        }
        .frame(maxWidth: .infinity)
    }

    private var streak: some View {
        VStack(alignment: .leading, spacing: 14) {
            caption(Lang.text("Дней подряд без перерыва"))
            number(recap.streak)
            YearRing(lit: recap.lit, days: recap.length, progress: grow)
                .frame(width: 250, height: 250)
                .frame(maxWidth: .infinity)
            line(Lang.text("Кольцо — ваш год: каждая яркая точка — день с поливом."),
                 delay: 1.6)
        }
    }

    @ViewBuilder
    private var rhythm: some View {
        if let hour = recap.peakHour, let persona = recap.persona {
            VStack(alignment: .leading, spacing: 14) {
                caption(Lang.text("Ваше время"))
                ZStack {
                    HourDial(hours: recap.hours, peak: hour, progress: grow)
                        .frame(width: 230, height: 230)
                    Text(verbatim: Self.clock(hour))
                        .font(RecapTheme.huge(40))
                        .opacity(grow)
                }
                .frame(maxWidth: .infinity)
                word(persona.title, size: 52)
                line(persona.line)
            }
        }
    }

    /// Час по-местному: у кого «08:00», у кого «8 AM».
    private static func clock(_ hour: Int) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Lang.locale
        let moment = calendar.date(bySettingHour: hour, minute: 0, second: 0,
                                   of: Date()) ?? Date()
        return moment.formatted(Date.FormatStyle(date: .omitted,
                                                 time: .shortened)
            .locale(Lang.locale))
    }

    @ViewBuilder
    private var aim: some View {
        if let share = recap.onTime {
            let percent = Int((share * 100).rounded())
            VStack(alignment: .leading, spacing: 14) {
                caption(Lang.text("Вовремя"))
                ZStack {
                    Circle()
                        .stroke(.white.opacity(0.2), lineWidth: 18)
                    Circle()
                        .trim(from: 0, to: share * grow)
                        .stroke(.white, style: StrokeStyle(lineWidth: 18,
                                                           lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    number(percent, size: 64) { Lang.format("%lld%%", $0) }
                }
                .frame(width: 220, height: 220)
                .frame(maxWidth: .infinity)
                line(share >= 0.6
                     ? Lang.text("Вы с землёй на одной волне: поливаете, когда пора.")
                     : share >= 0.3
                     ? Lang.text("Часто вовремя, иногда с запасом — растения не в обиде.")
                     : Lang.text("Поливаете с запасом: пересохнуть вашим растениям не грозит."))
            }
        }
    }

    @ViewBuilder
    private var months: some View {
        if let best = recap.bestMonth {
            VStack(alignment: .leading, spacing: 14) {
                caption(Lang.text("Самый зелёный месяц"))
                word(MonthBars.name(best))
                MonthBars(months: recap.months, best: best, progress: grow)
                line(Lang.format("Поливов в этом месяце: %lld",
                                 recap.months[best]), delay: 1.6)
            }
        }
    }

    private var garden: some View {
        VStack(alignment: .leading, spacing: 14) {
            if recap.added > 0 {
                caption(Lang.text("Новых растений"))
                number(recap.added) { "+" + $0.formatted() }
            } else {
                caption(Lang.text("Растений в саду"))
                number(recap.plants)
            }
            line(Lang.format("Растений: %1$lld · комнат: %2$lld",
                             recap.plants, recap.rooms))
        }
    }

    private var awards: some View {
        VStack(alignment: .leading, spacing: 16) {
            caption(Lang.text("Награды года"))
            number(recap.awards.count)
            let columns = [GridItem(.adaptive(minimum: 70), spacing: 12)]
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(Array(recap.awards.enumerated()), id: \.element) {
                    index, rank in
                    // Медаль вырастает на месте, как карточка растения.
                    MedalBadge(rank: rank, earned: true)
                        .frame(width: 70, height: 70)
                        .scaleEffect(shown ? 1 : Motion.medalScale)
                        .opacity(shown ? 1 : 0)
                        .animation(Motion.medal
                            .delay(0.6 + Double(index) * 0.12), value: shown)
                }
            }
            line(Lang.format("Получено %1$lld из %2$lld",
                             Cabinet.shared.total, Award.total),
                 delay: 1.6)
        }
    }

    private var outro: some View {
        VStack(alignment: .leading, spacing: 16) {
            caption(Lang.text("Спасибо, что поливали"))
            word(Lang.format("До встречи в %lld", recap.year + 1), size: 54)
            line(Lang.text("Покажите друзьям, как рос ваш сад."), delay: 0.9)
            HStack(spacing: 12) {
                if let poster {
                    ShareLink(item: poster,
                              preview: SharePreview(
                                  Lang.format("Итоги %lld в Sprout",
                                              recap.year),
                                  image: poster)) {
                        Label("Поделиться", systemImage: "square.and.arrow.up")
                            .font(.headline)
                            .padding(.horizontal, 6)
                    }
                    .buttonStyle(.glassProminent)
                    .controlSize(.large)
                }
                Button(action: again) {
                    Label("Ещё раз", systemImage: "arrow.counterclockwise")
                        .font(.headline)
                }
                .buttonStyle(.glass)
                .controlSize(.large)
            }
            .padding(.top, 8)
            .opacity(grow)
        }
    }

    // MARK: - Рисунок за текстом

    @ViewBuilder
    private var decoration: some View {
        switch slide {
        case .waterings, .outro:
            DropRain()
        case .garden, .intro:
            PieceRise()
        default:
            EmptyView()
        }
    }
}

/// Фигурки узора всплывают снизу — росток, цветок, капля и горшок, как
/// пузыри в воде.
struct PieceRise: View {
    var count = 22

    @Environment(\.accessibilityReduceMotion) private var still

    var body: some View {
        TimelineView(.animation(paused: still)) { frame in
            let time = frame.date.timeIntervalSinceReferenceDate
            Canvas { context, size in
                for index in 0 ..< count {
                    piece(index, at: time, in: size, into: &context)
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func piece(_ index: Int, at time: Double, in size: CGSize,
                       into context: inout GraphicsContext) {
        func unit(_ salt: Int) -> Double {
            Double((index &* 2_246_822_519 &+ salt &* 31_337) & 0xFFFF) / 65_535
        }
        let pieces = SproutShapes.pieces
        let shape = pieces[index % pieces.count]
        let speed = 30 + unit(1) * 50
        let span = Double(size.height) + 120
        let rise = (time * speed + unit(2) * span)
            .truncatingRemainder(dividingBy: span)
        let y = CGFloat(Double(size.height) + 60 - rise)
        let sway = sin(time * 0.6 + unit(4) * 6) * 16
        let x = CGFloat(unit(3) * Double(size.width) + sway)
        let scale = CGFloat(0.4 + unit(5) * 0.6)
        var layer = context
        layer.opacity = 0.14 + unit(6) * 0.22
        layer.translateBy(x: x, y: y)
        layer.rotate(by: .radians(sin(time * 0.5 + unit(7) * 6) * 0.4))
        layer.scaleBy(x: scale, y: scale)
        layer.translateBy(x: -shape.centre.x, y: -shape.centre.y)
        layer.fill(shape.path, with: .color(.white))
    }
}
