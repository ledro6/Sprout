import Foundation

// Выгружает объёмные растения в OBJ с цветами вершин — для
// tool/preview_plants.sh. Первый аргумент — папка, второй — влажность.

func write(_ name: String, _ parts: [(Mesh3D, Channels)], to folder: String) {
    var out = ""
    var base = 1
    for (mesh, color) in parts {
        for (point, normal) in zip(mesh.positions, mesh.normals) {
            out += "v \(point.x) \(point.y) \(point.z) \(color.red / 255) "
                + "\(color.green / 255) \(color.blue / 255)\n"
            out += "vn \(normal.x) \(normal.y) \(normal.z)\n"
        }
        for face in stride(from: 0, to: mesh.indices.count, by: 3) {
            let a = Int(mesh.indices[face]) + base
            let b = Int(mesh.indices[face + 1]) + base
            let c = Int(mesh.indices[face + 2]) + base
            out += "f \(a)//\(a) \(b)//\(b) \(c)//\(c)\n"
        }
        base += mesh.positions.count
    }
    try! out.write(toFile: "\(folder)/\(name).obj", atomically: true,
                   encoding: .utf8)
}

/// Та же поза, что даёт шарнир в сцене.
func placed(_ sprig: Sprig, _ mesh: Mesh3D, lean: Float) -> Mesh3D {
    var out = mesh
    out.positions = mesh.positions.map { sprig.place($0, lean: lean) }
    out.normals = mesh.normals.map {
        $0.turned(around: Vec3(0, 0, 1), by: sprig.rise - lean)
            .turned(around: Vec3(0, 1, 0), by: sprig.yaw)
    }
    return out
}

let folder = CommandLine.arguments[1]
let moisture = Double(CommandLine.arguments[2]) ?? 1
let species = ["Монстера", "Кактус", "Тюльпан", "Папоротник", "Драцена",
               "Базилик", "Плющ", "Алоэ", "Фиалка", "Ромашка", "Орхидея",
               "Спатифиллум"]
for (index, name) in species.enumerated() {
    let plant = Plant(id: "preview-\(index)", name: name, species: name,
                      moisture: moisture, dryingDays: 7,
                      addedOn: DateComponents(year: 2025, month: 1, day: 1))
    let grown = Greenhouse.grow(plant)
    let lean = Greenhouse.sag(moisture)
    var parts: [(Mesh3D, Channels)] = [
        (grown.pot, grown.potColor),
        (grown.soil, Greenhouse.soilColor(moisture)),
        (grown.stems, grown.stemColor),
        (grown.body, Greenhouse.leafColor(grown.bodyColor, moisture: moisture)),
        (Sculpt.arc(inner: 0.098, outer: 0.11, sweep: Float(moisture)),
         Greenhouse.ringColor(moisture)),
    ]
    for sprig in grown.sprigs {
        for part in sprig.parts {
            let color = part.wilts
                ? Greenhouse.leafColor(part.color, moisture: moisture)
                : part.color
            parts.append((placed(sprig, part.mesh, lean: sprig.sag * lean),
                          color))
        }
    }
    write("\(index)", parts, to: folder)
}

// Лейка в полный наклон над монстерой и струя.
let plant = Plant(id: "preview-0", name: "", species: "Монстера",
                  moisture: moisture, dryingDays: 7,
                  addedOn: DateComponents(year: 2025, month: 1, day: 1))
let grown = Greenhouse.grow(plant)
let lift = Pouring.clearance(over: grown.height)
let origin = Pouring.origin(scale: 1, clearance: lift)
var scene: [(Mesh3D, Channels)] = [
    (grown.pot, grown.potColor), (grown.soil, Greenhouse.soilColor(moisture)),
    (grown.stems, grown.stemColor),
    (WateringCan.mesh.turned(around: Vec3(0, 0, 1), by: -Pouring.angle)
        .moved(by: Vec3(origin.x, origin.y, 0)), Tint.defaultWave.vivid),
]
for sprig in grown.sprigs {
    for part in sprig.parts { scene.append((placed(sprig, part.mesh, lean: 0),
                                            part.color)) }
}
let tip = Pouring.spout(from: origin, tilt: Pouring.angle, scale: 1)
let launch = Pouring.launch(scale: 1)
let bead = Sculpt.lathe([SIMD2(0, -0.003), SIMD2(0.003, 0), SIMD2(0, 0.003)],
                        segments: 8)
for step in 0 ..< 40 {
    var drop = Droplet(position: Vec3(tip.x, tip.y, 0),
                       velocity: Vec3(launch.x, launch.y, 0))
    for _ in 0 ..< step * 3 { drop.fall(1 / 240) }
    if drop.position.y > Greenhouse.soil {
        scene.append((bead.moved(by: drop.position), Channels(120, 190, 255)))
    }
}
write("pour", scene, to: folder)
