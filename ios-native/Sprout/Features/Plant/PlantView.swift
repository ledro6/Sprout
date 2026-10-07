import ImagePlayground
import SwiftUI

/// Экран растения сверху вниз: фото, «Полить сейчас», действия, сведения,
/// заметки и история поливов. Растение берётся из сада по номеру, а не
/// копией: его поливают и правят прямо здесь, а почва подсыхает сама.
struct PlantView: View {
    let plantID: Plant.ID

    @Environment(Garden.self) private var garden
    @Environment(\.dismiss) private var dismiss

    /// Нет Image Playground — нет и «Портрета»: неработающей кнопки не
    /// показываем.
    @Environment(\.supportsImagePlayground) private var playground

    @State private var renaming = false
    @State private var draft = ""

    @State private var moving = false
    @State private var roomDraft = ""

    @State private var tuning = false

    @State private var staging = false

    @State private var modelling = false

    @State private var diagnosing = false

    @State private var portraying = false

    @State private var asking = false

    /// «Спросить о растении» — выбор: по фото («Что с ним?») или вопросом
    /// («Спросить сад» о нём).
    @State private var choosing = false
    /// «Подключить датчик» — лист поиска датчика.
    @State private var linking = false

    /// Открытка для друзей — см. `PosterSheet`.
    @State private var posting = false

    /// Заметка правится на месте и ложится в сад, когда поле отпускают.
    @State private var noteDraft = ""
    @FocusState private var writing: Bool

    /// Отсюда идёт волна полива. Не состоянием — см. `Spot`.
    @State private var spot = Spot()

    @State private var chrome = false

    /// Список записей под графиком — свёрнут: он нужен, чтобы удалить
    /// ошибочную.
    @State private var listing = false

    private var plant: Plant? { garden.plant(id: plantID) }

