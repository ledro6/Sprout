import SwiftUI

/// Экран одного растения: большое фото и карточка со сведениями.
///
/// Панель навигации системная: в iOS 26 она сама рисует стеклянные
/// капсулы кнопки «назад» и элементов тулбара, сама держит жест возврата
/// свайпом и сама анимирует переход. Ничего из этого писать не нужно.
///
/// Плашки фото и сведений — тот же материал, что у карточек на главном,
/// см. `sproutPlate`. Отклика на нажатие у них нет: нажимать нечего.
struct PlantView: View {
    let plant: Plant

    var body: some View {
        ScrollView {
            VStack(spacing: 44) {
                photo
                facts
            }
            .padding(.horizontal, Metrics.margin)
            .padding(.top, 14)
            .padding(.bottom, 40)
        }
        .background { SproutBackground() }
        .navigationTitle(plant.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {} label: {
                        Label("Полить сейчас", systemImage: "drop.fill")
                    }
                    Button {} label: {
                        Label("Переименовать", systemImage: "pencil")
                    }
                    Button(role: .destructive) {} label: {
                        Label("Удалить", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                }
            }
        }
    }

    /// Плашка с фото. В макете 336×347: квадратное фото плюс поля.
    private var photo: some View {
        Image(plant.photo)
            .resizable()
            .scaledToFit()
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity)
            .aspectRatio(336.0 / 347.0, contentMode: .fit)
            .sproutPlate(in: plate)
    }

    private var facts: some View {
        VStack(alignment: .leading, spacing: 14) {
            fact(plant.species)
            fact(plant.wateringLabel)
            fact(plant.addedLabel)
        }
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
        .foregroundStyle(.black)
    }
}
