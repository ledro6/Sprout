import Foundation

// Растит готовые модели всех видов обычной детализации и пишет их
// двоичными слепками в папку из первого аргумента, рядом — сводку. Сжимает
// и раскладывает по каталогу ресурсов tool/make_stock.py.
let folder = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
var kits: [[String: Any]] = []
for preset in Preset.allCases {
    let blueprint = Blueprint.stock(preset)
    let kit = Botany.grow(blueprint, species: preset.title, detail: .standard)
    let data = kit.encoded()
    try data.write(to: folder.appendingPathComponent(
        "stock-\(preset.rawValue).kit"))
    kits.append([
        "preset": preset.rawValue,
        "triangles": kit.triangles,
        "pieces": kit.pieces.count,
        "pictures": kit.pictures.count,
        "bytes": data.count,
    ])
}
let summary: [String: Any] = ["version": Int(Kit.version), "kits": kits]
try JSONSerialization.data(withJSONObject: summary,
                           options: [.prettyPrinted, .sortedKeys])
    .write(to: folder.appendingPathComponent("manifest.json"))
