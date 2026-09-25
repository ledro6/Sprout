import Metal
import RealityKit
import UIKit

/// Вода лейки в сцене. Полёт порций и сетку струи считает `Rill`; здесь —
/// перевод в RealityKit. Сетка одна на всю воду и живёт в `LowLevelMesh`:
/// каждый кадр в её буферы ложатся новые точки, и видеокарта рисует её
/// одним вызовом. Воду из сетки делает шейдер `sproutWater` (Water.metal):
/// прозрачная, с отражениями комнаты по краю и бегущей рябью. Брызги у
/// земли — частицы RealityKit, круги на земле — шейдер `sproutPuddle`.
@MainActor
final class Stream {
    let entity = ModelEntity()
    let splash = Entity()

    private var rill: Rill
    private var splashing = false
    private let room: (vertices: Int, indices: Int)
    private let mesh: LowLevelMesh?
    private let material: any RealityKit.Material

    init(jets count: Int) {
        rill = Rill(jets: count)
        room = rill.room
        mesh = Self.makeMesh(room)
        material = WaterLook.stream()
        entity.isEnabled = false
        splash.components.set(WaterLook.splash())
    }

    var idle: Bool { rill.idle }

    /// Новый полив: вода и брызги переезжают к растению.
    func begin(on anchor: Entity, scale: Float, clearance: Float) {
        entity.setParent(anchor)
        splash.setParent(anchor)
        rill.begin(scale: scale,
                   flight: Rill.flight(scale: scale, clearance: clearance))
        emit(false)
        var emitter = splash.components[ParticleEmitterComponent.self]
            ?? WaterLook.splash()
        emitter.speed = 0.3 * scale.squareRoot()
        emitter.mainEmitter.size = 0.0022 * scale
        splash.components.set(emitter)
    }

    func pour(from mouth: Vec3, jet: Vec3, side: Vec3, dt: Double) {
        rill.pour(from: mouth, jet: jet, side: side, dt: dt)
    }

    func stop() { rill.stop() }

    /// Полёт за кадр и новая сетка. Ответ — где вода коснулась земли в
    /// горшке; там же брызги.
    func fly(_ dt: Float, ground: Float, center: Vec3, mouth: Float,
             floor: Float) -> Vec3? {
        let hit = rill.fly(dt, ground: ground, center: center, mouth: mouth,
                           floor: floor)
        if let hit { splash.position = hit }
        emit(hit != nil)
        draw()
        return hit
    }

    /// Остановить всё: растения убрали или переставили.
    func reset() {
        rill.clear()
        emit(false)
        entity.isEnabled = false
    }

    private func emit(_ on: Bool) {
        guard on != splashing,
              var emitter = splash.components[ParticleEmitterComponent.self]
        else { return }
        splashing = on
        emitter.isEmitting = on
        splash.components.set(emitter)
    }

    private func draw() {
        let (vertices, indices) = rill.geometry()
        guard !indices.isEmpty else {
            entity.isEnabled = false
            return
        }
        var low = vertices[0].position
        var high = low
        for vertex in vertices {
            low = pointwiseMin(low, vertex.position)
            high = pointwiseMax(high, vertex.position)
        }
        if let mesh, vertices.count <= room.vertices,
           indices.count <= room.indices {
            vertices.withUnsafeBytes { source in
                mesh.withUnsafeMutableBytes(bufferIndex: 0) { target in
                    target.copyMemory(from: source)
                }
            }
            indices.withUnsafeBytes { source in
                mesh.withUnsafeMutableIndices { target in
                    target.copyMemory(from: source)
                }
            }
            mesh.parts.replaceAll([LowLevelMesh.Part(
                indexCount: indices.count, topology: .triangle,
                bounds: BoundingBox(min: low, max: high))])
            if entity.model == nil,
               let resource = try? MeshResource(from: mesh) {
                entity.model = ModelComponent(mesh: resource,
                                              materials: [material])
            }
        } else {
            // Низкоуровневой сетки нет — обычная, заново каждый кадр.
            var descriptor = MeshDescriptor(name: "water")
            descriptor.positions = MeshBuffers.Positions(
                vertices.map(\.position))
            descriptor.normals = MeshBuffers.Normals(vertices.map(\.normal))
            descriptor.textureCoordinates = MeshBuffers.TextureCoordinates(
                vertices.map(\.uv))
            descriptor.primitives = .triangles(indices)
            guard let resource = try? MeshResource.generate(from: [descriptor])
            else { return }
            entity.model = ModelComponent(mesh: resource,
                                          materials: [material])
        }
        entity.isEnabled = true
    }

