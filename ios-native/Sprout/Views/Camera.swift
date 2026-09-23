import SwiftUI
import UIKit

/// Системная камера из UIKit: в SwiftUI её нет, `PhotosPicker` умеет только
/// библиотеку. В симуляторе камеры нет — см. `Camera.exists`.
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
