import SwiftUI

/// Экран растения: фото, сведения, заметки и история поливов. Растение
/// берётся из сада по номеру, а не копией: его поливают и правят прямо здесь,
/// а почва подсыхает сама.
struct PlantView: View {
    let plantID: Plant.ID

    @Environment(Garden.self) private var garden
    @Environment(\.dismiss) private var dismiss

    @State private var renaming = false
    @State private var draft = ""

    @State private var moving = false
    @State private var roomDraft = ""

    @State private var tuning = false

    @State private var staging = false

    /// Заметка правится на месте и ложится в сад, когда поле отпускают.
    @State private var noteDraft = ""
    @FocusState private var writing: Bool

    /// Отсюда идёт волна полива. Не состоянием — см. `Spot`.
    @State private var spot = Spot()

    @State private var chrome = false

    private var plant: Plant? { garden.plant(id: plantID) }

    var body: some View {
        ScrollView {
            if let plant {
                // Без стеклянного контейнера: он склеил бы экран в один слой
                // и сломал разворачивание карточки.
                VStack(spacing: 44) {
                    photo(plant)
                    facts(plant)
                    notes
                    diary(plant)
                }
                .padding(.horizontal, Metrics.margin)
                .padding(.top, 14)
                .padding(.bottom, 40)
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .background { SproutBackground() }
        .navigationTitle(plant?.name ?? "")
        .navigationBarTitleDisplayMode(.inline)
        // Своя кнопка «назад»: системную не размыть. Жест свайпа от края при
        // этом пропадает, возврат потягиванием вниз остаётся.
        .navigationBarBackButtonHidden(true)
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
            Button("Переехать") { relocate(to: roomDraft) }
        } message: {
            Text("Растение переедет туда, и комната появится в списке.")
        }
        .sheet(isPresented: $tuning) {
            PlantSettingsView(plantID: plantID).environment(garden)
        }
        .fullScreenCover(isPresented: $staging) {
            PlantAR(plantID: plantID).environment(garden)
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
            Button { tuning = true } label: {
                Label("Настройки", systemImage: "slider.horizontal.3")
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
                .font(Typography.navTitle)
        }
        .menuStyle(.button)
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
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
                .foregroundStyle(.secondary)
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
            .overlay(alignment: .bottomTrailing) {
                if PlantAR.available {
                    Button { staging = true } label: {
                        Label("Посмотреть в AR", systemImage: "arkit")
                            .font(Typography.settingNote)
                    }
                    .buttonStyle(.glass)
                    .padding(16)
                }
            }
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) }
                action: { spot.rect = $0 }
            // Отсюда волна трогается — эта плашка подпрыгивает первой.
            .sproutRide()
    }

    private func facts(_ plant: Plant) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            fact("Влажность \(plant.moistureLabel)")
                .contentTransition(.numericText())
            fact(plant.species)
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

    /// История поливов. Новая строка приходит `blurReplace`, числа —
    /// переходом цифр; вытесненная строка уходит тем же размытием.
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
                Text("Ошибочную запись удалит долгое нажатие.")
                    .font(Typography.settingNote)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
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

    /// Удалить — долгим нажатием: запись маленькая, смахивание по ней
    /// спорило бы с прокруткой.
    private func entry(_ moment: Date) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "drop.fill")
                .font(Typography.settingNote)
                .foregroundStyle(Palette.water)
            Text(Diary.label(moment))
                .font(Typography.settingRow)
                .foregroundStyle(Palette.ink)
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

    private func fact(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("•")
            Text(text)
        }
        .font(Typography.detail)
        .foregroundStyle(Palette.ink)
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
