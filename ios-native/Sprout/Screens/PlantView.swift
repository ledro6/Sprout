import SwiftUI

/// Экран одного растения: фото, сведения и то, что с ним можно сделать.
///
/// Растение берётся из сада по номеру, а не передаётся копией: его тут же
/// поливают и переименовывают, и экран должен показывать живое состояние,
/// а не слепок, снятый при переходе.
///
/// Панель навигации системная: в iOS 26 она сама рисует стеклянные
/// капсулы кнопки «назад» и элементов тулбара, сама держит жест возврата
/// свайпом и сама анимирует переход.
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
                // Обе плашки стеклянные — контейнер сводит их в один
                // проход рисования. Нулевой шаг: сливаться им незачем.
                GlassEffectContainer(spacing: 0) {
                    VStack(spacing: 22) {
                        photo(plant)
                        facts(plant)
                    }
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
            Image(systemName: "ellipsis")
        }
    }

    private func water() {
        withAnimation(Motion.appear) { garden.water(plantID) }
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
    }

    private func facts(_ plant: Plant) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            fact("Влажность \(plant.moistureLabel)")
            fact(plant.species)
            if let room = garden.roomName(of: plant.id) {
                fact("Стоит в комнате \(room)")
            }
            fact(plant.wateringLabel)
            fact(plant.addedLabel)

            Button(action: water) {
                Label("Полить", systemImage: "drop.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .controlSize(.large)
            .tint(Palette.accent)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 25)
        .padding(.vertical, 22)
        .sproutPlate(in: plate)
    }

    private func fact(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("•")
            Text(text)
        }
        .font(Typography.detail)
        .foregroundStyle(Palette.ink)
    }

    private var plate: RoundedRectangle {
        RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous)
    }
}
