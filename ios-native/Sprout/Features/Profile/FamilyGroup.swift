import SwiftUI

/// «Семья» в профиле: сад в iCloud на всех своих устройствах, приглашение в
/// сад, участники и выход. Приглашает системный лист iCloud — он же
/// показывает, кто в саду, и даёт сменить права. Без возможности iCloud в
/// сборке группы нет вовсе — см. `Kinship.enabled`.
struct FamilyGroup: View {
    @Environment(Garden.self) private var garden
    @Environment(\.scenePhase) private var phase

    private let kin = Kinship.shared

    @State private var stopping = false
    @State private var leaving = false

    /// Подписи поливов и новости о них — когда в саду есть кто-то ещё.
    private var family: Bool { kin.mode == .guest || kin.sharing }

    var body: some View {
        SproutGroup("Семья") {
            if kin.mode == .guest {
                guest
            } else {
                own
            }
            if family {
                SproutDivider()
                news
                    .transition(.blurReplace)
                SproutDivider()
                signature
                    .transition(.blurReplace)
            }
        }
        .animation(Motion.enter, value: kin.mode)
        .animation(Motion.enter, value: kin.people)
        .animation(Motion.enter, value: kin.status)
        .animation(Motion.enter, value: kin.sharing)
        .task { await kin.refresh() }
        // Вернулись из Сообщений — может, приглашение уже приняли.
        .onChange(of: phase) { _, now in
            if now == .active { Task { await kin.refresh() } }
        }
        .confirmationDialog("Перестать делиться садом?",
                            isPresented: $stopping,
                            titleVisibility: .visible) {
            Button("Перестать делиться", role: .destructive) {
                Task { await kin.stopSharing() }
                Feel.toss()
            }
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("Семья больше не увидит сад и его поливы. У вас всё останется.")
        }
        .confirmationDialog("Выйти из общего сада?", isPresented: $leaving,
                            titleVisibility: .visible) {
            Button("Выйти", role: .destructive) {
                Task { await kin.leave() }
                Feel.toss()
            }
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("Общий сад исчезнет с этого телефона, а ваш прежний сад вернётся. Ваши поливы останутся в общем саду.")
        }
        .sproutRide()
    }

    // MARK: - Свой сад