    var body: some View {
        ScrollViewReader { reader in
            ScrollView {
                if let plant {
                    // Без стеклянного контейнера: он склеил бы экран в один слой
                    // и сломал разворачивание карточки.
                    VStack(spacing: Metrics.plantGap) {
                        photo(plant)
                            .hintSpot(.plantPhoto)
                        VStack(spacing: Metrics.actionGap) {
                            pour
                                .hintSpot(.plantPour)
                            tools(plant)
                                .hintSpot(.plantTools)
                        }
                        if let days = Rhythm.suggest(for: plant, log: garden.log) {
                            rhythm(plant, days: days)
                                .transition(.blurReplace)
                        }
                        care(plant)
                        if let plan = plant.treatment {
                            TreatmentCard(plant: plant, plan: plan)
                                .transition(.blurReplace)
                        }
                        facts(plant)
                        notes
                            .hintSpot(.plantNotes)
                        diary(plant)
                            .hintSpot(.plantDiary)
                    }
                    .animation(Motion.enter,
                               value: Rhythm.suggest(for: plant, log: garden.log))
                    .padding(.horizontal, Metrics.margin)
                    .padding(.top, 14)
                    .padding(.bottom, Metrics.barGap)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .background { SproutBackground() }
            .walk(.plant, scroll: reader)
        }
        .navigationTitle(plant?.name ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .scrollEdgeEffectStyle(.soft, for: .top)
        .sproutSettledEdge()
        // Своя кнопка «назад»: системную не размыть. Жест свайпа от края
        // UIKit с ней выключает — возвращаем его сами.
        .navigationBarBackButtonHidden(true)
        .sproutSwipeBack()
        .toolbar {
            // Без общей подложки панели: она не размывалась — значок
            // проступал, а капсула стояла с первого кадра.
            ToolbarItem(placement: .topBarLeading) { back }
                .sharedBackgroundVisibility(.hidden)
            ToolbarItem(placement: .principal) { title }
            ToolbarItem(placement: .topBarTrailing) { actions }
                .sharedBackgroundVisibility(.hidden)
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Готово") { writing = false }
            }
        }
        // Панель проступает, отстав от разворачивания карточки. Отставание
        // здесь, а не задержкой анимации — иначе с задержкой шёл бы и уход; и
        // отдельным проходом — смену в проходе появления SwiftUI схлопывает.
        .onAppear {
            noteDraft = plant?.note ?? ""
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
            Button("Переместить") { relocate(to: roomDraft) }
        } message: {
            Text("Растение переедет туда, и комната появится в списке.")
        }
        .sheet(isPresented: $tuning) {
            PlantSettingsView(plantID: plantID).environment(garden)
        }
        .sheet(isPresented: $posting) {
            PosterSheet(poster: .plant(plantID)).environment(garden)
        }
        .fullScreenCover(isPresented: $staging) {
            PlantAR(plantID: plantID).environment(garden)
        }
        .sheet(isPresented: $modelling) {
            ModelSheet(plantID: plantID).environment(garden)
        }
        // Один вход на два режима. «Вопросом» есть и без Apple
        // Intelligence: лист объяснит, чего не хватает, а не пропадёт.
        .confirmationDialog("Спросить о растении", isPresented: $choosing,
                            titleVisibility: .visible) {
            Button("По фото") { diagnosing = true }
            Button("Вопросом") { asking = true }
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("Разбирается на телефоне, ничего не отправляется.")
        }
        .sheet(isPresented: $diagnosing) {
            DiagnosisSheet(plantID: plantID).environment(garden)
        }
        .sheet(isPresented: $asking) {
            AskView(focus: plantID).environment(garden)
        }
        .sheet(isPresented: $linking) {
            SensorPicker(plantID: plantID).environment(garden)
        }
        // Стиль выбирают в самом листе; готовый портрет встаёт обложкой.
        .imagePlaygroundSheet(isPresented: $portraying, concepts: concepts,
                              sourceImage: likeness) { file in
            portray(file)
        }
        // Растение удалили — экран закрывается сам; вернуть можно с плашки
        // внизу.
        .onChange(of: plant == nil) { _, gone in
            if gone { close() }
        }
        .onChange(of: writing) { _, now in
            if !now { keepNote() }
        }
        // Закрыли экран, не отпустив поле, — заметка всё равно сохраняется.
        .onDisappear { keepNote() }
    }

    /// Круг крупнее системной кнопки «назад»: до неё тянуться через весь
    /// экран, и маленькая промахивалась.
    private var back: some View {
        Button { close() } label: {
            Image(systemName: "chevron.backward")
                .modifier(NavCircle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Назад")
        .modifier(Chrome(shown: chrome))
        .sproutRide()
    }

    /// Свой заголовок: системный появляется разом, его не размыть.
    private var title: some View {
        Text(plant?.name ?? "")
            .font(Typography.navTitle)
            .foregroundStyle(Palette.ink)
            .lineLimit(1)
            .contentTransition(.numericText())
            .modifier(Chrome(shown: chrome))
            .sproutRide()
    }

    /// `.button` заставляет меню принять стиль кнопки. Полива здесь нет — он
    /// большой кнопкой под фото.
    private var actions: some View {
        Menu {
            Button {
                draft = plant?.name ?? ""
                renaming = true
            } label: {
                Label("Переименовать", systemImage: "pencil")
            }
            Button { tuning = true } label: {
                Label("Настройки", systemImage: "slider.horizontal.3")
            }
            if playground {
                Button { portraying = true } label: {
                    Label(portrayed ? "Новый портрет" : "Портрет",
                          systemImage: "apple.image.playground")
                }
                if portrayed {
                    Button(action: unportray) {
                        Label("Вернуть фото", systemImage: "photo")
                    }
                }
            }
            Button { choosing = true } label: {
                Label("Спросить о растении",
                      systemImage: "bubble.left.and.text.bubble.right")
            }
            // Черенок — кодом в переписку: друг посадит его со всем уходом.
            if let plant {
                ShareLink(item: Cutting(plant: plant, from: garden.signed).card) {
                    Label("Поделиться", systemImage: "square.and.arrow.up")
                }
            }
            // А это — картинкой, просто показать.
            Button { posting = true } label: {
                Label("Поделиться карточкой", systemImage: "photo.on.rectangle")
            }
            if Tags.ready {
                Button { Tags.shared.write(plantID) } label: {
                    Label("Привязать метку",
                          systemImage: "sensor.tag.radiowaves.forward")
                }
            }
            Button { Coach.shared.start(.plant) } label: {
                Label("Подсказки", systemImage: "questionmark.circle")
            }
            MoveMenu(current: garden.roomName(of: plantID),
                     rooms: garden.rooms.map(\.name),
                     move: relocate,
                     ask: {
                         roomDraft = ""
                         moving = true
                     })
            Button(role: .destructive) { toss() } label: {
                Label("Удалить", systemImage: "trash")
            }
        } label: {
            Image(systemName: "ellipsis")
                .modifier(NavCircle())
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .modifier(Chrome(shown: chrome))
        .sproutRide()
    }

    /// Закрытие ждёт, пока панель растворится: на складывание UIKit снимает с
    /// неё кадр, и иначе в нём была бы резкая панель. Потянули экран вниз —
    /// закрывает само разворачивание, мимо этого.
    private func close() {
        writing = false
        keepNote()
        chrome = false
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(Motion.chromeLead))
            dismiss()
        }
    }

    /// Полив с анимацией, иначе тревожная тень гасла бы щелчком.
    private func water() {
        guard Bin.shared.water(plantID, in: garden) else { return }
        Cheer.shared.now(from: spot.rect)
        Feel.water()
    }

    /// Красное идёт от плашки с фото.
    private func toss() {
        Bin.shared.toss(plantID, from: spot.rect, in: garden)
    }

    private func relocate(to room: String) {
        withAnimation(Motion.number) { garden.relocate(plantID, to: room) }
    }

    private var portrayed: Bool { plant?.portrait != nil }

    /// Понятие для листа — вид растения, см. `Portrait`.
    private var concepts: [ImagePlaygroundConcept] {
        guard let plant else { return [] }
        return Portrait.concepts(for: plant)
            .map { ImagePlaygroundConcept.text($0) }
    }

    /// Затравка портрета — своё фото, а нет его — рисунок вида. Прежний
    /// портрет затравкой не берём: новый рисуется с натуры.
    private var likeness: Image? {
        guard let plant else { return nil }
        if let shot = plant.shot, let image = Snapshot.image(shot) {
            return Image(uiImage: image)
        }
        return Image(plant.photo)
    }

    private func portray(_ file: URL) {
        guard let name = Snapshot.keep(contentsOf: file) else { return }
        withAnimation(Motion.appear) { garden.portray(plantID, file: name) }
        Feel.done()
    }

    /// «Вернуть фото»: портрет уходит, обложкой снова снимок.
    private func unportray() {
        withAnimation(Motion.appear) { garden.unportray(plantID) }
        Feel.toss()
    }

    /// Звук — только если заметка правда изменилась: отпустить поле ещё не
    /// значит что-то сохранить.
    private func keepNote() {
        guard let plant else { return }
        let before = plant.note
        garden.note(plantID, noteDraft)
        let after = garden.plant(id: plantID)?.note
        noteDraft = after ?? ""
        if after != before { Feel.done() }
    }

    /// Шёпотом, как в «Заметках»: крупная подсказка читалась бы уже записанным.
    private var notes: some View {
        VStack(alignment: .leading, spacing: Metrics.diaryGap) {
            Text("Заметки")
                .font(Typography.groupTitle)
                .foregroundStyle(Palette.secondaryText)
            TextField("Пересадка, удобрения, где любит стоять…",
                      text: $noteDraft, axis: .vertical)
                .textFieldStyle(.plain)
                .font(Typography.settingRow)
                .foregroundStyle(Palette.ink)
                .lineLimit(1 ... 12)
                .focused($writing)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 25)
        .padding(.vertical, 22)
        .sproutPlate(in: plate)
        .sproutRide()
    }

    private func forget(_ moment: Date) {
        withAnimation(Motion.appear) {
            garden.forget(Watering(plant: plantID, when: moment))
        }
        Feel.toss()
    }

    /// В макете 336×347: квадратное фото плюс поля.
    private func photo(_ plant: Plant) -> some View {
        PlantPhoto(plant: plant, radius: Metrics.cardRadius - 6)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity)
            .aspectRatio(336.0 / 347.0, contentMode: .fit)
            .sproutPlate(in: plate)
            .modifier(PlantGlow(plant: plant, shape: plate))
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) }
                action: { spot.rect = $0 }
            // Отсюда волна трогается — эта плашка подпрыгивает первой.
            .sproutRide()
    }

