import AVFoundation
import RealityKit
import SwiftUI

/// Ход скана: сессия съёмки, потом сборка модели. Сессия Object Capture —
/// одна на экран; кончилась съёмка — камеру отпускаем, иначе сборке не
/// хватит памяти. Состояние сессии читается и потоком, и опросом: поток
/// отдаёт только перемены, и «готова», случившееся до подписки, терялось —
/// экран навсегда оставался на «Включаю камеру…». Рамку сессия ставит сама,
/// как только под растением найден пол или стол: без плоскости
/// `startDetecting` молча отказывает.
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

    /// Что мешает съёмке — строкой для хозяина; пусто — всё хорошо.
    private(set) var trouble: String?

    /// Камера потеряла опору — поверх показывается подсказка ARKit, свою
    /// лучше убрать.
    private(set) var coaching = false

    @ObservationIgnored private var seen: ObjectCaptureSession.CaptureState?

    /// Сессия съёмки — её показывает `ObjectCaptureView`; после съёмки её
    /// нет, и на экране — ход сборки.
    private(set) var session: ObjectCaptureSession?
    @ObservationIgnored private var work: URL?
    @ObservationIgnored private var plant: Plant.ID?
    @ObservationIgnored private var watching: Task<Void, Never>?
    @ObservationIgnored private var counting: Task<Void, Never>?
    @ObservationIgnored private var assembling: PhotogrammetrySession?

    /// Сначала — разрешение на камеру: без него сессия встаёт намертво.
    func start(_ id: Plant.ID) async {
        guard session == nil, work == nil else { return }
        guard ScanView.supported, let base = Scans.folder else {
            step = .failed(Lang.text("Этот iPhone не умеет сканировать: нужен LiDAR."))
            return
        }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            break
        case .notDetermined:
            guard await AVCaptureDevice.requestAccess(for: .video) else {
                step = .failed(Self.blind)
                return
            }
        default:
            step = .failed(Self.blind)
            return
        }
        guard session == nil, work == nil else { return }
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
        // Состояние, кадры, круг, помехи и опора камеры — опросом: так не
        // важно, как и когда сессия сообщает о них сама.
        counting = Task { [weak self] in
            while !Task.isCancelled {
                guard let self, let session = self.session else { return }
                self.follow(session.state)
                if self.shots != session.numberOfShotsTaken {
                    self.shots = session.numberOfShotsTaken
                }
                if self.lapped != session.userCompletedScanPass {
                    self.lapped = session.userCompletedScanPass
                }
                let trouble = Self.trouble(session.feedback)
                if self.trouble != trouble { self.trouble = trouble }
                var steady = false
                if case .normal = session.cameraTracking { steady = true }
                let coaching = !steady && session.state != .ready
                if self.coaching != coaching { self.coaching = coaching }
                // Готова — ставим рамку сами, как только найдётся опора.
                if session.state == .ready { _ = session.startDetecting() }
                try? await Task.sleep(for: .milliseconds(250))
            }
        }
    }

    /// Нет доступа к камере — куда идти.
    private static var blind: String {
        Lang.text("Нет доступа к камере. Разрешите его в Настройках → Sprout.")
    }

    /// Самая важная помеха из тех, о которых говорит сессия.
    private static func trouble(_ feedback: Set<ObjectCaptureSession.Feedback>)
        -> String? {
        if feedback.contains(.environmentTooDark) {
            return Lang.text("Слишком темно — включите свет")
        }
        if feedback.contains(.environmentLowLight) {
            return Lang.text("Темновато — модель выйдет тусклой")
        }
        if feedback.contains(.movingTooFast) {
            return Lang.text("Медленнее — кадры смазываются")
        }
        if feedback.contains(.objectTooClose) {
            return Lang.text("Отойдите чуть дальше")
        }
        if feedback.contains(.objectTooFar) {
            return Lang.text("Подойдите ближе")
        }
        if feedback.contains(.outOfFieldOfView) {
            return Lang.text("Растение ушло из кадра")
        }
        if feedback.contains(.objectNotDetected) {
            return Lang.text("Не вижу растения — наведите камеру на него")
        }
        return nil
    }

    /// Рамку заново: обняла не то.
    func redetect() {
        guard let session, session.state == .detecting else { return }
        _ = session.resetDetection()
    }

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
        guard state != seen else { return }
        seen = state
        switch state {
        case .initializing: step = .starting
        case .ready: step = .aiming
        case .detecting: step = .detecting
        case .capturing: step = .capturing
        case .finishing: step = .finishing
        case .completed: assemble()
        case .failed(let error): step = .failed(Self.reason(error))
        @unknown default: break
        }
    }

    private static func reason(_ error: any Error) -> String {
        switch error as? ObjectCaptureSession.Error {
        case .insufficientStorage:
            Lang.text("Не хватает места на телефоне: кадрам нужно несколько гигабайт.")
        case .trackingFailed:
            Lang.text("Камера потеряла растение. Попробуйте ещё раз, при ровном свете и медленнее.")
        case .sensorFailed:
            Lang.text("Датчик LiDAR не ответил. Перезапустите приложение и попробуйте снова.")
        default:
            error.localizedDescription
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
        // Сессия съёмки должна отпустить камеру и память до сборки — как
        // в образце Apple: иначе сборка падает, не начавшись.
        Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(600))
            self?.build(work: work, plant: plant, into: scans)
        }
    }

    private func build(work: URL, plant: Plant.ID, into scans: URL) {
        guard assembling == nil else { return }
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
