import SwiftUI
import UIKit

/// Ряд цветов узора или волны: готовые, свои и «+» в конце. «+» открывает
/// палитру iOS — ту, что с пипеткой, сеткой и спектром; выбранный цвет
/// встаёт в ряд и сразу выбирается. Свой цвет убирается долгим нажатием.
/// У каждого ряда свои цвета — у узора, волны и кружка хозяина, до
/// `Hue.ownLimit`. Замер кружка отдаётся выбирающему: волна идёт оттуда,
/// где попали пальцем.
struct HueRow: View {
    let current: Hue
    let layer: HueLayer
    let spots: Spots
    let pick: (Hue, CGRect) -> Void
    let remove: (Channels, CGRect) -> Void

    /// Подсказки о своих цветах — у одного ряда на экран: место одно.
    var hints = false


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
            ForEach(Array(settings.own(layer).enumerated()), id: \.element) {
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
            if settings.own(layer).count < Hue.ownLimit {
                plus
            }
        }
        .modifier(HueSpot(on: hints, target: .huesRemove))
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
                .frame(minWidth: Metrics.tapTarget, minHeight: Metrics.tapTarget)
                .contentShape(Rectangle())
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
            Feel.pick()
            SystemPalette.open { adopt($0) }
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
                .frame(minWidth: Metrics.tapTarget, minHeight: Metrics.tapTarget)
                .contentShape(Rectangle())
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Добавить свой цвет")
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) }
            action: { spots.put($0, at: Self.plusKey) }
        .modifier(HueSpot(on: hints, target: .huesAdd))
        .transition(.scale.combined(with: .opacity))
    }

    /// Палитру закрыли с цветом — он встаёт в ряд и сразу красит, волной
    /// от «+». Ничего не выбрали — палитра и не зовёт.
    private func adopt(_ colour: Channels) {
        let spot = spots.rect(Self.plusKey)
        withAnimation(Motion.arrange) {
            _ = settings.add(own: colour, to: layer)
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

/// Палитра iOS — та самая, с пипеткой, сеткой, спектром и ползунками. Её
/// показывает UIKit, своим листом поверх всего, как в «Заметках»: вложенная
/// в лист SwiftUI, она ставила свою шапку под чужую ручку и прыгала
/// высотой. SwiftUI-шный `ColorPicker` открывается только своим радужным
/// кружком, а здесь палитру открывает «+». Цвет — каналами, без
/// прозрачности: узору она ни к чему.
@MainActor
enum SystemPalette {
    /// Живёт, пока палитра открыта: делегат палитра держит слабо.
    private static var keeper: Keeper?

    /// `chosen` зовётся, когда палитру закрыли с выбранным цветом.
    static func open(_ chosen: @escaping (Channels) -> Void) {
        guard keeper == nil, let top = topmost() else { return }
        let picker = UIColorPickerViewController()
        picker.supportsAlpha = false
        picker.title = Lang.text("Свой цвет")
        let keeper = Keeper { colour in
            Self.keeper = nil
            if let colour { chosen(colour) }
        }
        picker.delegate = keeper
        if let sheet = picker.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
        }
        // Смахнули лист вниз — это тоже «готово».
        picker.presentationController?.delegate = keeper
        Self.keeper = keeper
        top.present(picker, animated: true)
    }

    /// Верхний экран — поверх него и настройки, открытые листом.
    private static func topmost() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
        let scene = scenes.first { $0.activationState == .foregroundActive }
            ?? scenes.first
        var top = scene?.keyWindow?.rootViewController
        while let next = top?.presentedViewController { top = next }
        return top
    }

    @MainActor
    private final class Keeper: NSObject, UIColorPickerViewControllerDelegate,
                                UIAdaptivePresentationControllerDelegate {
        private var colour: Channels?
        private var close: ((Channels?) -> Void)?

        init(_ close: @escaping (Channels?) -> Void) {
            self.close = close
        }

        func colorPickerViewController(_ picker: UIColorPickerViewController,
                                       didSelect color: UIColor,
                                       continuously: Bool) {
            colour = Self.channels(color)
        }

        func colorPickerViewControllerDidFinish(
            _ picker: UIColorPickerViewController) {
            finish()
        }

        func presentationControllerDidDismiss(
            _ presentationController: UIPresentationController) {
            finish()
        }

        /// Кнопка и смахивание могут прийти обе — отвечаем один раз.
        private func finish() {
            let close = self.close
            self.close = nil
            close?(colour)
        }

        /// Цвет из широкой гаммы приходит за пределами sRGB — прижимаем.
        private static func channels(_ color: UIColor) -> Channels? {
            var red: CGFloat = 0
            var green: CGFloat = 0
            var blue: CGFloat = 0
            var alpha: CGFloat = 0
            guard color.getRed(&red, green: &green, blue: &blue,
                               alpha: &alpha) else { return nil }
            func channel(_ value: CGFloat) -> Double {
                min(max(Double(value), 0), 1) * 255
            }
            return Channels(channel(red), channel(green), channel(blue))
        }
    }
}