    /// Главное действие экрана — широкой синей кнопкой, как в системных
    /// приложениях iOS 26.
    private var pour: some View {
        Button(action: water) {
            Label("Полить сейчас", systemImage: "drop.fill")
                .font(Typography.detail)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.glassProminent)
        .tint(Palette.accentFill)
        .controlSize(.extraLarge)
        .sproutRide()
    }

    /// Остальные действия — квадратными плитками стекла: значок и под ним
    /// подпись до двух строк, без ужатия — в широком прямоугольнике она
    /// мельчала и не читалась. Без дополненной реальности плиток две, того
    /// же размера, у левого края.
    private func tools(_ plant: Plant) -> some View {
        HStack(spacing: Metrics.actionGap) {
            if PlantAR.available {
                tool("В AR", action: { staging = true }) {
                    ModelMark(plant: plant)
                }
                tool("Модель", icon: "cube.transparent") { modelling = true }
            }
            tool("Спросить о растении",
                 icon: "bubble.left.and.text.bubble.right") { choosing = true }
            tool("Настройки", icon: "slider.horizontal.3") { tuning = true }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .sproutRide()
    }

    private func tool(_ title: LocalizedStringKey, icon: String,
                      action: @escaping () -> Void) -> some View {
        tool(title, action: action) { Image(systemName: icon) }
    }

    /// Знак над подписью — в строку высотой с текст: значок, проценты и
    /// крутилка сменяют друг друга, не толкая кнопку.
    private func tool(_ title: LocalizedStringKey, action: @escaping () -> Void,
                      @ViewBuilder mark: () -> some View) -> some View {
        // Стекло — своё, а не стилем кнопки: у стиля поля шире, и подписи
        // в квадрате не хватало места.
        Button(action: action) {
            VStack(spacing: 6) {
                Text(Bench.percent(1))
                    .hidden()
                    .overlay { mark() }
                    .font(Typography.navTitle)
                Text(title)
                    .font(Typography.settingNote.weight(.medium))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(Palette.ink)
            .padding(6)
            .frame(maxWidth: .infinity, minHeight: Metrics.toolTile)
            .sproutGlass(in: .rect(cornerRadius: Metrics.toolRadius))
            .contentShape(.rect(cornerRadius: Metrics.toolRadius))
        }
        .buttonStyle(SproutPress())
        .frame(maxWidth: Metrics.toolTile)
    }

    /// Поливают раньше срока — предложение сократить его. Отказ запоминается:
    /// то же предложение больше не всплывёт.
    private func rhythm(_ plant: Plant, days: Double) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Label("Поливаете раньше срока",
                      systemImage: "calendar.badge.clock")
                    .font(Typography.detail)
                    .foregroundStyle(Palette.ink)
                TermHint(.rhythm)
            }
            Text(Lang.format("Похоже, земля сохнет быстрее: %1$@ вместо %2$@.",
                             Species.periodPhrase(days),
                             Species.periodPhrase(plant.dryingDays)))
                .font(Typography.settingNote)
                .foregroundStyle(Palette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: Metrics.actionGap) {
                Button { adopt(days) } label: {
                    Text("Поменять срок")
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .tint(Palette.accentFill)
                Button {
                    withAnimation(Motion.enter) { garden.quiet(plantID, days) }
                } label: {
                    Text("Оставить")
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glass)
            }
            .font(Typography.settingRow)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 25)
        .padding(.vertical, 22)
        .sproutPlate(in: plate)
        .sproutRide()
    }

