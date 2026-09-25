import RealityKit
import SwiftUI
import UIKit

/// Сетки, материалы и картинки для RealityKit — общие у сцены и растений.
@MainActor
enum Craft {
    static func model(_ mesh: Mesh3D, _ material: any RealityKit.Material)
        -> ModelEntity? {
        guard let resource = resource(mesh) else { return nil }
        return ModelEntity(mesh: resource, materials: [material])
    }

    static func resource(_ mesh: Mesh3D) -> MeshResource? {
        guard !mesh.isEmpty else { return nil }
        var descriptor = MeshDescriptor(name: "sprout")
        descriptor.positions = MeshBuffers.Positions(mesh.positions)
        descriptor.normals = MeshBuffers.Normals(mesh.normals)
        if mesh.uvs.count == mesh.positions.count {
            descriptor.textureCoordinates = MeshBuffers.TextureCoordinates(
                mesh.uvs)
            descriptor.tangents = MeshBuffers.Tangents(mesh.tangents())
        }
        descriptor.primitives = .triangles(mesh.indices)
        return try? MeshResource.generate(from: [descriptor])
    }

    static func shadow(_ entity: ModelEntity) {
        entity.components.set(GroundingShadowComponent(castsShadow: true))
    }

    /// Тени у всех сеток скана — он приходит деревом сущностей.
    static func shadows(_ entity: Entity) {
        if entity.components.has(ModelComponent.self) {
            entity.components.set(GroundingShadowComponent(castsShadow: true))
        }
        for child in entity.children { shadows(child) }
    }

    static func paint(_ color: Channels, rough: Float,
                      metal: Float = 0) -> PhysicallyBasedMaterial {
        var material = PhysicallyBasedMaterial()
        material.baseColor = .init(tint: Self.color(color))
        material.roughness = .init(floatLiteral: rough)
        material.metallic = .init(floatLiteral: metal)
        return material
    }

    /// Светится само, без света сцены: кольцо и прицел видны и в темноте.
    static func glow(_ color: Channels, opacity: Float) -> UnlitMaterial {
        var material = UnlitMaterial(color: Self.color(color))
        material.blending = .transparent(opacity: .init(floatLiteral: opacity))
        return material
    }

    static func color(_ channels: Channels) -> UIColor {
        UIColor(red: channels.red / 255, green: channels.green / 255,
                blue: channels.blue / 255, alpha: 1)
    }

    static func image(_ picture: Picture) -> CGImage? {
        guard let provider = CGDataProvider(data: Data(picture.pixels) as CFData)
        else { return nil }
        return CGImage(width: picture.width, height: picture.height,
                       bitsPerComponent: 8, bitsPerPixel: 32,
                       bytesPerRow: picture.width * 4,
                       space: CGColorSpaceCreateDeviceRGB(),
                       bitmapInfo: CGBitmapInfo(
                           rawValue: CGImageAlphaInfo.last.rawValue),
                       provider: provider, decode: nil,
                       shouldInterpolate: true, intent: .defaultIntent)
    }
}
