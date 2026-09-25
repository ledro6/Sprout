import AVFoundation
import Observation
import SwiftUI

/// «Итоги года сада» — презентация во весь экран, как годовые итоги
/// музыкальных сервисов: слайды сменяются сами, полоски сверху показывают,
/// сколько осталось. Нажатие справа — дальше, слева — назад, удержание —
/// пауза, смахнуть вниз — закрыть. Под слайдами играет мелодия года.
struct RecapView: View {
    let recap: Recap

    @Environment(\.dismiss) private var dismiss

    @State private var index = 0
    /// Сколько раз смотрели заново: слайд с тем же номером — новый слайд.
    @State private var round = 0
    @State private var clock = StoryClock()
    @State private var player = RecapPlayer()
    @State private var pull: CGFloat = 0
    @State private var pressed: Date?

    private var deck: [Recap.Slide] { recap.deck }

    private var slide: Recap.Slide { deck[min(index, deck.count - 1)] }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                // Жест — на самом слайде: кнопки на нём главнее касания.
                RecapPage(slide: slide, recap: recap, again: restart)
                    .contentShape(Rectangle())
                    .gesture(press(width: geometry.size.width))
                    .id("\(round)-\(index)")
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 1.08)),
                        removal: .opacity.combined(with: .scale(scale: 0.94))))
                VStack(spacing: 10) {
                    StoryBar(count: deck.count, index: index, clock: clock,
                             seconds: Self.seconds(slide))
                    HStack {
                        Spacer()
                        CloseButton { close() }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.top, 6)
            }
        }
        .background(Color.black)
        .clipShape(RoundedRectangle(cornerRadius: pull > 0 ? 40 : 0,
                                    style: .continuous))
        .scaleEffect(1 - min(pull, 320) / 1600)
        .offset(y: pull)
        .statusBarHidden()
        .preferredColorScheme(.dark)
        .task(id: "\(round)-\(index)") { await run() }
        .task { await player.start(recap) }
        .onDisappear { player.stop() }
    }

    /// Сколько стоит слайд: вступление короче, последний — пока не закроют.
    static func seconds(_ slide: Recap.Slide) -> Double {
        slide == .intro ? 5.5 : 7
    }

    private func run() async {
        guard slide != .outro else {
            clock.finish()
            return
        }
        if await clock.run(for: Self.seconds(slide)) { next() }
    }

    /// Одно касание решает всё: коротко — листать, держать — пауза,
    /// потянуть вниз — закрыть.
    private func press(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if pressed == nil {
                    pressed = value.time
                    hold(true)
                }
                pull = max(value.translation.height, 0)
            }
            .onEnded { value in
                let began = pressed ?? value.time
                pressed = nil
                hold(false)
                if value.translation.height > 140 {
                    close()
                    return
                }
                withAnimation(.spring(duration: 0.35)) { pull = 0 }
                let moved = hypot(value.translation.width,
                                  value.translation.height)
                guard moved < 12,
                      value.time.timeIntervalSince(began) < 0.35 else { return }
                if value.location.x < width * 0.3 { back() } else { next() }
            }
    }

    private func hold(_ on: Bool) {
        clock.paused = on
        if on { player.pause() } else { player.resume() }
    }

    private func next() {
        guard index < deck.count - 1 else { return }
        withAnimation(.smooth(duration: 0.55)) { index += 1 }
        Feel.pick()
    }

    /// На первом слайде «назад» — начать его заново.
    private func back() {
        withAnimation(.smooth(duration: 0.55)) {
            if index > 0 { index -= 1 } else { round += 1 }
        }
        Feel.pick()
    }

    private func restart() {
        withAnimation(.smooth(duration: 0.6)) {
            round += 1
            index = 0
        }
        Feel.pick()
    }

    private func close() {
        player.stop()
        dismiss()
    }
}

/// Часы слайда: сколько он уже идёт. Своим циклом, а не таймером
/// анимации: пауза по удержанию должна останавливать и полоску, и смену.
@MainActor
@Observable
final class StoryClock {
    var elapsed = 0.0
    var paused = false
    private(set) var done = false

    /// Отвечает, дошёл ли слайд до конца, — прерванный не листает.
    func run(for seconds: Double) async -> Bool {
        elapsed = 0
        done = false
        var last = ContinuousClock.now
        while elapsed < seconds {
            try? await Task.sleep(for: .milliseconds(33))
            if Task.isCancelled { return false }
            let now = ContinuousClock.now
            if !paused { elapsed += (now - last) / .seconds(1) }
            last = now
        }
        return true
    }

    func finish() { done = true }
}

/// Полоски сверху: прошедшие — полные, текущая — наливается.
struct StoryBar: View {
    let count: Int
    let index: Int
    let clock: StoryClock
    let seconds: Double

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0 ..< count, id: \.self) { item in
                GeometryReader { geometry in
                    Capsule()
                        .fill(.white.opacity(0.3))
                        .overlay(alignment: .leading) {
                            Capsule()
                                .fill(.white)
                                .frame(width: geometry.size.width * fill(item))
                        }
                }
                .frame(height: 3)
            }
        }
        .accessibilityHidden(true)
    }

    private func fill(_ item: Int) -> CGFloat {
        if item < index || (item == index && clock.done) { return 1 }
        if item > index { return 0 }
        return CGFloat(min(clock.elapsed / seconds, 1))
    }
}

