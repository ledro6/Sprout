import SwiftUI

/// Добавить растение: кличка, вид, комната и как часто поливать.
struct AddView: View {
    @Environment(Garden.self) private var garden

    @State private var name = ""
    @State private var species = ""
    @State private var roomIndex = 0
    @State private var dryingDays = 7.0
    /// Что показать после посадки. Держим текстом: растение уже уехало в
    /// свою комнату и меняется там своей жизнью.
    @State private var planted: String?

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    SectionTitle("Добавить")

                    PlateSection("Растение") {
                        field("Кличка", text: $name, hint: "Баксик")
                        Divider()
                        field("Вид", text: $species, hint: "Монстера")
                    }

                    PlateSection("Комната") {
                        Picker("Комната", selection: $roomIndex) {
                            ForEach(garden.rooms.indices, id: \.self) { index in
                                Text(garden.rooms[index].name).tag(index)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    PlateSection("Полив") {
                        Text("Раз в \(days) " + Plant.plural(days, "день", "дня", "дней"))
                            .font(Typography.cardTitle)
                            .foregroundStyle(.black)
                        Slider(value: $dryingDays, in: 3...60, step: 1)
                            .tint(Palette.accent)
                        Text("За столько почва высыхает от полного полива "
                             + "досуха. У кактуса это месяц, у папоротника неделя.")
                            .font(Typography.cardCaption)
                            .foregroundStyle(.secondary)
                    }

                    plantButton

                    if let planted {
                        done(planted)
                    }
                }
                .padding(.bottom, 28)
                .animation(.smooth(duration: 0.35), value: planted)
            }
            .background { SproutBackground() }
            .toolbar(.hidden, for: .navigationBar)
            .scrollDismissesKeyboard(.interactively)
        }
    }

    private var days: Int { Int(dryingDays.rounded()) }

    private func field(_ title: String, text: Binding<String>,
                       hint: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(Typography.cardCaption)
                .foregroundStyle(.secondary)
            TextField(hint, text: text)
                .font(Typography.cardTitle)
                .foregroundStyle(.black)
                .textInputAutocapitalization(.sentences)
        }
    }

    private var plantButton: some View {
        Button {
            let room = garden.rooms[roomIndex].name
            let nickname = trimmedName
            garden.add(name: name, species: species,
                       roomIndex: roomIndex, dryingDays: dryingDays)
            planted = "«\(nickname)» теперь в комнате \(room)"
            name = ""
            species = ""
        } label: {
            Text("Посадить")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.capsule)
        .controlSize(.large)
        .tint(Palette.accent)
        .disabled(trimmedName.isEmpty)
        .padding(.horizontal, Metrics.contentMargin)
    }

    private func done(_ text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "leaf.fill")
                .foregroundStyle(Palette.green)
            Text(text)
                .font(Typography.cardTitle)
                .foregroundStyle(.black)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .sproutPlate(
            in: RoundedRectangle(cornerRadius: Metrics.rowRadius,
                                 style: .continuous))
        .padding(.horizontal, Metrics.contentMargin)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}
