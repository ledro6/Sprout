import SwiftUI
import UIKit

/// Выбрать кадр: что из снимка попадёт на карточку.
///
/// Кадр всегда квадратный, и выбирать его форму не дают. Карточки в сетке
/// обязаны быть одного размера — иначе ряд с высокой расталкивает
/// соседние, — а один размер у них будет ровно тогда, когда у всех
/// снимков одно соотношение сторон. Это не украшение, а условие, на
/// котором держится вёрстка.
///
/// Снимок двигают пальцем и разводят двумя; двойное нажатие возвращает
/// всё как было. Из окна он не выходит: сдвиг и увеличение подрезаются
/// прямо на ходу — см. `Crop`, там же и вся арифметика.
struct Trim: View {
    let image: UIImage
    let onDone: (UIImage) -> Void

    @Environment(\.dismiss) private var dismiss

    /// Увеличение и сдвиг, уже принятые. Пока палец на экране, к ним
    /// прибавляется то, что он делает прямо сейчас.
    @State private var scale: Double = 1
    @State private var offset: CGSize = .zero

    @GestureState private var pinch: Double = 1
    @GestureState private var drag: CGSize = .zero

    /// Сторона окна на экране. Нужна и разметке, и арифметике кадра.
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

    /// Квадратное окно со снимком внутри.
    ///
    /// Снимок лежит в наложении на пустой цвет: `scaledToFill` сообщает о
    /// себе размер больше предложенного, и сам по себе он растянул бы
    /// разметку. Пустой цвет берёт ровно предложенное, а наложение
    /// обрезается по нему.
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

    /// Увеличение с учётом того, что делает палец прямо сейчас.
    private var live: Double {
        min(max(scale * pinch, 1), Crop.deepest)
    }

    /// И сдвиг — сразу подрезанный по краям снимка. Подрезка на ходу, а
    /// не по отпусканию пальца: иначе снимок отходил бы от края и
    /// отскакивал назад, а он должен упираться.
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
                // Приблизили и отпустили — сдвиг мог оказаться за краем:
                // подрезаем его по новому увеличению.
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
