import Foundation

// Рисует готовые модели растений программным растеризатором — с текстурами,
// вырезами по прозрачности и светом, — чтобы видеть их без телефона.
//
//     preview папка влажность вид…
//
// Кладёт в папку по картинке PPM на вид; лист собирает render.py.

struct Camera {
    var yaw: Float = 0.55
    var pitch: Float = 0.5
    var distance: Float = 0.95
    var target = Vec3(0, 0.2, 0)
    var width = 360
    var height = 440

    func view(_ point: Vec3) -> Vec3 {
        var p = point - target
        p = p.turned(around: Pose.y, by: -yaw)
        p = p.turned(around: Pose.x, by: pitch)
        return Vec3(p.x, p.y, distance - p.z)
    }
}

/// Растеризует набор: z-буфер, барицентрические координаты, текстура по
/// ближайшему пикселю, вырез по прозрачности, свет по Ламберту.
func render(_ kit: Kit, moisture: Double, camera: Camera) -> Picture {
    var image = Picture(width: camera.width, height: camera.height,
                        fill: Ink(0.94, 0.95, 0.96, 1))
    var depth = [Float](repeating: .infinity,
                        count: camera.width * camera.height)
    let light = camera.view(Vec3(-0.5, 1.2, 0.8) + camera.target)
        - camera.view(camera.target)
    let sun = light.unit
    let focal = Float(camera.height) * 1.5
    let sag = Greenhouse.sag(moisture)
    let wither = Greenhouse.wither(moisture)
    let wet = Greenhouse.wetTint(moisture).ink()
    for piece in kit.pieces {
        let mesh = kit.meshes[piece.mesh]
        let look = kit.looks[piece.look]
        let lean = piece.sag * sag
        let points = mesh.positions.map {
            camera.view(piece.pose.place($0, lean: lean))
        }
        let normals = mesh.normals.map {
            (camera.view(piece.pose.turn($0, lean: lean) + camera.target)
                - camera.view(camera.target)).unit
        }
        let screen = points.map {
            SIMD2<Float>(Float(camera.width) / 2 + $0.x / $0.z * focal,
                         Float(camera.height) / 2 - $0.y / $0.z * focal)
        }
        var tint = look.tint.ink()
        if look.wets { tint *= wet }
        let texture = look.color.map {
            look.wilts ? kit.pictures[$0].withered(wither) : kit.pictures[$0]
        }
        for face in stride(from: 0, to: mesh.indices.count, by: 3) {
            let a = Int(mesh.indices[face])
            let b = Int(mesh.indices[face + 1])
            let c = Int(mesh.indices[face + 2])
            let edge1 = points[b] - points[a]
            let edge2 = points[c] - points[a]
            let facing = edge1.crossed(edge2)
            // Камера в начале координат смотрит вдоль +z: видна грань, чья
            // нормаль смотрит к камере.
            guard facing.dotted(points[a]) > 0 else { continue }
            let pa = screen[a], pb = screen[b], pc = screen[c]
            let minX = max(Int(min(pa.x, pb.x, pc.x)), 0)
            let maxX = min(Int(max(pa.x, pb.x, pc.x)) + 1, camera.width - 1)
            let minY = max(Int(min(pa.y, pb.y, pc.y)), 0)
            let maxY = min(Int(max(pa.y, pb.y, pc.y)) + 1, camera.height - 1)
            guard minX <= maxX, minY <= maxY else { continue }
            let area = (pb.x - pa.x) * (pc.y - pa.y) - (pb.y - pa.y) * (pc.x - pa.x)
            guard abs(area) > 1e-9 else { continue }
            for y in minY ... maxY {
                for x in minX ... maxX {
                    let p = SIMD2<Float>(Float(x) + 0.5, Float(y) + 0.5)
                    let w0 = ((pb.x - p.x) * (pc.y - p.y)
                        - (pb.y - p.y) * (pc.x - p.x)) / area
                    let w1 = ((pc.x - p.x) * (pa.y - p.y)
                        - (pc.y - p.y) * (pa.x - p.x)) / area
                    let w2 = 1 - w0 - w1
                    guard w0 >= 0, w1 >= 0, w2 >= 0 else { continue }
                    let z = w0 * points[a].z + w1 * points[b].z + w2 * points[c].z
                    let at = y * camera.width + x
                    guard z < depth[at] else { continue }
                    var color = tint
                    if let texture {
                        let uv = mesh.uvs[a] * w0 + mesh.uvs[b] * w1
                            + mesh.uvs[c] * w2
                        let u = uv.x - floor(uv.x)
                        let v = uv.y - floor(uv.y)
                        let tx = min(Int(u * Float(texture.width)),
                                     texture.width - 1)
                        let ty = min(Int((1 - v) * Float(texture.height)),
                                     texture.height - 1)
                        let texel = texture.ink(at: tx, ty)
                        if look.cutout && texel.w < 0.5 { continue }
                        color *= texel
                    }
                    let normal = (normals[a] * w0 + normals[b] * w1
                        + normals[c] * w2).unit
                    let lit = max(normal.dotted(sun), 0)
                    let shade = 0.38 + 0.72 * lit
                    var rgb = SIMD3(color.x, color.y, color.z) * shade
                    if look.opacity < 1 {
                        let old = image.ink(at: x, y)
                        rgb = rgb * look.opacity
                            + SIMD3(old.x, old.y, old.z) * (1 - look.opacity)
                    } else {
                        depth[at] = z
                    }
                    image.set(x, y, Ink(rgb.x, rgb.y, rgb.z, 1))
                }
            }
        }
    }
    return image
}

func ppm(_ picture: Picture, to path: String) {
    var data = Data("P6\n\(picture.width) \(picture.height)\n255\n".utf8)
    for index in 0 ..< picture.width * picture.height {
        data.append(picture.pixels[index * 4])
        data.append(picture.pixels[index * 4 + 1])
        data.append(picture.pixels[index * 4 + 2])
    }
    try! data.write(to: URL(fileURLWithPath: path))
}

let arguments = CommandLine.arguments
let folder = arguments[1]
let moisture = Double(arguments[2]) ?? 1
let wanted = arguments.count > 3 ? Array(arguments[3...]) : Preset.allCases.map(\.rawValue)
for name in wanted {
    guard let preset = Preset(rawValue: name) else { continue }
    let kit = Botany.grow(.stock(preset), species: preset.title)
    var camera = Camera()
    camera.target = Vec3(0, min(kit.height, 0.6) * 0.5, 0)
    camera.distance = max(0.75, kit.height * 1.7, kit.spread * 2.6)
    ppm(render(kit, moisture: moisture, camera: camera),
        to: "\(folder)/\(name).ppm")
}
