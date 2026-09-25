import SwiftUI

/// Вход в планетарий на обзоре статистики: маленький живой планетарий и
/// пара слов.
struct OrreryTeaser: View {
    @Environment(Garden.self) private var garden

    var body: some View {
        let orbits = Orrery.orbits(garden.rooms.flatMap(\.plants))
        HStack(spacing: 14) {
            TimelineView(.animation(minimumInterval: 1.0 / 30)) { context in
                let drift = context.date.timeIntervalSince(garden.ticked)
                    * Garden.speed / 86_400
                OrreryDial(planets: Orrery.sky(orbits, ahead: 0, drift: drift),
                           small: true)
            }
            .frame(width: Metrics.teaser, height: Metrics.teaser)
            .background(Circle().fill(Palette.space))
            .clipShape(Circle())
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text("Планетарий сада")
                        .font(Typography.detail)
                        .foregroundStyle(Palette.ink)
                    Image(systemName: "sparkles")
                        .font(Typography.settingNote)
                        .foregroundStyle(Palette.accent)
                }
                Text("Растения кружат по орбитам полива. Послушайте, как звучит месяц.")
                    .font(Typography.settingNote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(Typography.settingNote)
                .foregroundStyle(.tertiary)
        }
        .padding(Metrics.groupPadding)
        .contentShape(Rectangle())
        .sproutPlate(in: RoundedRectangle(cornerRadius: Metrics.cardRadius,
                                          style: .continuous))
    }
}
