import SwiftUI

/// Экран одного растения: большое фото, карточка со сведениями и история
/// поливов.
///
/// Растение берётся из сада по номеру, а не передаётся копией: его тут же
/// поливают и переименовывают, а почва вдобавок подсыхает сама — экран
/// должен показывать живое состояние, а не слепок, снятый при переходе.
///
/// Панель навигации системная: в iOS 26 она сама рисует стеклянные
/// капсулы кнопки «назад» и элементов тулбара, сама держит жест возврата
/// свайпом и сама анимирует переход. Ничего из этого писать не нужно.
///
/// Плашки фото и сведений — тот же материал, что у карточек на главном,
/// см. `sproutPlate`. Отклика на нажатие у них нет: нажимать нечего.
struct PlantView: View {
    let plantID: Plant.ID

    @Environment(Garden.self) private var garden
    @Environment(\.dismiss) private var dismiss

    @State private var renaming = false
    @State private var draft = ""

    /// Спрашивают ли имя новой комнаты, куда переезжать.
    @State private var moving = false
    @State private var roomDraft = ""

    /// Где на экране лежит плашка с фото. Отсюда по узору расходится
    /// волна: полив виден на ней, от неё же он и идёт по фону. Не
    /// состоянием — см. `Spot`.
    @State private var spot = Spot()

    /// Проступила ли верхняя панель. С неё начинается экран, но не с
    /// первого кадра: см. `Motion.chrome`.
    @State private var chrome = false

    private var plant: Plant? { garden.plant(id: plantID) }

