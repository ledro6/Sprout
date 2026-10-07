import PhotosUI
import SwiftUI

/// «Что с ним?» — снимок растения разбирается на телефоне: сколько на
/// листьях зелени, желтизны, бурых краёв, пятен и налёта, — и вместе с
/// историей полива и ухода это превращается в подсказки. Есть Apple
/// Intelligence — сверху ещё и пара тёплых слов о том, с чего начать.
struct DiagnosisSheet: View {
    let plantID: Plant.ID

    @Environment(Garden.self) private var garden
    @Environment(\.dismiss) private var dismiss

    @State private var item: PhotosPickerItem?
    @State private var shooting = false
    @State private var fresh: UIImage?
    @State private var shown: UIImage?
    @State private var thinking = false
    @State private var findings: [Finding] = []
    @State private var advice: String?
    /// План лечения составлен по этому снимку.
    @State private var planned = false
    /// Разбор снимка — его можно отменить.
    @State private var job: Task<Void, Never>?
    /// Снимок не открылся.
    @State private var failed = false

    private var plant: Plant? { garden.plant(id: plantID) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Metrics.groupGap) {
                    photo
                    if thinking {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text("Разбираю фото…")
                                .font(Typography.settingNote)
                                .foregroundStyle(Palette.secondaryText)
                            Spacer(minLength: 8)
                            Button("Отмена", action: cancel)
                                .buttonStyle(.glass)
                                .font(Typography.settingNote)
                        }
                        .transition(.blurReplace)
                    }
                    if failed {
                        Label("Не получилось открыть снимок. Попробуйте ещё раз — снимите или выберите другой.",
                              systemImage: "exclamationmark.bubble")
                            .font(Typography.settingNote)
                            .foregroundStyle(Palette.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                            .transition(.blurReplace)
                    }
                    if let advice {
                        Text(advice)
                            .font(Typography.settingRow)
                            .foregroundStyle(Palette.ink)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(Metrics.groupPadding)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .sproutPlate(in: RoundedRectangle(
                                cornerRadius: Metrics.cardRadius,
                                style: .continuous))
                            .transition(.blurReplace)
                    }
                    ForEach(findings) { finding in
                        card(finding)
                            .transition(.blurReplace)
                    }
                    planOffer
                    if !Muse.ready {
                        Text("Совет словами пишет Apple Intelligence — на этом телефоне её нет. Находки по снимку работают и без неё.")
                            .font(Typography.settingNote)
                            .foregroundStyle(Palette.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 6)
                    }
                    Text("Это подсказка по снимку, а не приговор: тень, блик или белые цветки телефон может принять за беду. Разбирается на телефоне, ничего не отправляется.")
                        .font(Typography.settingNote)
                        .foregroundStyle(Palette.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 6)
                }
                .padding(.horizontal, Metrics.contentMargin)
                .padding(.top, 4)
                .padding(.bottom, 40)
                .animation(Motion.enter, value: findings)
                .animation(Motion.enter, value: thinking)
                .animation(Motion.enter, value: advice)
                .animation(Motion.enter, value: planned)
                .animation(Motion.enter, value: failed)
            }
            .background { SproutBackground() }
            .navigationTitle("Что с растением?")
            .navigationBarTitleDisplayMode(.inline)
            .scrollEdgeEffectStyle(.soft, for: .top)
            .sproutSettledEdge()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Готово") { dismiss() }
                }
            }
        }
        .onChange(of: item) { _, chosen in
            Task { await pick(chosen) }
        }
        // Лист закрыли посреди разбора — дальше не нужен.
        .onDisappear { job?.cancel() }
        .fullScreenCover(isPresented: $shooting, onDismiss: { snapped() }) {
            Camera { image in fresh = image }
                .ignoresSafeArea()
        }
        .task {
            // Своё фото растения — сразу в разбор: чаще всего его и хотят
            // проверить.
            if let name = plant?.shot, let image = Snapshot.image(name) {
                run(image)
            }
        }
    }

    private var photo: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let shown {
                Image(uiImage: shown)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 220)
                    .clipShape(RoundedRectangle(cornerRadius: Metrics.cardRadius
                                                - 6, style: .continuous))
                    .transition(.blurReplace)
            } else {
                Text("Снимите растение целиком, при дневном свете — телефон посмотрит на листья.")
                    .font(Typography.settingNote)
                    .foregroundStyle(Palette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: Metrics.actionGap) {
                if Camera.exists {
                    Button { shooting = true } label: {
                        Label("Снять", systemImage: "camera")
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glassProminent)
                    .tint(Palette.accentFill)
                }
                PhotosPicker(selection: $item, matching: .images) {
                    Label("Из галереи", systemImage: "photo")
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glass)
            }
            .font(Typography.settingNote)
            .controlSize(.large)
            .disabled(thinking)
        }
        .padding(Metrics.groupPadding)
        .sproutPlate(in: RoundedRectangle(cornerRadius: Metrics.cardRadius,
                                          style: .continuous))
    }

    /// Есть что делать — план лечения: шаги из советов выше, с
    /// напоминаниями; разобранный снимок становится снимком «до».
    @ViewBuilder
    private var planOffer: some View {
        if !thinking, findings.contains(where: { !$0.advice.isEmpty }) {
            VStack(alignment: .leading, spacing: 10) {
                if planned {
                    Label("План лечения — на экране растения",
                          systemImage: "checkmark.circle.fill")
                        .font(Typography.settingRow)
                        .foregroundStyle(Palette.green)
                } else {
                    Button { makePlan() } label: {
                        Group {
                            if plant?.treatment?.active == true {
                                Label("Составить план заново",
                                      systemImage: "list.bullet.clipboard")
                            } else {
                                Label("Составить план лечения",
                                      systemImage: "list.bullet.clipboard")
                            }
                        }
                        .font(Typography.detail)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(.glassProminent)
                    .tint(Palette.accentFill)
                    .controlSize(.large)
                    Text("Шаги — из советов выше, со сроками и напоминаниями. Этот снимок станет снимком «до».")
                        .font(Typography.settingNote)
                        .foregroundStyle(Palette.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 6)
                }
            }
            .transition(.blurReplace)
        }
    }

    private func makePlan() {
        guard let plant,
              var plan = Treatment.plan(findings, plant: plant) else { return }
        plan.before = shown.flatMap { Snapshot.keep($0) }
        withAnimation(Motion.enter) {
            garden.treat(plantID, plan)
            planned = true
        }
        Feel.done()
    }

    private func card(_ finding: Finding) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: finding.icon)
                    .font(Typography.navTitle)
                    .foregroundStyle(finding.kind == .healthy ? Palette.accent
                                     : Palette.warn)
                    .frame(width: 28)
                Text(finding.title)
                    .font(Typography.detail)
                    .foregroundStyle(Palette.ink)
                Spacer(minLength: 8)
                if finding.kind != .unclear && finding.kind != .healthy {
                    let sure = Sureness(finding.confidence).word
                    Text(sure)
                        .font(Typography.settingNote)
                        .foregroundStyle(Palette.secondaryText)
                        .accessibilityLabel(Lang.format("Уверенность: %@", sure))
                }
            }
            Text(finding.detail)
                .font(Typography.settingNote)
                .foregroundStyle(Palette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            ForEach(finding.tips, id: \.self) { tip in
                Label {
                    Text(tip)
                        .fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: "arrow.turn.down.right")
                        .foregroundStyle(Palette.accent)
                }
                .font(Typography.settingNote)
                .foregroundStyle(Palette.ink)
            }
        }
        .padding(Metrics.groupPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .sproutPlate(in: RoundedRectangle(cornerRadius: Metrics.cardRadius,
                                          style: .continuous))
    }

    @MainActor
    private func pick(_ chosen: PhotosPickerItem?) async {
        guard let chosen else { return }
        guard let data = try? await chosen.loadTransferable(type: Data.self),
              let image = UIImage(data: data)
        else {
            item = nil
            withAnimation(Motion.enter) { failed = true }
            return
        }
        item = nil
        run(image)
    }

    private func snapped() {
        guard let image = fresh else { return }
        fresh = nil
        run(image)
    }

    /// Новый разбор — прежний, если идёт, долой.
    private func run(_ image: UIImage) {
        job?.cancel()
        job = Task { await examine(image) }
    }

    /// «Отмена» во время разбора: снимок убирается, можно взять другой.
    private func cancel() {
        job?.cancel()
        job = nil
        withAnimation(Motion.enter) {
            thinking = false
            shown = nil
            findings = []
            advice = nil
        }
    }

    @MainActor
    private func examine(_ image: UIImage) async {
        guard let plant else { return }
        withAnimation(Motion.enter) {
            shown = image
            thinking = true
            findings = []
            advice = nil
            planned = false
            failed = false
        }
        let seen = await Eye.examine(image)
        guard !Task.isCancelled else { return }
        let found = Finding.diagnose(seen, plant: plant, log: garden.log,
                                     climate: Settings.shared.weather
                                        ? Settings.shared.climate : nil)
        withAnimation(Motion.enter) {
            thinking = false
            findings = found
        }
        Feel.done()
        if Muse.ready, found.first?.kind != .unclear {
            let words = await Muse.advise(found, plant: plant,
                                          room: garden.roomName(of: plantID),
                                          log: garden.log)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !Task.isCancelled, let words, !words.isEmpty else { return }
            withAnimation(Motion.enter) { advice = words }
        }
    }
}
