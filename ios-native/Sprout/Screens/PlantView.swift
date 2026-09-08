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
            ToolbarItem(placement: .topBarTrailing) { actions }
        }
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

    /// Меню в панели. Полив идёт с анимацией: проценты прыгают к сотне
    /// разом, и без неё тревожная тень гасла бы щелчком.
    private var actions: some View {
        Menu {
            Button {
                withAnimation(Motion.appear) { garden.water(plantID) }
            } label: {
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
            Image(systemName: "ellipsis")
        }
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
