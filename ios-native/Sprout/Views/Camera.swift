import SwiftUI
import UIKit

/// Камера — системная, из UIKit.
///
/// В SwiftUI камеры нет: `PhotosPicker` умеет только библиотеку. Своей
/// камеры здесь и не нужно — снимок делается системным экраном, тем же,
/// что во всех приложениях, со всеми его вспышками и переключениями.
///
/// Есть она не везде: в симуляторе камеры нет вовсе, и кнопку туда
/// показывать нельзя — см. `Camera.exists`.
struct Camera: UIViewControllerRepresentable {
    let onShot: (UIImage) -> Void

    @Environment(\.dismiss) private var dismiss

    static var exists: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ picker: UIImagePickerController,
                                context: Context) {}

    func makeCoordinator() -> Shutter { Shutter(self) }

    /// Посредник между UIKit и SwiftUI: снимок приходит делегатом, а
    /// закрывается экран тем же `dismiss`, что и любой лист.
    final class Shutter: NSObject, UIImagePickerControllerDelegate,
                         UINavigationControllerDelegate {
        private let camera: Camera

        init(_ camera: Camera) { self.camera = camera }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info:
                [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                camera.onShot(image)
            }
            camera.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            camera.dismiss()
        }
    }
}
