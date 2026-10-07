import PhotosUI
import SwiftUI

/// План лечения на экране растения: сколько шагов сделано, когда следующий,
/// сами шаги с отметкой, снимки «до» и «после» и «Вылечено». Вылечили —
/// короткий праздник: волна по фону, печать и награда «Врач растений».
struct TreatmentCard: View {
    let plant: Plant
    let plan: Treatment

    @Environment(Garden.self) private var garden

    @State private var item: PhotosPickerItem?
    @State private var shooting = false
    @State private var fresh: UIImage?
    @State private var dropping = false
    @State private var spot = CGRect.zero

    var body: some View {
        // Сроки словами — «через 2 дня» — сами по себе не обновятся: время
        // идёт, а растение может и не меняться.
        TimelineView(.everyMinute) { context in
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 8) {
                    Text("План лечения")
                        .font(Typography.groupTitle)
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 8)
                    Text(Lang.format("%1$lld из %2$lld", plan.done, plan.total))
                        .font(Typography.settingNote)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                }
                if plan.active {
                    going(now: context.date)
                } else {
                    cured
                }
            }
        }
        .animation(Motion.number, value: plan)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 25)
        .padding(.vertical, 22)
        .sproutPlate(in: RoundedRectangle(cornerRadius: Metrics.cardRadius,
                                          style: .continuous))
        .sproutRide()
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) }
            action: { spot = $0 }
        .onChange(of: item) { _, chosen in
            Task { await pick(chosen) }
        }
        .fullScreenCover(isPresented: $shooting, onDismiss: { snapped() }) {
            Camera { image in fresh = image }
                .ignoresSafeArea()
        }
        .confirmationDialog("Отменить план лечения?", isPresented: $dropping,
                            titleVisibility: .visible) {
            Button("Отменить план", role: .destructive) {
                withAnimation(Motion.enter) { garden.untreat(plant.id) }
            }
            Button("Оставить", role: .cancel) {}
        } message: {
            Text("Шаги, отметки и снимки «до» и «после» пропадут.")
        }
    }

    // MARK: - Лечится

    @ViewBuilder
    private func going(now: Date) -> some View {
        ProgressView(value: Double(plan.done),
                     total: Double(max(plan.total, 1)))
            .tint(Palette.green)
        if let next = plan.next {
            Text(Lang.format("Следующий шаг — %@",
                             Treatment.when(next.due, from: now)))
                .font(Typography.detail)
                .foregroundStyle(next.due <= now ? Palette.accent : Palette.ink)
                .contentTransition(.numericText())
        } else {
            Text("Все шаги сделаны — пора сказать «Вылечено».")
                .font(Typography.detail)
                .foregroundStyle(Palette.accent)
                .fixedSize(horizontal: false, vertical: true)
        }
        ForEach(plan.steps) { step in
            row(step, now: now)
        }
        photos
        afterButtons
        Button { cure() } label: {
            Label("Вылечено", systemImage: "checkmark.seal.fill")
                .font(Typography.detail)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
        }
        .buttonStyle(.glassProminent)
        .tint(Palette.green)
        .controlSize(.large)
        Button("Отменить план") { dropping = true }
            .font(Typography.settingNote)
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
    }

    private func row(_ step: Treatment.Step, now: Date) -> some View {
        let done = step.done != nil
        let when = done ? Lang.text("сделано")
            : Treatment.when(step.due, from: now)
        let meta = [step.count, when].compactMap { $0 }
            .joined(separator: " · ")
        return HStack(alignment: .top, spacing: 12) {
            Button {
                withAnimation(Motion.number) {
                    garden.step(plant.id, step.id, done: !done)
                }
                if done { Feel.pick() } else { Feel.done() }
            } label: {
                Image(systemName: done ? "checkmark.circle.fill" : "circle")
                    .font(Typography.navTitle)
                    .foregroundStyle(done ? Palette.green
                                     : (step.due <= now ? Palette.accent
                                        : Palette.ink.opacity(0.35)))
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(done ? "Снять отметку" : "Сделано")
            VStack(alignment: .leading, spacing: 3) {
                Label {
                    Text(step.title)
                        .strikethrough(done)
                        .fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: step.icon)
                        .foregroundStyle(Palette.accent)
                }
                .font(Typography.settingRow)
                .foregroundStyle(Palette.ink.opacity(done ? 0.5 : 1))
                Text(meta)
                    .font(Typography.settingNote)
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Снимки

    /// «До» — снимок, по которому составили план; «после» — свой, когда
    /// растение поправится.
    @ViewBuilder
    private var photos: some View {
        let before = plan.before.flatMap { Snapshot.image($0) }
        let after = plan.after.flatMap { Snapshot.image($0) }
        if before != nil || after != nil {
            HStack(spacing: 12) {
                if let before { tile(before, caption: "До") }
                if let after { tile(after, caption: "После") }
            }
        }
    }

    private func tile(_ image: UIImage, caption: LocalizedStringKey)
        -> some View {
        Color.clear
            .frame(maxWidth: .infinity)
            .frame(height: 130)
            .overlay {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            }
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(alignment: .bottomLeading) {
                Text(caption)
                    .font(Typography.settingNote.weight(.semibold))
                    .foregroundStyle(Palette.ink)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(8)
            }
    }

    @ViewBuilder
    private var afterButtons: some View {
        if plan.after == nil {
            HStack(spacing: Metrics.actionGap) {
                if Camera.exists {
                    Button { shooting = true } label: {
                        Label("Снять «после»", systemImage: "camera")
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glass)
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
        }
    }

    // MARK: - Вылечено

    private var cured: some View {
        VStack(spacing: 10) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 48, weight: .semibold))
                .foregroundStyle(Palette.green)
                .symbolEffect(.bounce, value: plan.cured)
            Text("Вылечено!")
                .font(Typography.figure)
                .foregroundStyle(Palette.ink)
            Text("Растение снова в строю. Снимки «до» и «после» остаются здесь, пока план не убран.")
                .font(Typography.settingNote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            photos
            afterButtons
            Button("Убрать план") {
                withAnimation(Motion.enter) { garden.untreat(plant.id) }
            }
            .buttonStyle(.glass)
            .font(Typography.settingNote)
        }
        .frame(maxWidth: .infinity)
        .transition(.blurReplace)
    }

    private func cure() {
        withAnimation(Motion.enter) { garden.cure(plant.id) }
        Cabinet.shared.deed(.healer)
        Cheer.shared.now(from: spot)
        Feel.planted()
    }

    // MARK: - Снимок «после»

    @MainActor
    private func pick(_ chosen: PhotosPickerItem?) async {
        guard let chosen,
              let data = try? await chosen.loadTransferable(type: Data.self),
              let image = UIImage(data: data)
        else { return }
        item = nil
        keep(image)
    }

    private func snapped() {
        guard let image = fresh else { return }
        fresh = nil
        keep(image)
    }

    private func keep(_ image: UIImage) {
        guard let name = Snapshot.keep(image) else { return }
        withAnimation(Motion.enter) {
            garden.treatmentShot(plant.id, file: name, after: true)
        }
        Feel.done()
    }
}