/// Мелодия года — шкатулкой, как музыка сфер, по кругу. Собирается в фоне
/// при открытии; беззвучный режим и выключенные звуки её глушат.
@MainActor
final class RecapPlayer {
    private var player: AVAudioPlayer?
    private var stopped = false

    func start(_ recap: Recap) async {
        guard Settings.shared.sounds else { return }
        let notes = recap.melody()
        let length = Recap.length()
        let data = await Task.detached(priority: .userInitiated) {
            Spheres.wav(Spheres.render(notes, seconds: length))
        }.value
        guard !stopped else { return }
        try? AVAudioSession.sharedInstance().setCategory(.ambient)
        guard let player = try? AVAudioPlayer(
            data: data, fileTypeHint: AVFileType.wav.rawValue) else { return }
        player.numberOfLoops = -1
        player.volume = 0
        player.play()
        player.setVolume(0.9, fadeDuration: 1.5)
        self.player = player
    }

    func pause() { player?.pause() }

    func resume() { player?.play() }

    /// Затихает, а не обрывается.
    func stop() {
        stopped = true
        guard let player else { return }
        self.player = nil
        player.setVolume(0, fadeDuration: 0.4)
        Task {
            try? await Task.sleep(for: .milliseconds(450))
            player.stop()
        }
    }
}

/// Итоги картинкой — поделиться: год, главные числа, любимчик и время
/// садовника на живом фоне с фигурками узора.
struct RecapPoster: View {
    let recap: Recap

    var body: some View {
        ZStack(alignment: .topLeading) {
            MeshGradient(width: 3, height: 3, points: [
                SIMD2(0, 0), SIMD2(0.55, 0), SIMD2(1, 0),
                SIMD2(0, 0.45), SIMD2(0.6, 0.5), SIMD2(1, 0.55),
                SIMD2(0, 1), SIMD2(0.45, 1), SIMD2(1, 1),
            ], colors: RecapTheme.colors(.outro))
            Canvas { context, size in
                let pieces = SproutShapes.pieces
                for index in 0 ..< 18 {
                    let piece = pieces[index % pieces.count]
                    var layer = context
                    layer.opacity = 0.12
                    layer.translateBy(x: CGFloat(index % 4) * 100 + 30,
                                      y: CGFloat(index / 4) * 150 + 40)
                    layer.rotate(by: .degrees(Double(index * 37 % 60) - 30))
                    layer.translateBy(x: -piece.centre.x, y: -piece.centre.y)
                    layer.fill(piece.path, with: .color(.white))
                }
            }
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    SproutLogo(height: 30, aspect: SproutLogo.plain)
                    Text(verbatim: "Sprout")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                }
                Text(Lang.text("Итоги года"))
                    .font(RecapTheme.caption)
                    .textCase(.uppercase)
                    .opacity(0.85)
                    .padding(.top, 18)
                Text(verbatim: String(recap.year))
                    .font(RecapTheme.huge(92))
                Grid(alignment: .leading, horizontalSpacing: 18,
                     verticalSpacing: 14) {
                    GridRow {
                        figure(Lang.text("Поливы за год"),
                               recap.waterings.formatted())
                        figure(Lang.text("Дней подряд без перерыва"),
                               recap.streak.formatted())
                    }
                    GridRow {
                        figure(Lang.text("Вовремя"),
                               recap.onTime.map {
                                   Lang.format("%lld%%", Int(($0 * 100).rounded()))
                               } ?? "—")
                        figure(Lang.text("Растений в саду"),
                               recap.plants.formatted())
                    }
                }
                if let star = recap.favorite {
                    figure(Lang.text("Любимчик года"), star.name)
                }
                if let persona = recap.persona {
                    figure(Lang.text("Ваше время"), persona.title)
                }
                Spacer(minLength: 0)
            }
            .padding(28)
        }
        .foregroundStyle(.white)
        .frame(width: 360, height: 640)
    }

    private func figure(_ caption: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(verbatim: value)
                .font(RecapTheme.huge(30))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Text(caption)
                .font(.caption.weight(.semibold))
                .opacity(0.8)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Втрое крупнее экрана: картинка уходит в соцсети, там её увеличивают.
    @MainActor
    static func image(_ recap: Recap) -> Image? {
        let renderer = ImageRenderer(content: RecapPoster(recap: recap))
        renderer.scale = 3
        guard let image = renderer.uiImage else { return nil }
        return Image(uiImage: image)
    }
}

/// Вход в итоги на экране статистики — карточкой с живым фоном.
struct RecapTeaser: View {
    let year: Int

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Backdrop(colors: RecapTheme.colors(.intro))
            PieceRise(count: 10)
            VStack(alignment: .leading, spacing: 2) {
                Text(Lang.text("Итоги года"))
                    .font(RecapTheme.caption)
                    .textCase(.uppercase)
                    .opacity(0.85)
                Text(verbatim: String(year))
                    .font(RecapTheme.huge(46))
                Text(Lang.text("Как жил ваш сад — слайдами и с музыкой"))
                    .font(.subheadline.weight(.semibold))
                    .opacity(0.9)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .foregroundStyle(.white)
        .frame(height: 170)
        .clipShape(RoundedRectangle(cornerRadius: Metrics.cardRadius,
                                    style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: Metrics.cardRadius,
                                       style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }
}
