import SwiftUI

/// Архив в профиле: погибшие растения, когда ушли и сколько раз их
/// поливали. «Вернуть из архива» ставит растение в свою комнату с журналом.
struct ArchiveGroup: View {
    @Environment(Garden.self) private var garden

    var body: some View {
        SproutGroup("Архив") {
            ForEach(Array(garden.archive.enumerated()), id: \.element.plant.id) {
                place, entry in
                if place > 0 { SproutDivider() }
                row(entry)
            }
        }
        .sproutRide()
    }

    private func row(_ entry: Archived) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.plant.name)
                    .font(Typography.settingRow)
                    .foregroundStyle(Palette.ink)
                    .dataLines()
                Text(note(entry))
                    .font(Typography.settingNote)
                    .foregroundStyle(Palette.secondaryText)
                    .lineLimit(2)
            }
            Spacer(minLength: 8)
            Button("Вернуть из архива") {
                withAnimation(Motion.appear) { garden.revive(entry.plant.id) }
                Feel.back()
            }
            .font(Typography.settingNote)
            .buttonStyle(.bordered)
            .frame(minHeight: 44)
        }
        .accessibilityElement(children: .contain)
    }

    /// «Кухня · в архиве с 3 окт. · поливов: 12».
    private func note(_ entry: Archived) -> String {
        let pours = garden.log.count { $0.plant == entry.plant.id }
        let since = entry.plant.archived?
            .formatted(.dateTime.day().month(.abbreviated)) ?? ""
        return Lang.format("%1$@ · в архиве с %2$@ · поливов: %3$lld",
                           entry.room, since, pours)
    }
}