    private func adopt(_ days: Double) {
        guard let plant else { return }
        withAnimation(Motion.number) {
            garden.tune(plantID, name: plant.name, species: plant.species,
                        dryingDays: days)
        }
        Feel.done()
    }

    /// Подкормка, пересадка и мелкий уход: сколько осталось и кнопка
    /// «сделал». Всё выключено в настройках растения — плашки нет.
    @ViewBuilder
    private func care(_ plant: Plant) -> some View {
        let tending = plant.tending
        let errands = tending.errands
        if tending.feedEvery != nil || tending.repotEvery != nil
            || !errands.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                Text("Уход")
                    .font(Typography.groupTitle)
                    .foregroundStyle(Palette.secondaryText)
                if let line = tending.feedLabel {
                    chore(line, due: tending.feedDue, done: "Подкормил",
                          icon: "sparkles", term: .feeding) {
                        garden.feed(plantID)
                        Cabinet.shared.deed(.feeder)
                    }
                }
                if let line = tending.repotLabel {
                    chore(line, due: tending.repotDue, done: "Пересадил",
                          icon: "arrow.up.bin", term: .repotting) {
                        garden.repot(plantID)
                    }
                }
                ForEach(errands) { duty in
                    if let line = tending.label(duty) {
                        chore(line, due: tending.due(duty),
                              done: LocalizedStringKey(duty.done),
                              icon: duty.icon) {
                            garden.did(duty, on: plantID)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 25)
            .padding(.vertical, 22)
            .sproutPlate(in: plate)
            .sproutRide()
        }
    }

    /// Срок — переходом цифр; пора — синим, как всё, что ждёт действия.
    private func chore(_ line: String, due: Bool, done: LocalizedStringKey,
                       icon: String, term: Term? = nil,
                       action: @escaping () -> Void) -> some View {
        HStack(spacing: 12) {
            HStack(spacing: 6) {
                Text(line)
                    .font(Typography.detail)
                    .foregroundStyle(due ? Palette.accent : Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .contentTransition(.numericText())
                if let term { TermHint(term) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button {
                withAnimation(Motion.number) { action() }
                Feel.done()
            } label: {
                Label(done, systemImage: icon)
                    .font(Typography.settingNote)
                    .lineLimit(1)
                    .fixedSize()
            }
            .buttonStyle(.glass)
        }
    }

    private func facts(_ plant: Plant) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            // Одна строка: процент, откуда он и заряд датчика.
            fact(plant.moistureLine, term: .moisture)
                .contentTransition(.numericText())
            // Статус — словами и значком общего движка, см. `StatusStyle`.
            StatusLabel(status: plant.status)
                .font(Typography.detail)
                .foregroundStyle(Palette.ink)
                .animation(Motion.number, value: plant.status)
            if plant.sensor == nil {
                Button { linking = true } label: {
                    Label("Подключить датчик — точная влажность",
                          systemImage: "sensor.fill")
                        .font(Typography.settingNote)
                }
                .buttonStyle(.glass)
            }
            fact(plant.species)
            // Сразу под видом: питомца касается вид, а не кличка.
            if let danger = Toxicity.of(plant.species) {
                fact(danger.line, term: .pets, tone: tone(of: danger))
            }
            fact(plant.wateringLabel, term: .period)
                .contentTransition(.numericText())
            if let credit = credit(plant) {
                fact(credit)
                    .transition(.blurReplace)
            }
            if let room = garden.roomName(of: plant.id) {
                fact(Lang.format("Комната «%@»", room))
                    .contentTransition(.numericText())
            }
            if let season = Season.line(stretch: Season.stretch) {
                fact(season)
            }
            if Settings.shared.weather, let climate = Settings.shared.climate,
               climate.fresh(),
               let line = climate.line(outdoor: Climate.outdoor(
                   garden.roomName(of: plant.id) ?? "")) {
                fact(line, term: .weather)
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

    /// История поливов: сколько и как часто, график высыхания и, под
    /// раскрывашкой, сами записи. Новое приходит `blurReplace`, числа —
    /// переходом цифр.
    private func diary(_ plant: Plant) -> some View {
        let diary = Diary.of(garden.log, plant: plant.id)
        return VStack(alignment: .leading, spacing: Metrics.diaryGap) {
            Text("Поливы")
                .font(Typography.groupTitle)
                .foregroundStyle(Palette.secondaryText)
            if diary.entries.isEmpty {
                Text("Поливов ещё не было.")
                    .font(Typography.settingNote)
                    .foregroundStyle(Palette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.blurReplace)
            } else {
                tally(diary)
                    .transition(.blurReplace)
                DryingChart(points: Diary.curve(garden.log, plant: plant))
                    .transition(.blurReplace)
                DisclosureGroup(isExpanded: $listing.animation(Motion.pill)) {
                    VStack(alignment: .leading, spacing: Metrics.diaryGap) {
                        ForEach(Array(diary.entries.prefix(Diary.shown)),
                                id: \.self) { moment in
                            entry(moment)
                                .transition(.blurReplace)
                        }
                        Text("Ошибочную запись удалит долгое нажатие.")
                            .font(Typography.settingNote)
                            .foregroundStyle(Palette.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 4)
                    }
                    .padding(.top, 8)
                } label: {
                    Text("Записи")
                        .font(Typography.settingRow)
                        .foregroundStyle(Palette.ink)
                }
                .tint(Palette.accent)
                .transition(.blurReplace)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 25)
        .padding(.vertical, 22)
        .sproutPlate(in: plate)
        .sproutRide()
    }

    private func tally(_ diary: Diary) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 28) {
            figure(diary.total.formatted(), caption: "Всего")
            if let average = diary.average {
                figure(Diary.rhythm(average), caption: "В среднем")
                    .transition(.blurReplace)
            }
        }
        .padding(.bottom, 4)
    }

    private func figure(_ value: String,
                        caption: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(Typography.detail)
                .foregroundStyle(Palette.ink)
                .contentTransition(.numericText())
            Text(caption)
                .font(Typography.figureCaption)
                .foregroundStyle(Palette.secondaryText)
        }
    }

    /// Удалить — долгим нажатием: запись маленькая, смахивание по ней
    /// спорило бы с прокруткой. В общем саду под чужим поливом — кто полил.
    private func entry(_ moment: Date) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "drop.fill")
                .font(Typography.settingNote)
                .foregroundStyle(Palette.water)
            VStack(alignment: .leading, spacing: 2) {
                Text(Diary.label(moment))
                    .font(Typography.settingRow)
                    .foregroundStyle(Palette.ink)
                if let who = signature(of: moment) {
                    Text(who)
                        .font(Typography.settingNote)
                        .foregroundStyle(Palette.secondaryText)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(.contextMenuPreview,
                      RoundedRectangle(cornerRadius: 12, style: .continuous))
        .contextMenu {
            Button(role: .destructive) { forget(moment) } label: {
                Label("Удалить запись", systemImage: "trash")
            }
        }
    }

    private var plate: RoundedRectangle {
        RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous)
    }

    /// Последний полив — чужой: «Полила Маша, 9:55». Свой не подписываем.
    private func credit(_ plant: Plant) -> String? {
        guard Kinship.enabled,
              let last = garden.log.last(where: { $0.plant == plant.id })
        else { return nil }
        return Kinship.shared.credit(last)
    }

    /// Кто полил в этот миг, если не хозяин телефона: «Полила Маша».
    private func signature(of moment: Date) -> String? {
        guard Kinship.enabled,
              let entry = garden.log.last(where: {
                  $0.plant == plantID && $0.when == moment
              })
        else { return nil }
        return Kinship.shared.signature(entry)
    }

    private func fact(_ text: String, term: Term? = nil,
                      tone: Color = Palette.ink) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text("•")
            Text(text)
            if let term { TermHint(term) }
        }
        .font(Typography.detail)
        .foregroundStyle(tone)
    }

