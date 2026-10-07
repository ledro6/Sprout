import AVFoundation
import SwiftUI
import UIKit

/// Камера для снимка растения. Доступ запрещён — вместо чёрного экрана
/// системы честная строка и «Открыть Настройки». Ещё не спрашивали —
/// спросит сама системная камера.
struct Camera: View {
    let onShot: (UIImage) -> Void

    @Environment(\.dismiss) private var dismiss

    static var exists: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    private var denied: Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        return status == .denied || status == .restricted
    }

    var body: some View {
        if denied {
            VStack(spacing: 20) {
                AccessNote(need: .camera)
                Button("Закрыть") { dismiss() }
                    .font(Typography.settingNote)
            }
            .padding(Metrics.contentMargin)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background { SproutBackground() }
        } else {
            CameraPicker(onShot: onShot)
                .ignoresSafeArea()
        }
    }
}

/// Системная камера из UIKit: в SwiftUI её нет, `PhotosPicker` умеет только
/// библиотеку. В симуляторе камеры нет — см. `Camera.exists`.
struct CameraPicker: UIViewControllerRepresentable {
    let onShot: (UIImage) -> Void

    @Environment(\.dismiss) private var dismiss

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
        private let camera: CameraPicker

        init(_ camera: CameraPicker) { self.camera = camera }

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
