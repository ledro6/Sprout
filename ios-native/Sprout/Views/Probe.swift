import ARKit
import Foundation
import Metal

/// Факты о телефоне для `Rig`: семейство графики, память, LiDAR и нагрев.
/// Решения по ним — в модели, здесь только замер.
enum Probe {
    static var hardware: Rig.Hardware {
        let info = ProcessInfo.processInfo
        return Rig.Hardware(
            gpu: gpu,
            memory: Double(info.physicalMemory) / 1_073_741_824,
            lidar: ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh),
            strained: info.isLowPowerModeEnabled
                || info.thermalState == .serious
                || info.thermalState == .critical)
    }

    static var rig: Rig { Rig.of(hardware) }

    /// Семейство графики: 9 — A17 Pro и новее, 8 — A15 и A16, 7 — A14.
    private static let gpu: Int = {
        guard let device = MTLCreateSystemDefaultDevice() else { return 6 }
        let families: [(MTLGPUFamily, Int)] = [
            (.apple9, 9), (.apple8, 8), (.apple7, 7), (.apple6, 6),
        ]
        return families.first { device.supportsFamily($0.0) }?.1 ?? 5
    }()
}
