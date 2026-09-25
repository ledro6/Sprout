import Foundation

extension Wrist {
    /// Сад — в посылку для часов: от самого сухого. Только на телефоне: у
    /// часов своего сада нет.
    static func of(_ rooms: [Room], at moment: Date = Date()) -> Wrist {
        var pots: [Pot] = []
        for room in rooms {
            for plant in room.plants {
                pots.append(Pot(id: plant.id, name: plant.name, room: room.name,
                                moisture: plant.moisture, period: plant.period))
            }
        }
        pots.sort { $0.moisture < $1.moisture }
        return Wrist(pots: pots, sent: moment)
    }
}