    /// Смертельное — красным, ядовитое — оранжевым, как тень тревоги;
    /// безопасное — обычным цветом: хорошая новость не кричит.
    private func tone(of danger: Toxicity) -> Color {
        switch danger {
        case .safe: Palette.ink
        case .toxic: Palette.warn
        case .lily, .deadly: Palette.alarm
        }
    }
}

/// Проступание из размытия, как верх экрана альбома в Музыке. Анимация
/// объявлена у самой вью: содержимое панели живёт в UIKit, и `withAnimation`
/// снаружи до него не доходит.
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

/// Знак на кнопке AR: значок, а пока собирается своя модель по снимку —
/// её проценты. AR открывается и тогда: до конца сборки в нём модель вида.
/// Своим вью: доли меняются на каждый процент, и перерисовываться с ними
/// должен знак, а не весь экран.
private struct ModelMark: View {
    let plant: Plant

    var body: some View {
        let share = Bench.shared.share(plant)
        Group {
            if let share, share < 1 {
                Text(Bench.percent(share))
                    .monospacedDigit()
                    .contentTransition(.numericText())
            } else {
                Image(systemName: "arkit")
            }
        }
        .animation(Motion.number, value: share)
    }
}

/// Кнопка панели — стеклянный круг одного размера у «назад» и у меню:
/// стиль `.glass` у меню добавлял свои поля, и круг выходил больше. Те же
/// круги — в шапке планетария.
struct NavCircle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(Typography.navButton)
            .foregroundStyle(Palette.ink)
            .frame(width: Metrics.navCircle, height: Metrics.navCircle)
            .glassEffect(.regular.interactive(), in: .circle)
            .contentShape(.circle)
    }
}
