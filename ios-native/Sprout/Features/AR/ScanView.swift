import RealityKit
import SwiftUI

/// Скан растения. Хозяин обходит растение с телефоном, Object Capture
/// снимает кадры с глубиной от LiDAR, а PhotogrammetrySession собирает из
/// них модель USDZ — всё на телефоне, без сети. Модель ложится в `Scans` и
/// с этой минуты стоит в AR вместо готовой. Кадры после сборки удаляются:
/// их сотни мегабайт.
struct ScanView: View {
    let plantID: Plant.ID

    @Environment(Garden.self) private var garden
    @Environment(\.dismiss) private var dismiss

    @State private var scanner = Scanner()

    /// Без LiDAR на iPhone Object Capture не работает — кнопка скана спит.
    static var supported: Bool {
        ObjectCaptureSession.isSupported && PhotogrammetrySession.isSupported
    }

    var body: some View {
        ZStack {
            if let session = scanner.session {
                ObjectCaptureView(session: session)
                    .ignoresSafeArea()
            } else {
                SproutBackground()
                    .ignoresSafeArea()
                    .environment(\.colorScheme, .dark)
            }
        }
        .overlay(alignment: .top) { header }
        .overlay(alignment: .bottom) { controls }
        .animation(Motion.enter, value: scanner.step)
        .task { await scanner.start(plantID) }
        .onDisappear { scanner.cancel() }
        .onChange(of: scanner.step) { _, step in
            guard case .done(let name) = step else { return }
            garden.scanned(plantID, file: name)
            Feel.done()
            dismiss()
        }
    }

    // MARK: - Верх и низ

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            CloseButton { dismiss() }

            Spacer(minLength: 0)

            VStack(spacing: 4) {
                Text(scanner.trouble ?? hint)
                    .font(Typography.toastNote)
                    .foregroundStyle(scanner.trouble == nil ? Palette.ink
                                     : Palette.warn)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .contentTransition(.numericText())
                if case .capturing = scanner.step {
                    Text(Lang.format("Кадров: %lld", scanner.shots))
                        .font(Typography.toastNote)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .glassEffect(.regular, in: .rect(cornerRadius: 18))
            .id(scanner.trouble ?? hint)
            .transition(.blurReplace)
            // Поверх — подсказка ARKit, как вернуть опору; своя ей мешала бы.
            .opacity(scanner.coaching ? 0 : 1)

            Spacer(minLength: 0)

            // Противовес крестику — подсказка встаёт ровно посередине.
            Color.clear
                .frame(width: 44, height: 44)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, Metrics.contentMargin)
    }

    private var hint: String {
        switch scanner.step {
        case .starting:
            Lang.text("Включаю камеру…")
        case .aiming:
            Lang.text("Поставьте растение на стол или пол и наведите камеру так, чтобы была видна и опора")
        case .detecting:
            Lang.text("Рамка обнимает растение с горшком? Тогда начинайте. Края рамки тянутся пальцем")
        case .capturing where scanner.lapped:
            Lang.text("Круг пройден. Можно ещё один — пониже или повыше")
        case .capturing:
            Lang.text("Медленно обходите растение по кругу")
        case .finishing:
            Lang.text("Дописываю кадры…")
        case .building(let share):
            Lang.format("Собираю модель: %@", Bench.percent(share))
        case .done:
            Lang.text("Готово")
        case .failed(let reason):
            reason
        }
    }

    @ViewBuilder
    private var controls: some View {
        HStack(spacing: 12) {
            switch scanner.step {
            case .aiming:
                // Рамка встанет сама, как только камера найдёт опору.
                ProgressView()
                    .controlSize(.large)
                    .padding(12)
                    .glassEffect(.regular, in: .circle)
            case .detecting:
                tool("Заново", icon: "arrow.counterclockwise",
                       prominent: false) { scanner.redetect() }
                tool("Начать съёмку", icon: "camera.aperture",
                       prominent: true) { scanner.capture() }
            case .capturing:
                if scanner.lapped {
                    tool("Ещё круг", icon: "arrow.triangle.2.circlepath",
                           prominent: false) { scanner.lap() }
                }
                tool("Готово", icon: "checkmark",
                       prominent: scanner.lapped) { scanner.finish() }
                    .disabled(scanner.shots < Scanner.fewest)
            case .building:
                ProgressView()
                    .controlSize(.large)
                    .padding(12)
                    .glassEffect(.regular, in: .circle)
            case .failed:
                tool("Закрыть", icon: "xmark", prominent: false) {
                    dismiss()
                }
            case .starting, .finishing, .done:
                EmptyView()
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 12)
    }

    @ViewBuilder
    private func tool(_ title: LocalizedStringKey, icon: String,
                        prominent: Bool,
                        action: @escaping () -> Void) -> some View {
        let label = Label(title, systemImage: icon)
            .font(Typography.detail)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
        if prominent {
            Button(action: action) { label }
                .buttonStyle(.glassProminent)
        } else {
            Button(action: action) { label }
                .buttonStyle(.glass)
        }
    }
}
