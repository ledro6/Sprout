import SwiftUI

/// Фото растения на весь экран: щипок и двойное касание увеличивают,
/// увеличенное двигается пальцем, смах вниз или «Закрыть» — назад. Снимков
/// несколько (портрет и своё фото) — листаются.
struct PhotoViewer: View {
    /// Имена файлов в `Shots`, первый — обложка.
    let names: [String]

    @State private var index = 0
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()
            TabView(selection: $index) {
                ForEach(names.indices, id: \.self) { page in
                    PhotoPage(name: names[page]) { dismiss() }
                        .tag(page)
                }
            }
            .tabViewStyle(.page(
                indexDisplayMode: names.count > 1 ? .automatic : .never))
            .ignoresSafeArea()
            Button("Закрыть") { dismiss() }
                .buttonStyle(.glass)
                .frame(minWidth: 44, minHeight: 44)
                .padding(.trailing, Metrics.contentMargin)
        }
        .preferredColorScheme(.dark)
    }
}

/// Одна страница: картинка с увеличением и сдвигом.
private struct PhotoPage: View {
    let name: String
    let close: () -> Void

    @State private var scale = 1.0
    @State private var offset = CGSize.zero
    @GestureState private var pinch = 1.0
    @GestureState private var drag = CGSize.zero

    private static let deepest = 5.0
    private static let tapZoom = 2.5

    private var now: Double { min(max(scale * pinch, 1), Self.deepest) }

    var body: some View {
        GeometryReader { box in
            if let image = Snapshot.image(name) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: box.size.width, height: box.size.height)
                    .scaleEffect(now)
                    .offset(shift(in: box.size))
                    .gesture(pan(in: box.size))
                    .simultaneousGesture(zoom)
                    .onTapGesture(count: 2) {
                        withAnimation(Motion.enter) {
                            scale = scale > 1 ? 1 : Self.tapZoom
                            offset = .zero
                        }
                    }
                    .accessibilityLabel("Фото растения")
                    .accessibilityAddTraits(.isImage)
            }
        }
    }

    /// Сдвиг не уводит картинку за край; на единице вниз тянет «на закрытие».
    private func shift(in size: CGSize) -> CGSize {
        if scale <= 1 {
            return CGSize(width: 0, height: max(drag.height, 0))
        }
        return held(CGSize(width: offset.width + drag.width,
                           height: offset.height + drag.height), in: size)
    }

    private func held(_ moved: CGSize, in size: CGSize) -> CGSize {
        let sideways = size.width * (now - 1) / 2
        let upright = size.height * (now - 1) / 2
        return CGSize(width: min(max(moved.width, -sideways), sideways),
                      height: min(max(moved.height, -upright), upright))
    }

    private func pan(in size: CGSize) -> some Gesture {
        DragGesture()
            .updating($drag) { value, state, _ in
                // На единице — только если тянут больше вниз, чем в бок:
                // горизонталь отдана листанию.
                if scale > 1 || abs(value.translation.height)
                    > abs(value.translation.width) {
                    state = value.translation
                }
            }
            .onEnded { value in
                if scale > 1 {
                    offset = held(CGSize(
                        width: offset.width + value.translation.width,
                        height: offset.height + value.translation.height),
                        in: size)
                } else if value.translation.height > 120,
                          value.translation.height
                            > abs(value.translation.width) {
                    close()
                }
            }
    }

    private var zoom: some Gesture {
        MagnifyGesture()
            .updating($pinch) { value, state, _ in state = value.magnification }
            .onEnded { value in
                scale = min(max(scale * value.magnification, 1), Self.deepest)
                if scale <= 1 { offset = .zero }
            }
    }
}
