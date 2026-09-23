import SwiftUI
import UIKit

/// Выбрать квадратный кадр для карточки. Форму не дают: карточки в сетке
/// одного размера, только если у всех снимков одно соотношение сторон.
/// Арифметика — в `Crop`.
struct Trim: View {
    let image: UIImage
    let onDone: (UIImage) -> Void

    @Environment(\.dismiss) private var dismiss

    /// Принятые увеличение и сдвиг; пока палец на экране, к ним прибавляется
    /// жест.
    @State private var scale: Double = 1
    @State private var offset: CGSize = .zero

    @GestureState private var pinch: Double = 1
    @GestureState private var drag: CGSize = .zero

    @State private var side: Double = 1

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                Spacer(minLength: 0)
                window
                Text("Потяните снимок или разведите пальцы. "
                     + "Двойное нажатие вернёт как было.")
                    .font(Typography.settingNote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 40)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background { SproutBackground() }
            .navigationTitle("Кадр")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Готово") { finish() }
                        .fontWeight(.semibold)
                }
            }
        }
    }

    /// Снимок — наложением на пустой цвет: `scaledToFill` сам по себе
    /// растянул бы разметку.
    private var window: some View {
        Color.clear
            .overlay {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .scaleEffect(live)
                    .offset(held)
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(1, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: Metrics.cardRadius,
                                        style: .continuous))
            .sproutPlate(in: RoundedRectangle(
                cornerRadius: Metrics.cardRadius, style: .continuous))
            .padding(.horizontal, Metrics.contentMargin)
            .onGeometryChange(for: Double.self) { Double($0.size.width) }
                action: { side = max($0, 1) }
            .gesture(pan)
            .simultaneousGesture(zoom)
            .onTapGesture(count: 2) {
                withAnimation(Motion.pill) {
                    scale = 1
                    offset = .zero
                }
                Feel.pick()
            }
            .accessibilityLabel("Кадр снимка")
    }

    private var live: Double {
        min(max(scale * pinch, 1), Crop.deepest)
    }

    /// Сдвиг подрезается на ходу, а не по отпусканию: снимок должен упираться
    /// в край, а не отскакивать от него.
    private var held: CGSize {
        Crop.hold(CGSize(width: offset.width + drag.width,
                         height: offset.height + drag.height),
                  image: image.size, window: side, scale: live)
    }

    private var pan: some Gesture {
        DragGesture()
            .updating($drag) { value, state, _ in state = value.translation }
            .onEnded { value in
                offset = Crop.hold(
                    CGSize(width: offset.width + value.translation.width,
                           height: offset.height + value.translation.height),
                    image: image.size, window: side, scale: scale)
            }
    }

    private var zoom: some Gesture {
        MagnifyGesture()
            .updating($pinch) { value, state, _ in state = value.magnification }
            .onEnded { value in
                scale = min(max(scale * value.magnification, 1), Crop.deepest)
                // После увеличения сдвиг мог выйти за край — подрезаем
                // заново.
                offset = Crop.hold(offset, image: image.size, window: side,
                                   scale: scale)
            }
    }

    private func finish() {
        let crop = Crop.of(image: image.size, window: side, scale: scale,
                           offset: offset)
        onDone(Snapshot.cut(image, to: crop))
        dismiss()
    }
}
