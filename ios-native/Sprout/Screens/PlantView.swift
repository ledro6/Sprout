import SwiftUI

/// Экран одного растения: большое фото и карточка со сведениями.
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
    @State private var deleting = false

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
                }
                .padding(.horizontal, Metrics.margin)
                .padding(.top, 14)
                .padding(.bottom, 40)
            }
        }
        .background { SproutBackground() }
        .navigationTitle(plant?.name ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) { title }
            // Без общей стеклянной подложки: её рисует панель, а не эта
            // вью, и на размытие она не отзывалась — кнопка проступала, а
            // капсула под ней стояла с первого кадра. Сняв её, капсулу
            // рисуем сами, и проступает кнопка целиком.
            ToolbarItem(placement: .topBarTrailing) { actions }
                .sharedBackgroundVisibility(.hidden)
        }
        // Панель проступает сама, следом за разворачиванием карточки.
        //
        // Отдельным проходом, а не прямо здесь: смену, случившуюся в том
        // же проходе, где вью появилась, SwiftUI схлопывает — панель
        // просто оказывалась на месте, и анимировать было нечего.
        .onAppear { Task { @MainActor in chrome = true } }
        .alert("Переименовать", isPresented: $renaming) {
            TextField("Кличка", text: $draft)
            Button("Отмена", role: .cancel) {}
            Button("Сохранить") { garden.rename(plantID, to: draft) }
        } message: {
            Text("Как теперь зовут растение?")
        }
        .confirmationDialog("Удалить «\(plant?.name ?? "")»?",
                            isPresented: $deleting, titleVisibility: .visible) {
            Button("Удалить", role: .destructive) { garden.delete(plantID) }
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("Растение исчезнет из комнаты. Вернуть его будет нельзя.")
        }
        // Растение удалили — экран закрывается сам: показывать больше
        // нечего, а пустым он выглядел бы поломкой.
        .onChange(of: plant == nil) { _, gone in
            if gone { dismiss() }
        }
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
            .modifier(Chrome(shown: chrome))
    }

    /// Меню в панели. Капсула своя — см. `sharedBackgroundVisibility`
    /// выше.
    ///
    /// Кнопка «назад» осталась системной, со своей капсулой и без
    /// проступания. Сделать своей её нельзя без потери: спрятав
    /// системную, SwiftUI заодно выключает жест возврата свайпом, а
    /// вернуть его можно только руками через UIKit. Полсекунды размытия
    /// того не стоят, и панель она не портит — системный переход и так
    /// вводит её плавно.
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
            Button(role: .destructive) { deleting = true } label: {
                Label("Удалить", systemImage: "trash")
            }
        } label: {
            // Цвет не задаём: кнопка идёт за общим оттенком приложения,
            // как и системная «назад» рядом.
            Image(systemName: "ellipsis")
                .font(Typography.navTitle)
                .frame(width: Metrics.barButton, height: Metrics.barButton)
                .glassEffect(.regular.interactive(), in: Circle())
        }
        .modifier(Chrome(shown: chrome))
    }

    /// Полить: сад меняет влажность, а по узору от плашки с фото
    /// расходится волна.
    ///
    /// Полив с анимацией: проценты прыгают к сотне разом, и без неё
    /// тревожная тень гасла бы щелчком.
    private func water() {
        withAnimation(Motion.appear) { garden.water(plantID) }
        Cheer.shared.now(from: spot.middle)
    }

    /// Плашка с фото. В макете 336×347: квадратное фото плюс поля.
    private func photo(_ plant: Plant) -> some View {
        Image(plant.photo)
            .resizable()
            .scaledToFit()
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
    }

    private func facts(_ plant: Plant) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            // Влажность первой строкой: она здесь единственное, что
            // меняется само, и смотреть на таймер удобнее всего тут.
            // Меняются только цифры — числовым переходом системы.
            fact("Влажность \(plant.moistureLabel)")
                .contentTransition(.numericText())
            fact(plant.species)
            fact(plant.wateringLabel)
            fact(plant.addedLabel)
        }
        .animation(Motion.number, value: plant.moisture)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 25)
        .padding(.vertical, 22)
        .sproutPlate(in: plate)
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
            .animation(Motion.chrome, value: shown)
    }
}
