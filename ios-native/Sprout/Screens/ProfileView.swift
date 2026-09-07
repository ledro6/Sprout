import SwiftUI

/// Профиль: хозяин сада, скорость времени и комнаты.
struct ProfileView: View {
    @Environment(Garden.self) private var garden

    @State private var renaming = false
    @State private var draft = ""

    var body: some View {
        @Bindable var garden = garden
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    SectionTitle("Профиль")
                    owner

                    PlateSection("Скорость времени") {
                        Picker("Скорость", selection: $garden.speed) {
                            ForEach(TimeSpeed.allCases) { speed in
                                Text(speed.title).tag(speed)
                            }
                        }
                        .pickerStyle(.segmented)
                        Text(garden.speed.hint)
                            .font(Typography.cardCaption)
                            .foregroundStyle(.secondary)
                    }

                    PlateSection("Комнаты") {
                        ForEach(garden.rooms) { room in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(alignment: .firstTextBaseline) {
                                    Text(room.name)
                                        .font(Typography.cardTitle)
                                        .foregroundStyle(.black)
                                    Spacer(minLength: 8)
                                    Text(count(room.plants.count))
                                        .font(Typography.cardCaption)
                                        .foregroundStyle(.secondary)
                                }
                                MoistureBar(level: room.averageMoisture)
                            }
                        }
                    }
                }
                .padding(.bottom, 28)
            }
            .background { SproutBackground() }
            .toolbar(.hidden, for: .navigationBar)
            .alert("Как вас зовут?", isPresented: $renaming) {
                TextField("Имя", text: $draft)
                Button("Отмена", role: .cancel) {}
                Button("Сохранить") {
                    let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty { garden.owner = trimmed }
                }
            }
        }
    }

    private var owner: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(Palette.greenSoft)
                SproutLogo(height: 30)
            }
            .frame(width: 62, height: 62)

            VStack(alignment: .leading, spacing: 3) {
                Text(garden.owner)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.black)
                    .lineLimit(1)
                Text(summary)
                    .font(Typography.cardCaption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            Button {
                draft = garden.owner
                renaming = true
            } label: {
                Image(systemName: "pencil")
                    .font(.system(size: 15, weight: .semibold))
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.capsule)
            .tint(Palette.accent)
            .accessibilityLabel("Изменить имя")
        }
        .padding(16)
        .sproutPlate(
            in: RoundedRectangle(cornerRadius: Metrics.rowRadius,
                                 style: .continuous))
        .padding(.horizontal, Metrics.contentMargin)
    }

    private var summary: String {
        let plants = garden.allPlants.count
        let rooms = garden.rooms.count
        return "\(count(plants)) в \(rooms) "
            + Plant.plural(rooms, "комнате", "комнатах", "комнатах")
    }

    private func count(_ n: Int) -> String {
        "\(n) " + Plant.plural(n, "растение", "растения", "растений")
    }
}