    @ViewBuilder
    private var own: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Сад в iCloud")
                    .font(Typography.settingRow)
                    .foregroundStyle(Palette.ink)
                if kin.mode == .off {
                    note(Self.why)
                }
                if kin.mode != .off || kin.status.speaks {
                    line
                }
            }
            Spacer(minLength: 0)
            Toggle("Сад в iCloud", isOn: Binding(
                get: { kin.mode == .own },
                set: { on in
                    withAnimation(Motion.enter) { kin.setOwn(on) }
                    Feel.pick()
                }))
                .labelsHidden()
                // Пока садом делятся, выключать его нельзя: семья осталась
                // бы со старым садом. Сначала — «Перестать делиться».
                .disabled(kin.sharing)
        }
        SproutDivider()
        invite
        // Один хозяин — ещё не семья: список — когда есть кто-то ещё.
        if kin.people.count > 1 {
            SproutDivider()
            members
                .transition(.blurReplace)
        }
        if kin.sharing {
            Button(role: .destructive) { stopping = true } label: {
                Label("Перестать делиться", systemImage: "person.2.slash")
                    .font(Typography.settingNote)
            }
            .buttonStyle(.glass)
            .disabled(kin.busy)
            .transition(.blurReplace)
        }
    }

    private static let why = Lang.text("""
        Тот же сад на всех ваших устройствах, а с приглашением — и у семьи.
        """)

    private var invite: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                Task { await kin.invite() }
                Feel.pick()
            } label: {
                Label(kin.sharing ? "Пригласить ещё" : "Пригласить в сад",
                      systemImage: "person.badge.plus")
                    .font(Typography.detail)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
            .disabled(kin.busy)
            Text(Self.invitation)
                .font(Typography.settingNote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private static let invitation = Lang.text("""
        Ссылкой в Сообщениях или почте. Кто примет, увидит этот сад и сможет \
        поливать, а у растения будет видно, кто полил.
        """)

    // MARK: - Общий сад

    @ViewBuilder
    private var guest: some View {
        Label {
            VStack(alignment: .leading, spacing: 3) {
                Text("Общий сад")
                    .font(Typography.settingRow)
                    .foregroundStyle(Palette.ink)
                if let host = kin.host {
                    note(Lang.format("Хозяин — %@", host))
                }
                line
            }
        } icon: {
            Image(systemName: "person.2.fill")
                .foregroundStyle(Palette.green)
        }
        if kin.people.count > 1 {
            SproutDivider()
            members
                .transition(.blurReplace)
        }
        SproutDivider()
        Button(role: .destructive) { leaving = true } label: {
            Label("Выйти из общего сада",
                  systemImage: "rectangle.portrait.and.arrow.right")
                .font(Typography.settingNote)
        }
        .buttonStyle(.glass)
        .disabled(kin.busy)
    }

    // MARK: - Участники

    private var members: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(kin.people) { person in
                HStack(spacing: 10) {
                    Image(systemName: person.owner ? "house.fill"
                          : "person.fill")
                        .font(Typography.settingNote)
                        .foregroundStyle(person.owner || person.accepted
                                         ? Palette.green : Color.secondary)
                        .frame(width: 22)
                    Text(person.name)
                        .font(Typography.settingRow)
                        .foregroundStyle(Palette.ink)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    Text(role(of: person))
                        .font(Typography.settingNote)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func role(of person: Kinship.Person) -> String {
        if person.me { return Lang.text("вы") }
        if person.owner { return Lang.text("хозяин сада") }
        return person.accepted ? Lang.text("в саду") : Lang.text("ждёт ответа")
    }

    // MARK: - Состояние

    /// Что с синхронизацией — одной строкой под заголовком.
    @ViewBuilder
    private var line: some View {
        switch kin.status {
        case .idle:
            note(Lang.text("Сохраняется в iCloud"))
        case .syncing:
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                note(Lang.text("Обновляю сад…"))
            }
        case .joining:
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                note(Lang.text("Подключаюсь к общему саду…"))
            }
        case .synced(let moment):
            note(Lang.format("Сохранено в iCloud в %@", moment.formatted(
                Date.FormatStyle(date: .omitted, time: .shortened)
                    .locale(Lang.locale))))
        case .trouble(let text):
            Label(text, systemImage: "exclamationmark.triangle")
                .font(Typography.settingNote)
                .foregroundStyle(Palette.warn)
                .fixedSize(horizontal: false, vertical: true)
        case .note(let text):
            note(text)
        }
    }

    private func note(_ text: String) -> some View {
        Text(text)
            .font(Typography.settingNote)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .transition(.blurReplace)
    }

    // MARK: - Поливы семьи

    private var news: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Сообщать, когда полили другие")
                    .font(Typography.settingRow)
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Уведомление вроде „Маша полила: Баксик“.")
                    .font(Typography.settingNote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Toggle("Сообщать, когда полили другие", isOn: Binding(
                get: { kin.news },
                set: { on in
                    kin.news = on
                    if on { Task { _ = await Notifier.ask() } }
                }))
                .labelsHidden()
        }
    }

    /// «Полил Миша» или «Полила Миша» — как другие увидят свои поливы.
    private var signature: some View {
        HStack(spacing: 12) {
            Text("Ваши поливы")
                .font(Typography.settingRow)
                .foregroundStyle(Palette.ink)
            Spacer(minLength: 8)
            Picker("Ваши поливы", selection: Binding(
                get: { kin.signsShe },
                set: { kin.she = $0 })) {
                Text(sample(she: false)).tag(false)
                Text(sample(she: true)).tag(true)
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .tint(Palette.accent)
        }
    }

    private func sample(she: Bool) -> String {
        Family.verb(garden.owner, she: she)
            ?? (she ? Lang.text("Полила") : Lang.text("Полил"))
    }
}
