import Foundation

// Рисует готовые модели растений программным растеризатором — с текстурами,
// вырезами по прозрачности и светом, — чтобы видеть их без телефона.
//
//     preview папка влажность вид…
//
// Кладёт в папку по картинке PPM на вид; лист собирает render.py.

struct Camera {
    /// Свет по-мировому; у портрета — от камеры, иначе цветок, смотрящий
    /// от солнца, выходил бы серым.
    var light = Vec3(-0.5, 1.2, 0.8)
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
    let light = camera.view(camera.light + camera.target)
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

/// Портрет цветка: самая высокая головка отдельно от растения — детали,
/// стоящие в той же позе, что её лепестки. Камера — анфас, по направлению,
/// куда цветок смотрит; ракурс подбирается перебором, чтобы не зависеть от
/// знаков поворотов.
func portrait(_ kit: Kit, camera base: Camera) -> (Kit, Camera)? {
    let petals = kit.pieces.filter {
        let look = kit.looks[$0.look]
        return look.cutout && !look.wilts
    }
    guard let top = petals.max(by: { $0.pose.base.y < $1.pose.base.y })
    else { return nil }
    var head = kit
    head.pieces = kit.pieces.filter {
        ($0.pose.base - top.pose.base).size < 1e-6
            && $0.pose.yaw == top.pose.yaw && $0.pose.rise == top.pose.rise
    }
    let forward = top.pose.turn(Vec3(1, 0, 0), lean: 0).unit
    var camera = base
    var best = -Float.infinity
    for yawStep in 0 ..< 72 {
        for pitchStep in -17 ... 17 {
            let yaw = Float(yawStep) * Float.pi / 36
            let pitch = Float(pitchStep) * Float.pi / 36
            let toward = Vec3(0, 0, 1).turned(around: Pose.x, by: -pitch)
                .turned(around: Pose.y, by: yaw)
            // Чуть сверху-сбоку, а не в упор: так видно и объём.
            let aim = (forward + Vec3(0, 0.35, 0)).unit
            let score = toward.dotted(aim)
            if score > best {
                best = score
                camera.yaw = yaw
                camera.pitch = pitch
                camera.light = toward + Vec3(0, 0.6, 0)
            }
        }
    }
    camera.target = top.pose.place(Vec3(0.006, 0, 0), lean: 0)
    camera.distance = 0.11
    return (head, camera)
}

let arguments = CommandLine.arguments
let folder = arguments[1]
let moisture = Double(arguments[2]) ?? 1
var rest = Array(arguments.dropFirst(3))
let close = rest.first == "--close"
if close { rest.removeFirst() }
let wanted = rest.isEmpty ? Preset.allCases.map(\.rawValue) : rest
// Вид можно уточнить названием: «pelargonium:Роза» — роза из того же
// готового набора.
for name in wanted {
    let parts = name.split(separator: ":", maxSplits: 1).map(String.init)
    guard let preset = Preset(rawValue: parts[0]) else { continue }
    let species = parts.count > 1 ? parts[1] : preset.title
    let kit = Botany.grow(.stock(preset), species: species)
    var camera = Camera()
    camera.target = Vec3(0, min(kit.height, 0.6) * 0.5, 0)
    camera.distance = max(0.75, kit.height * 1.7, kit.spread * 2.6)
    var shown = kit
    if close, let (head, near) = portrait(kit, camera: camera) {
        shown = head
        camera = near
    }
    ppm(render(shown, moisture: moisture, camera: camera),
        to: "\(folder)/\(name).ppm")
}