    var body: some View {
        ScrollView {
            if let plant {
                // Без стеклянного контейнера: этот экран — приёмная сторона
                // разворачивания карточки, и склеивать его содержимое в один
                // слой значит ломать переход с той стороны, куда он ведёт.
                VStack(spacing: 44) {
                    photo(plant)
                    facts(plant)
                    diary(plant)
                }
                .padding(.horizontal, Metrics.margin)
                .padding(.top, 14)
                .padding(.bottom, 40)
            }
        }
        .background { SproutBackground() }
        .navigationTitle(plant?.name ?? "")
        .navigationBarTitleDisplayMode(.inline)
        // Своя кнопка «назад», а не системная: системную не размыть — её
        // рисует панель. Ценой этого идёт жест возврата свайпом от края:
        // спрятав системную кнопку, SwiftUI выключает и его. Возврат
        // потягиванием вниз остаётся — его держит само разворачивание
        // карточки, а не панель.
        .navigationBarBackButtonHidden(true)
        .toolbar {
            // Без общей стеклянной подложки: её рисует панель, а не эти
            // кнопки, и на размытие она не отзывалась — значок проступал,
            // а капсула под ним стояла с первого кадра. Сняв её, капсулу
            // рисует каждая кнопка сама — тем же системным стеклом, но уже
            // внутри вью, которую можно размыть.
            ToolbarItem(placement: .topBarLeading) { back }
                .sharedBackgroundVisibility(.hidden)
            ToolbarItem(placement: .principal) { title }
            ToolbarItem(placement: .topBarTrailing) { actions }
                .sharedBackgroundVisibility(.hidden)
        }
        // Панель проступает сама, отстав от разворачивания карточки.
        //
        // Отставание отсчитывается здесь, а не задержкой у анимации:
        // анимацию выбирает тот же флаг, что и размытие, и задержка
        // внутри неё досталась бы и уходу — то есть уход начинался бы уже
        // после того, как экран сложился.
        //
        // Отдельным проходом ещё и потому, что смену, случившуюся в том
        // же проходе, где вью появилась, SwiftUI схлопывает: панель
        // просто оказывалась на месте, и анимировать было нечего.
        .onAppear {
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(Motion.chromeDelay))
                chrome = true
            }
        }
        .alert("Переименовать", isPresented: $renaming) {
            TextField("Кличка", text: $draft)
            Button("Отмена", role: .cancel) {}
            Button("Сохранить") {
                withAnimation(Motion.number) {
                    garden.rename(plantID, to: draft)
                }
            }
        } message: {
            Text("Как теперь зовут растение?")
        }
        .alert("Новая комната", isPresented: $moving) {
            TextField("Балкон", text: $roomDraft)
            Button("Отмена", role: .cancel) {}
            Button("Переехать") { relocate(to: roomDraft) }
        } message: {
            Text("Растение переедет туда, и комната появится в списке.")
        }
        // Растение удалили — экран закрывается сам: показывать больше
        // нечего, а пустым он выглядел бы поломкой. Вернуть его можно с
        // плашки внизу — уже на том экране, откуда сюда пришли.
        .onChange(of: plant == nil) { _, gone in
            if gone { close() }
        }
    }

    /// Кнопка «назад».
    ///
    /// Стекло и размер — системные, стилем кнопки. Здесь стояла своя
    /// сборка: квадрат в 44 пункта и материал, положенный на значок
    /// руками. Материал был тот же самый, а вот всё остальное, что
    /// приходит со стилем, приходилось бы писать самому — продавливание
    /// под пальцем, отскок, блик за точкой касания, поведение при
    /// «Уменьшении прозрачности».
    private var back: some View {
        Button { close() } label: {
            Image(systemName: "chevron.backward")
                .font(Typography.navTitle)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .accessibilityLabel("Назад")
        .modifier(Chrome(shown: chrome))
        .sproutRide()
    }

    /// Заголовок панели — свой, а не системный.
    ///
    /// Системный появляется разом и на полную силу, и подступиться к нему
    /// нечем: это не вью, а строка, которую панель рисует сама. Свой —
    /// обычный текст, и проступает он тем же размытием, что и меню рядом.
    private var title: some View {
        Text(plant?.name ?? "")
            .font(Typography.navTitle)
            .foregroundStyle(Palette.ink)
            .lineLimit(1)
            // Переименовали — новая кличка собирается из размытия.
            .contentTransition(.numericText())
            .modifier(Chrome(shown: chrome))
            .sproutRide()
    }

    /// Меню в панели. Стекло и размер — те же системные, что у «назад»:
    /// `.button` заставляет меню принять стиль кнопки.
    private var actions: some View {
        Menu {
            Button { water() } label: {
                Label("Полить сейчас", systemImage: "drop.fill")
            }
            Button {
                draft = plant?.name ?? ""
                renaming = true
            } label: {
                Label("Переименовать", systemImage: "pencil")
            }
            MoveMenu(current: garden.roomName(of: plantID),
                     rooms: garden.rooms.map(\.name),
                     move: relocate,
                     ask: {
                         roomDraft = ""
                         moving = true
                     })
            // Без подтверждения: растение уходит сразу, а вернуть его
            // можно с плашки — см. `Bin`.
            Button(role: .destructive) { toss() } label: {
                Label("Удалить", systemImage: "trash")
            }
        } label: {
            // Цвет не задаём: кнопка идёт за общим оттенком приложения,
            // как и «назад» рядом.
            Image(systemName: "ellipsis")
                .font(Typography.navTitle)
        }
        .menuStyle(.button)
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .modifier(Chrome(shown: chrome))
        .sproutRide()
    }

    /// Закрыть экран, дав панели раствориться.
    ///
    /// Уходит она тем же размытием, что и приходила, только быстрее и без
    /// задержки. А вот закрытие эту задержку ждёт — иначе ухода просто не
    /// видно: панель рисует UIKit, и на время складывания он снимает с
    /// неё кадр. Начни складывание сразу — в кадр попала бы панель целой
    /// и резкой.
    ///
    /// Уходом при этом закрывается не всякий возврат. Потянув экран вниз,
    /// его закрывает само разворачивание карточки, мимо этой кнопки, — и
    /// панель уезжает вместе со всем экраном, размывать её там незачем.
    private func close() {
        chrome = false
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(Motion.chromeLead))
            dismiss()
        }
    }

    /// Полить: сад меняет влажность, а по узору от плашки с фото
    /// расходится волна.
    ///
    /// Полив с анимацией: проценты прыгают к сотне разом, и без неё
    /// тревожная тень гасла бы щелчком.
    private func water() {
        withAnimation(Motion.appear) { garden.water(plantID) }
        Cheer.shared.now(from: spot.rect)
        Feel.water()
    }

    /// Удалить. Красное по узору идёт от плашки с фото — от того места,
    /// где растение и было видно.
    private func toss() {
        Bin.shared.toss(plantID, from: spot.rect, in: garden)
    }

    private func relocate(to room: String) {
        withAnimation(Motion.number) { garden.relocate(plantID, to: room) }
    }

    /// Плашка с фото. В макете 336×347: квадратное фото плюс поля.
    private func photo(_ plant: Plant) -> some View {
        PlantPhoto(plant: plant, radius: Metrics.cardRadius - 6)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity)
            .aspectRatio(336.0 / 347.0, contentMode: .fit)
            .sproutPlate(in: plate)
            // Та же тень, что у карточки на витрине, и считается тем же
            // кодом. Только под плашкой с растением: у плашки со
            // сведениями тревожиться не о чем.
            .modifier(PlantGlow(plant: plant, shape: plate))
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) }
                action: { spot.rect = $0 }
            // Плашка политого растения — та, из-под которой волна и
            // выходит: её черёд нулевой, она подпрыгивает первой.
            .sproutRide()
    }

    private func facts(_ plant: Plant) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            // Влажность первой строкой: она здесь единственное, что
            // меняется само, и смотреть на таймер удобнее всего тут.
            // Меняются только цифры — числовым переходом системы.
            fact("Влажность \(plant.moistureLabel)")
                .contentTransition(.numericText())
            fact(plant.species)
            // Срок полива и комната меняются от действий на этом же
            // экране — полили, перевезли, — и меняются тем же системным
            // размытием, что и проценты, а не щелчком.
            fact(plant.wateringLabel)
                .contentTransition(.numericText())
            if let room = garden.roomName(of: plant.id) {
                fact("Комната «\(room)»")
                    .contentTransition(.numericText())
            }
            fact(plant.addedLabel)
        }
        .animation(Motion.number, value: plant.moisture)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 25)
        .padding(.vertical, 22)
        .sproutPlate(in: plate)
        .sproutRide()
    }

    /// История поливов: сколько всего, как часто и последние поливы
    /// строками.
    ///
    /// Всё здесь появляется системным размытием. Полили с этого экрана — и
    /// новая строка не въезжает сверху и не проявляется, а собирается из
    /// расфокуса (`blurReplace`), а число поливов и частота меняются тем
    /// же переходом цифр, что и проценты влажности. Самая старая строка,
    /// которой больше нет места, уходит тем же размытием.
    private func diary(_ plant: Plant) -> some View {
        let diary = Diary.of(garden.log, plant: plant.id)
        return VStack(alignment: .leading, spacing: Metrics.diaryGap) {
            Text("Поливы")
                .font(Typography.groupTitle)
                .foregroundStyle(.secondary)
            if diary.entries.isEmpty {
                Text("Поливов ещё не было. Полить можно из меню сверху.")
                    .font(Typography.settingNote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.blurReplace)
            } else {
                tally(diary)
                    .transition(.blurReplace)
                ForEach(Array(diary.entries.prefix(Diary.shown)),
                        id: \.self) { moment in
                    entry(moment)
                        .transition(.blurReplace)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 25)
        .padding(.vertical, 22)
        .sproutPlate(in: plate)
        .sproutRide()
    }

    /// Сколько всего и как часто — двумя числами в ряд.
    private func tally(_ diary: Diary) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 28) {
            figure("\(diary.total)", caption: "Всего")
            if let average = diary.average {
                figure(Diary.rhythm(average), caption: "В среднем")
                    .transition(.blurReplace)
            }
        }
        .padding(.bottom, 4)
    }

    private func figure(_ value: String, caption: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(Typography.detail)
                .foregroundStyle(Palette.ink)
                .contentTransition(.numericText())
            Text(caption)
                .font(Typography.figureCaption)
                .foregroundStyle(.secondary)
        }
    }

    /// Один полив: капля и когда.
    private func entry(_ moment: Date) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "drop.fill")
                .font(Typography.settingNote)
                .foregroundStyle(Palette.water)
            Text(Diary.label(moment))
                .font(Typography.settingRow)
                .foregroundStyle(Palette.ink)
        }
    }

    private var plate: RoundedRectangle {
        RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous)
    }

    private func fact(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("•")
            Text(text)
        }
        .font(Typography.detail)
        .foregroundStyle(Palette.ink)
    }
}

/// Проступание из размытия.
///
/// Так в Музыке появляется верх экрана, когда открываешь альбом: обложка
/// встаёт на место, а панель над ней собирается из расфокуса. Одной
/// прозрачности для этого мало — она читается затемнением, а не
/// наведением резкости.
///
/// Анимация объявлена здесь, у самой вью, а не наведена снаружи через
/// `withAnimation`. Содержимое панели живёт не в дереве SwiftUI, а внутри
/// панели UIKit, и наведённая снаружи анимация до него не доходит: имя и
/// кнопка просто оказывались на месте. Объявленная у вью — доходит.
private struct Chrome: ViewModifier {
    let shown: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .blur(radius: shown || reduceMotion ? 0 : Metrics.chromeBlur)
            .opacity(shown ? 1 : 0)
            .animation(shown ? Motion.chrome : Motion.chromeOut, value: shown)
    }
}