    /// Буферы — на самую длинную струю, раз и навсегда.
    private static func makeMesh(_ room: (vertices: Int, indices: Int))
        -> LowLevelMesh? {
        typealias Vertex = Rill.Vertex
        var descriptor = LowLevelMesh.Descriptor()
        descriptor.vertexAttributes = [
            .init(semantic: .position, format: .float3,
                  offset: MemoryLayout<Vertex>.offset(of: \.position)!),
            .init(semantic: .normal, format: .float3,
                  offset: MemoryLayout<Vertex>.offset(of: \.normal)!),
            .init(semantic: .tangent, format: .float3,
                  offset: MemoryLayout<Vertex>.offset(of: \.tangent)!),
            .init(semantic: .uv0, format: .float2,
                  offset: MemoryLayout<Vertex>.offset(of: \.uv)!),
        ]
        descriptor.vertexLayouts = [
            .init(bufferIndex: 0, bufferStride: MemoryLayout<Vertex>.stride),
        ]
        descriptor.vertexCapacity = room.vertices
        descriptor.indexCapacity = room.indices
        descriptor.indexType = .uint32
        return try? LowLevelMesh(descriptor: descriptor)
    }
}

/// Материалы и частицы воды. Шейдеры — в Water.metal; нет их (симулятор) —
/// прозрачный лак без ряби.
@MainActor
enum WaterLook {
    private static let library = MTLCreateSystemDefaultDevice()?
        .makeDefaultLibrary()

    /// Цвет воды — чуть голубой: на просвет она почти бесцветна.
    private static let tint = SIMD4<Float>(0.8, 0.9, 1, 0)

    static func stream() -> any RealityKit.Material {
        if let library, var material = try? CustomMaterial(
            surfaceShader: CustomMaterial.SurfaceShader(named: "sproutWater",
                                                        in: library),
            lightingModel: .clearcoat) {
            material.custom.value = tint
            material.blending = .transparent(opacity: .init(floatLiteral: 1))
            material.faceCulling = .none
            return material
        }
        var plain = PhysicallyBasedMaterial()
        plain.baseColor = .init(tint: UIColor(red: 0.75, green: 0.87, blue: 1,
                                              alpha: 1))
        plain.roughness = .init(floatLiteral: 0.03)
        plain.metallic = .init(floatLiteral: 0)
        plain.clearcoat = .init(floatLiteral: 1)
        plain.blending = .transparent(opacity: .init(floatLiteral: 0.55))
        plain.faceCulling = .none
        return plain
    }

    /// Вода на земле: `strength` — сколько её, `spot` — куда бьёт струя, в
    /// развёртке диска.
    static func puddle(strength: Float,
                       spot: SIMD2<Float>) -> CustomMaterial? {
        guard let library, var material = try? CustomMaterial(
            surfaceShader: CustomMaterial.SurfaceShader(named: "sproutPuddle",
                                                        in: library),
            lightingModel: .lit)
        else { return nil }
        material.custom.value = SIMD4(spot.x, spot.y, 0, strength)
        material.blending = .transparent(opacity: .init(floatLiteral: 1))
        return material
    }

    /// Брызги из-под струи: мелкие капли вверх и в стороны, падают обратно.
    static func splash() -> ParticleEmitterComponent {
        var emitter = ParticleEmitterComponent()
        emitter.emitterShape = .point
        emitter.birthDirection = .local
        emitter.emissionDirection = [0, 1, 0]
        emitter.speed = 0.3
        emitter.speedVariation = 0.12
        emitter.timing = .repeating(warmUp: 0, emit: .init(duration: 60))
        emitter.isEmitting = false
        emitter.mainEmitter.birthRate = 240
        emitter.mainEmitter.lifeSpan = 0.32
        emitter.mainEmitter.lifeSpanVariation = 0.1
        emitter.mainEmitter.spreadingAngle = 0.95
        emitter.mainEmitter.acceleration = [0, -Pouring.gravity, 0]
        emitter.mainEmitter.size = 0.0022
        emitter.mainEmitter.sizeVariation = 0.001
        emitter.mainEmitter.sizeMultiplierAtEndOfLifespan = 0.4
        emitter.mainEmitter.color = .constant(.single(
            UIColor(red: 0.82, green: 0.92, blue: 1, alpha: 0.85)))
        emitter.mainEmitter.opacityCurve = .linearFadeOut
        emitter.mainEmitter.blendMode = .alpha
        emitter.mainEmitter.isLightingEnabled = true
        emitter.mainEmitter.stretchFactor = 0.5
        return emitter
    }
}
