import PhotosUI
import SwiftUI

/// Модель растения для AR. Сама по себе — готовая модель вида из
/// приложения, она открывается сразу. Своя — только по просьбе и двумя
/// путями. Придумать по фото: классификатор Apple узнаёт растение, Vision
/// отделяет его от фона, а цвета листьев, цветов и горшка, густоту и рост
/// модель берёт со снимка — всё на телефоне, без сети. Отсканировать: обойти
/// растение с телефоном, и Object Capture соберёт его точную объёмную копию.
struct ModelSheet: View {
    let plantID: Plant.ID

    @Environment(Garden.self) private var garden
    @Environment(\.dismiss) private var dismiss

    /// Снимок разбирается — кнопки спят.
    @State private var thinking = false
    /// Снимок не подошёл — почему.
    @State private var trouble: String?
    @State private var item: PhotosPickerItem?
    @State private var shooting = false
    @State private var fresh: UIImage?
    @State private var scanning = false

    private var plant: Plant? { garden.plant(id: plantID) }

    var body: some View {
        NavigationStack {
            ScrollView {
                if let plant {
                    VStack(alignment: .leading, spacing: Metrics.groupGap) {
                        now(plant)
                        imagine(plant)
                        scan
                    }
                    .padding(.horizontal, Metrics.contentMargin)
                    .padding(.top, 4)
                    .padding(.bottom, 40)
                    .animation(Motion.enter, value: plant.plan)
                    .animation(Motion.enter, value: plant.scan)
                }
            }
            .background { SproutBackground() }
            .navigationTitle("Модель для AR")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Готово") { dismiss() }
                }
            }
        }
        .onChange(of: plant == nil) { _, gone in
            if gone { dismiss() }
        }
        .onChange(of: item) { _, chosen in
            Task { await pick(chosen) }
        }
        // `onDismiss` объявлен до содержимого — вторым замыканием его не
        // переставить.
        .fullScreenCover(isPresented: $shooting, onDismiss: { snapped() }) {
            Camera { image in fresh = image }
                .ignoresSafeArea()
        }
        .fullScreenCover(isPresented: $scanning) {
            ScanView(plantID: plantID).environment(garden)
        }
    }

    // MARK: - Сейчас

    private func now(_ plant: Plant) -> some View {
        SproutGroup("Сейчас") {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: plant.scan != nil ? "viewfinder"
                      : plant.plan != nil ? "wand.and.stars" : "cube")
                    .font(Typography.navTitle)
                    .foregroundStyle(Palette.accent)
                    .frame(width: 30)
                VStack(alignment: .leading, spacing: 3) {
                    Text(plant.scan != nil ? Lang.text("Скан вашего растения")
                         : plant.blueprint.source)
                        .font(Typography.settingRow)
                        .foregroundStyle(Palette.ink)
                    Text(note(plant))
                        .font(Typography.settingNote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .contentTransition(.numericText())
                }
                Spacer(minLength: 0)
            }
            .id(plant.scan ?? plant.plan?.seed ?? "stock")
            .transition(.blurReplace)
            if plant.plan != nil || plant.scan != nil {
                SproutDivider()
                Button {
                    withAnimation(Motion.enter) { garden.unmodel(plantID) }
                    Feel.pick()
                } label: {
                    Label("Вернуть готовую модель", systemImage: "arrow.uturn.backward")
                        .font(Typography.settingRow)
                }
            }
        }
    }

    private func note(_ plant: Plant) -> String {
        if plant.scan != nil {
            return Lang.text("Точная объёмная копия — из скана.")
        }
        if plant.plan != nil {
            if let share = Bench.shared.share(plant), share < 1 {
                return Bench.preparing(share)
            }
            return Lang.text("Цвета, густота и рост — со снимка.")
        }
        return Lang.text("Лежит в приложении — AR открывается сразу.")
    }

    // MARK: - Придумать

    private func imagine(_ plant: Plant) -> some View {
        SproutGroup("Придумать по фото") {
            Text("""
                Телефон узнает растение на снимке и придумает его модель: \
                возьмёт цвета листьев, цветов и горшка, густоту и рост. Всё \
                считается на телефоне, без сети, — за пару секунд.
                """)
                .font(Typography.settingNote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: Metrics.actionGap) {
                if let name = plant.shot {
                    Button {
                        guard let image = Snapshot.image(name) else { return }
                        Task { await study(image) }
                    } label: {
                        Label("По фото растения", systemImage: "leaf")
                            .font(Typography.settingNote)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glassProminent)
                }
                PhotosPicker(selection: $item, matching: .images) {
                    Label("Из галереи", systemImage: "photo")
                        .font(Typography.settingNote)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glass)
                if Camera.exists {
                    Button { shooting = true } label: {
                        Label("Снять", systemImage: "camera")
                            .font(Typography.settingNote)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glass)
                }
            }
            .controlSize(.large)
            .disabled(thinking)
            if thinking {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Смотрю на снимок…")
                        .font(Typography.settingNote)
                        .foregroundStyle(.secondary)
                }
                .transition(.blurReplace)
            }
            if let trouble {
                Label(trouble, systemImage: "exclamationmark.triangle")
                    .font(Typography.settingNote)
                    .foregroundStyle(Palette.warn)
                    .fixedSize(horizontal: false, vertical: true)
                    .id(trouble)
                    .transition(.blurReplace)
            }
        }
        .animation(Motion.number, value: thinking)
        .animation(Motion.number, value: trouble)
    }

    @MainActor
    private func pick(_ chosen: PhotosPickerItem?) async {
        guard let chosen,
              let data = try? await chosen.loadTransferable(type: Data.self),
              let image = UIImage(data: data)
        else { return }
        item = nil
        await study(image)
    }

    /// Камера закрылась — снимок, если его сделали, идёт в разбор.
    private func snapped() {
        guard let image = fresh else { return }
        fresh = nil
        Task { await study(image) }
    }

    /// Разбор снимка и чертёж модели; сама сборка — в мастерской, её
    /// проценты видно здесь и на карточке. Вид — по названию растения, а не
    /// узнали — тот, что увидел классификатор.
    @MainActor
    private func study(_ image: UIImage) async {
        thinking = true
        trouble = nil
        async let studied = Eye.study(image)
        async let sighted = Eye.guess(image)
        let reading = await studied
        let seen = await sighted
        thinking = false
        guard let traits = reading.traits else {
            trouble = reading.verdict.line
            Feel.wrong()
            return
        }
        garden.imagine(plantID, traits: traits,
                       kind: seen.flatMap { Preset.known($0.species) })
        if let plant = garden.plant(id: plantID) { Workshop.order(plant) }
        Feel.done()
    }

    // MARK: - Скан

    private var scan: some View {
        SproutGroup("Отсканировать") {
            Text("""
                Обойдите растение с телефоном по кругу — получится его \
                точная объёмная копия. Съёмка займёт пару минут, сборка \
                модели — ещё несколько; всё на телефоне.
                """)
                .font(Typography.settingNote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button { scanning = true } label: {
                Label("Начать скан", systemImage: "viewfinder")
                    .font(Typography.detail)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
            .disabled(!ScanView.supported)
            if !ScanView.supported {
                Text("Нужен iPhone с датчиком LiDAR — модели Pro, начиная с iPhone 12 Pro.")
                    .font(Typography.settingNote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
