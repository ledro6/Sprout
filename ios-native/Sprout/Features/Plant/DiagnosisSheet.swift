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

    private var plant: Plant? { garden.plant(id: plantID) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Metrics.groupGap) {
                    photo
                    if thinking {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text("Смотрю на листья…")
                                .font(Typography.settingNote)
                                .foregroundStyle(.secondary)
                        }
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
                    Text("Это подсказка по снимку, а не приговор: тень, блик или белые цветки телефон может принять за беду.")
                        .font(Typography.settingNote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 6)
                }
                .padding(.horizontal, Metrics.contentMargin)
                .padding(.top, 4)
                .padding(.bottom, 40)
                .animation(Motion.enter, value: findings)
                .animation(Motion.enter, value: thinking)
                .animation(Motion.enter, value: advice)
            }
            .background { SproutBackground() }
            .navigationTitle("Что с растением?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Готово") { dismiss() }
                }
            }
        }
        .onChange(of: item) { _, chosen in
            Task { await pick(chosen) }
        }
        .fullScreenCover(isPresented: $shooting, onDismiss: { snapped() }) {
            Camera { image in fresh = image }
                .ignoresSafeArea()
        }
        .task {
            // Своё фото растения — сразу в разбор: чаще всего его и хотят
            // проверить.
            if let name = plant?.shot, let image = Snapshot.image(name) {
                await examine(image)
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
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: Metrics.actionGap) {
                if Camera.exists {
                    Button { shooting = true } label: {
                        Label("Снять", systemImage: "camera")
                            .lineLimit(1)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glassProminent)
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
                    let share = finding.confidence.formatted(
                        .percent.precision(.fractionLength(0)))
                    Text(share)
                        .font(Typography.settingNote)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .accessibilityLabel(Lang.format("Уверенность %@", share))
                }
            }
            Text(finding.detail)
                .font(Typography.settingNote)
                .foregroundStyle(.secondary)
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
        guard let chosen,
              let data = try? await chosen.loadTransferable(type: Data.self),
              let image = UIImage(data: data)
        else { return }
        item = nil
        await examine(image)
    }

    private func snapped() {
        guard let image = fresh else { return }
        fresh = nil
        Task { await examine(image) }
    }

    @MainActor
    private func examine(_ image: UIImage) async {
        guard let plant else { return }
        withAnimation(Motion.enter) {
            shown = image
            thinking = true
            findings = []
            advice = nil
        }
        let seen = await Eye.examine(image)
        let found = Finding.diagnose(seen, plant: plant, log: garden.log,
                                     climate: Settings.shared.weather
                                        ? Settings.shared.climate : nil)
        withAnimation(Motion.enter) {
            thinking = false
            findings = found
        }
        Feel.done()
        if Muse.ready, found.first?.kind != .unclear {
            let words = await Muse.advise(found, plant: plant)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard let words, !words.isEmpty else { return }
            withAnimation(Motion.enter) { advice = words }
        }
    }
}
