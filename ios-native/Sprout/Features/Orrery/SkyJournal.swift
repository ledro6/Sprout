import SwiftUI

/// «Небесный журнал» — одно окно со всеми счетами планетария: точность
/// орбиты, звёзды наблюдателя, время покоя и история редких событий.
/// Открывается кнопкой в шапке планетария или чипом «Точность».
struct SkyJournal: View {
    @Environment(Garden.self) private var garden
    @Environment(\.dismiss) private var dismiss
    private let book = SkyBook.shared

    private var side: Season.Side {
        Season.side(region: Locale.current.region?.identifier)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Metrics.groupGap) {
                    precision
                    observatory
                }
                .padding(.horizontal, Metrics.contentMargin)
                .padding(.top, 8)
                .padding(.bottom, Metrics.groupGap)
            }
            .background { StarField() }
            .navigationTitle("Небесный журнал")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") { dismiss() }
                }
            }
        }
        .environment(\.colorScheme, .dark)
        .presentationDetents([.medium, .large])
    }

    /// Карточка журнала: заголовок со значком и содержимое.
    private func card<Content: View>(
        _ title: String, icon: String,
        @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: icon)
                .font(Typography.detail)
                .foregroundStyle(Palette.ink)
            content()
        }
        .padding(Metrics.groupPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .sproutPlate(in: RoundedRectangle(cornerRadius: Metrics.cardRadius,
                                          style: .continuous))
    }

    private func note(_ text: String) -> some View {
        Text(text)
            .font(Typography.settingNote)
            .foregroundStyle(Palette.secondaryText)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Точность

    private var precision: some View {
        let standing = Precision.standing(garden.log, side: side,
                                          kept: book.state.record)
        let tally = standing.tally
        return card(Lang.text("Точность"), icon: "scope") {
            HStack(alignment: .firstTextBaseline) {
                Text(standing.share.map { Stats.percent($0) } ?? "—")
                    .font(Typography.figure)
                    .foregroundStyle(Palette.ink)
                Text("в этом сезоне")
                    .font(Typography.settingNote)
                    .foregroundStyle(Palette.secondaryText)
            }
            note(Lang.format("В яблочко: %1$lld · впритык: %2$lld · рано: %3$lld",
                             tally.bullseye, tally.tight, tally.early))
            if let record = standing.record {
                note(Lang.format("Рекорд: %1$@ — %2$@.",
                                 Stats.percent(record.share),
                                 Self.season(record.season))
                     + (standing.isRecord ? " " + Lang.text("Сейчас вы на рекорде.")
                        : ""))
            } else {
                note(Lang.text("Рекорд появится, когда за сезон наберётся несколько оценённых поливов."))
            }
            note(Lang.text("«В яблочко» — полив, когда в земле 20–40 % воды. Впритык и поздно счёт не портят, а ранний полив его снижает: награда только за точность."))
        }
    }

    private var observatory: some View {
        card(Lang.text("Обсерватория"), icon: "binoculars") {
            HStack(alignment: .firstTextBaseline) {
                Label("\(book.state.stars)", systemImage: "star.fill")
                    .font(Typography.figure)
                    .foregroundStyle(Palette.waterGlow)
                Text("звёзд наблюдателя")
                    .font(Typography.settingNote)
                    .foregroundStyle(Palette.secondaryText)
            }
            note(Lang.format("Серия верных дней: %lld", book.streak()))
            note(Lang.format("Лучшая серия: %lld", book.state.bestStreak))
            note(Lang.text("Раз в день планетарий спрашивает, кто первым дойдёт до луча. Ответ решён заранее по срокам полива, поэтому полив после выбора ничего не меняет."))
        }
    }

    /// «2027-winter» → «Зима 2027».
    static func season(_ stamp: String) -> String {
        let parts = stamp.split(separator: "-")
        guard parts.count == 2 else { return stamp }
        let name: String
        switch parts[1] {
        case "spring": name = Lang.text("Весна")
        case "summer": name = Lang.text("Лето")
        case "autumn": name = Lang.text("Осень")
        default: name = Lang.text("Зима")
        }
        return name + " " + parts[0]
    }
}
