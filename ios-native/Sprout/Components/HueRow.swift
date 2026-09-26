import SwiftUI
import UIKit

/// Ряд цветов узора или волны: готовые, свои и «+» в конце. «+» открывает
/// палитру iOS — ту, что с пипеткой, сеткой и спектром; выбранный цвет
/// встаёт в ряд и сразу выбирается. Свой цвет убирается долгим нажатием.
/// Свои цвета общие у узора и волны, их — до `Hue.ownLimit`. Замер кружка
/// отдаётся выбирающему: волна идёт оттуда, где попали пальцем.
struct HueRow: View {
    let current: Hue
    let spots: Spots
    let pick: (Hue, CGRect) -> Void
    let remove: (Channels, CGRect) -> Void

    /// Подсказки о своих цветах — у одного ряда на экран: место одно.
    var hints = false

    @State private var picking = false
    @State private var drafted: Channels?

    private let settings = Settings.shared

    /// По шесть в ряд, как у готовых: одиннадцать и «+» — ровно две строки.
    private static let columns = Array(repeating: GridItem(.flexible(),
                                                           spacing: 6),
                                       count: 6)

    /// Ключи замеров: готовые — своими номерами, свои — после них, «+» —
    /// последним.
    private static let ownBase = 100
    private static let plusKey = 999

    var body: some View {
        LazyVGrid(columns: Self.columns, spacing: 8) {
            ForEach(Tint.allCases) { tint in
                swatch(.preset(tint), key: tint.rawValue)
            }
            ForEach(Array(settings.ownHues.enumerated()), id: \.element) {
                item in
                let key = Self.ownBase + item.offset
                swatch(.own(item.element), key: key)
                    .contextMenu {
                        Button(role: .destructive) {
                            withAnimation(Motion.arrange) {
                                remove(item.element, spots.rect(key))
                            }
                        } label: {
                            Label("Удалить цвет", systemImage: "trash")
                        }
                    }
                    .transition(.scale.combined(with: .opacity))
            }
            if settings.ownHues.count < Hue.ownLimit {
                plus
            }
        }
        .modifier(HueSpot(on: hints, target: .huesRemove))
        .sheet(isPresented: $picking, onDismiss: adopt) {
            HuePicker(colour: $drafted) { picking = false }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    private func swatch(_ hue: Hue, key: Int) -> some View {
        let picked = hue == current
        return Button {
            withAnimation(Motion.pill) { pick(hue, spots.rect(key)) }
        } label: {
            Circle()
                .fill(Palette.swatch(hue))
                .overlay {
                    Circle().strokeBorder(Palette.ink.opacity(0.12),
                                          lineWidth: 0.5)
                }
                .frame(width: Metrics.swatch, height: Metrics.swatch)
                .padding(4)
                .overlay {
                    if picked {
                        Circle().strokeBorder(Palette.accent, lineWidth: 2)
                    }
                }
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(hue.title)
        .accessibilityAddTraits(picked ? .isSelected : [])
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) }
            action: { spots.put($0, at: key) }
    }

    /// «+» — пунктирный кружок того же размера, что цвета: пустое место в
    /// ряду, которое можно занять.
    private var plus: some View {
        Button {
            drafted = nil
            picking = true
            Feel.pick()
        } label: {
            Image(systemName: "plus")
                .font(.system(size: Metrics.swatch * 0.42, weight: .semibold))
                .foregroundStyle(Palette.accent)
                .frame(width: Metrics.swatch, height: Metrics.swatch)
                .overlay {
                    Circle().strokeBorder(Palette.accent.opacity(0.6),
                                          style: StrokeStyle(lineWidth: 1.5,
                                                             dash: [3, 3]))
                }
                .padding(4)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Добавить свой цвет")
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) }
            action: { spots.put($0, at: Self.plusKey) }
        .modifier(HueSpot(on: hints, target: .huesAdd))
        .transition(.scale.combined(with: .opacity))
    }

    /// Палитру закрыли — выбранный цвет встаёт в ряд и сразу красит, волной
    /// от «+». Ничего не выбрали — ничего и не было.
    private func adopt() {
        guard let colour = drafted else { return }
        drafted = nil
        let spot = spots.rect(Self.plusKey)
        withAnimation(Motion.arrange) {
            _ = settings.add(own: colour)
        }
        pick(.own(colour), spot)
    }
}

/// Место подсказки — только у ряда, которому их показывать.
private struct HueSpot: ViewModifier {
    let on: Bool
    let target: Hint.Target

    func body(content: Content) -> some View {
        if on {
            content.hintSpot(target)
        } else {
            content
        }
    }
}

/// Палитра iOS — та самая, с пипеткой, сеткой, спектром и ползунками.
/// SwiftUI-шный `ColorPicker` открывается только своим радужным кружком, а
/// здесь её открывает «+». Цвет — каналами, без прозрачности: узору она ни к
/// чему.
struct HuePicker: UIViewControllerRepresentable {
    @Binding var colour: Channels?
    let done: () -> Void

    func makeUIViewController(context: Context) -> UIColorPickerViewController {
        let picker = UIColorPickerViewController()
        picker.supportsAlpha = false
        picker.title = Lang.text("Свой цвет")
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ picker: UIColorPickerViewController,
                                context: Context) {
        context.coordinator.parent = self
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIColorPickerViewControllerDelegate {
        var parent: HuePicker

        init(_ parent: HuePicker) {
            self.parent = parent
        }

        /// Цвет из широкой гаммы приходит за пределами sRGB — прижимаем.
        func colorPickerViewController(_ picker: UIColorPickerViewController,
                                       didSelect color: UIColor,
                                       continuously: Bool) {
            var red: CGFloat = 0
            var green: CGFloat = 0
            var blue: CGFloat = 0
            var alpha: CGFloat = 0
            guard color.getRed(&red, green: &green, blue: &blue,
                               alpha: &alpha) else { return }
            func channel(_ value: CGFloat) -> Double {
                min(max(Double(value), 0), 1) * 255
            }
            parent.colour = Channels(channel(red), channel(green),
                                     channel(blue))
        }

        func colorPickerViewControllerDidFinish(
            _ picker: UIColorPickerViewController) {
            parent.done()
        }
    }
}
