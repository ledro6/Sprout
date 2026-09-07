import SwiftUI

/// Экран одного растения: фото, влажность и сведения.
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
                VStack(spacing: 22) {
                    photo(plant)
                    moisture(plant)
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
            Text("Растение исчезнет из комнаты. Отменить будет нельзя.")
        }
        // Растение удалили — экран закрывается сам: показывать больше
        // нечего, а пустой он выглядел бы поломкой.
        .onChange(of: plant == nil) { _, gone in
            if gone { dismiss() }
        }
    }

    private var actions: some View {
        Menu {
            Button {
                withAnimation(.smooth) { garden.water(plantID) }
            } label: {
                Label("Полить сейчас", systemImage: "drop.fill")
            }
            Button {
                draft = plant?.name ?? ""
                renaming = true
            } label: {
                Label("Переименовать", systemImage: "pencil")
            }
            Button(role: .destructive) {
                deleting = true
            } label: {
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
    }

    private func moisture(_ plant: Plant) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(plant.moistureLabel)
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(Palette.moisture(plant.moisture))
                    .monospacedDigit()
                Spacer(minLength: 12)
                Button {
                    withAnimation(.smooth) { garden.water(plantID) }
                } label: {
                    Label("Полить", systemImage: "drop.fill")
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .tint(Palette.accent)
            }
            MoistureBar(level: plant.moisture, height: 8)
            Text(plant.wateringLabel)
                .font(Typography.cardCaption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .sproutPlate(in: plate)
    }

    private func facts(_ plant: Plant) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            fact(plant.species)
            if let room = garden.roomName(of: plant.id) {
                fact("Стоит в комнате \(room)")
            }
            fact("Сохнет за \(days(plant)) "
                 + Plant.plural(days(plant), "сутки", "суток", "суток"))
            fact(plant.addedLabel)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 25)
        .padding(.vertical, 22)
        .sproutPlate(in: plate)
    }

    private func days(_ plant: Plant) -> Int { Int(plant.dryingDays.rounded()) }

    private func fact(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("•")
            Text(text)
        }
        .font(Typography.detail)
        .foregroundStyle(.black)
    }

    private var plate: RoundedRectangle {
        RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous)
    }
}
