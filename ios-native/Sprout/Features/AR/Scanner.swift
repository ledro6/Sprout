import RealityKit
import SwiftUI

/// Ход скана: сессия съёмки, потом сборка модели. Сессия Object Capture —
/// одна на экран; кончилась съёмка — камеру отпускаем, иначе сборке не
/// хватит памяти.
@MainActor
@Observable
final class Scanner {
    enum Step: Equatable {
        case starting
        /// Камера готова — ждём, когда наведут на растение.
        case aiming
        /// Рамка вокруг растения — можно начинать.
        case detecting
        case capturing
        case finishing
        /// Сборка модели, 0…1.
        case building(Double)
        /// Модель готова: имя файла в `Scans`.
        case done(String)
        case failed(String)
    }

    /// Меньше кадров — модель выйдет дырявой.
    static let fewest = 20

    /// Сборка не удалась — что сказать хозяину.
    private static var broken: String {
        Lang.text("Модель не собралась. Попробуйте снять ещё раз, при ровном свете.")
    }

    private(set) var step: Step = .starting
    private(set) var shots = 0
    /// Круг пройден — можно заканчивать или снять ещё один.
    private(set) var lapped = false

    /// Сессия съёмки — её показывает `ObjectCaptureView`; после съёмки её
    /// нет, и на экране — ход сборки.
    private(set) var session: ObjectCaptureSession?
    @ObservationIgnored private var work: URL?
    @ObservationIgnored private var plant: Plant.ID?
    @ObservationIgnored private var watching: Task<Void, Never>?
    @ObservationIgnored private var counting: Task<Void, Never>?
    @ObservationIgnored private var assembling: PhotogrammetrySession?

    /// Шаги съёмки приходят потоком состояний сессии.
    func start(_ id: Plant.ID) {
        guard session == nil, work == nil else { return }
        guard ScanView.supported, let base = Scans.folder else {
            step = .failed(Lang.text("Этот iPhone не умеет сканировать: нужен LiDAR."))
            return
        }
        plant = id
        let folder = base.appendingPathComponent("work-\(id)", isDirectory: true)
        let images = folder.appendingPathComponent("Images", isDirectory: true)
        let checkpoints = folder.appendingPathComponent("Checkpoint",
                                                        isDirectory: true)
        let manager = FileManager.default
        try? manager.removeItem(at: folder)
        do {
            try manager.createDirectory(at: images,
                                        withIntermediateDirectories: true)
            try manager.createDirectory(at: checkpoints,
                                        withIntermediateDirectories: true)
        } catch {
            step = .failed(Lang.text("Не нашлось места для кадров."))
            return
        }
        work = folder
        let session = ObjectCaptureSession()
        var configuration = ObjectCaptureSession.Configuration()
        configuration.checkpointDirectory = checkpoints
        session.start(imagesDirectory: images, configuration: configuration)
        self.session = session
        watching = Task { [weak self] in
            for await state in session.stateUpdates {
                self?.follow(state)
            }
        }
        // Число кадров и пройденный круг — опросом: так не важно, как
        // сессия сообщает о них сама.
        counting = Task { [weak self] in
            while !Task.isCancelled {
                guard let self, let session = self.session else { return }
                if self.shots != session.numberOfShotsTaken {
                    self.shots = session.numberOfShotsTaken
                }
                if self.lapped != session.userCompletedScanPass {
                    self.lapped = session.userCompletedScanPass
                }
                try? await Task.sleep(for: .milliseconds(250))
            }
        }
    }

    func detect() { _ = session?.startDetecting() }

    func capture() { session?.startCapturing() }

    func lap() {
        lapped = false
        session?.beginNewScanPass()
    }

    func finish() { session?.finish() }

    /// Ушли с экрана — всё останавливается, кадры удаляются.
    func cancel() {
        watching?.cancel()
        counting?.cancel()
        session?.cancel()
        session = nil
        assembling?.cancel()
        assembling = nil
        if case .done = step {} else { clear() }
    }

    private func follow(_ state: ObjectCaptureSession.CaptureState) {
        switch state {
        case .initializing: step = .starting
        case .ready: step = .aiming
        case .detecting: step = .detecting
        case .capturing: step = .capturing
        case .finishing: step = .finishing
        case .completed: assemble()
        case .failed(let error): step = .failed(error.localizedDescription)
        @unknown default: break
        }
    }

    /// Съёмка кончилась — собираем модель из кадров. Детализация
    /// «уменьшенная» — та, что по силам телефону, и для AR её хватает с
    /// запасом.
    private func assemble() {
        guard assembling == nil, let work, let plant,
              let scans = Scans.folder
        else { return }
        watching?.cancel()
        counting?.cancel()
        session = nil
        step = .building(0)
        let name = "\(plant)-\(UUID().uuidString.prefix(8)).usdz"
        let output = scans.appendingPathComponent(name)
        var configuration = PhotogrammetrySession.Configuration()
        configuration.checkpointDirectory = work.appendingPathComponent(
            "Checkpoint", isDirectory: true)
        let assembling: PhotogrammetrySession
        do {
            assembling = try PhotogrammetrySession(
                input: work.appendingPathComponent("Images", isDirectory: true),
                configuration: configuration)
            try assembling.process(requests: [
                .modelFile(url: output, detail: .reduced),
            ])
        } catch {
            step = .failed(Self.broken)
            clear()
            return
        }
        self.assembling = assembling
        Task { [weak self] in
            do {
                for try await update in assembling.outputs {
                    guard let self else { return }
                    switch update {
                    case .requestProgress(_, let share):
                        self.step = .building(min(max(share, 0), 0.99))
                    case .requestComplete:
                        self.clear()
                        self.step = .done(name)
                    case .requestError:
                        self.clear()
                        self.step = .failed(Self.broken)
                    default:
                        break
                    }
                }
            } catch {
                self?.clear()
                self?.step = .failed(Self.broken)
            }
        }
    }

    /// Кадры и контрольные точки — прочь: модель уже в своём файле или
    /// её не будет.
    private func clear() {
        guard let work else { return }
        try? FileManager.default.removeItem(at: work)
        self.work = nil
    }
}
