import SwiftUI
import UIKit

/// Где какая карточка на экране — по номеру растения, а не в состоянии
/// ячейки: ленивая сетка переиспользует ячейки, и волна уходила бы не от того
/// растения.
final class Cards {
    static let shared = Cards()

    private var rects: [Plant.ID: CGRect] = [:]

    private init() {}

    func put(_ rect: CGRect, for id: Plant.ID) { rects[id] = rect }

    func rect(_ id: Plant.ID) -> CGRect { rects[id] ?? .zero }
}

/// Кто сейчас в этой ячейке сетки.
///
/// Контекстное меню живёт в UIKit и держит замыкания, собранные, когда его
/// ставили. Ленивая сетка переиспользует вью под другое растение, а замыкания
/// остаются от прежнего — поливалось не то растение. Явный `id` этого не
/// лечит. Ссылка в `@State` лечит: замыкание старое, но читает из неё того,
/// кто в ячейке сейчас.
final class Tenant {
    var id: Plant.ID = ""
}

/// Меню растения по долгому нажатию — одно на главную и поиск: полить,
/// (ждущему воды — отложить на день), настройки, AR, переезд и удаление; те
/// же действия — у VoiceOver (`accessibilityAction`). Переименовать — в
/// настройках растения, расставить — продержав палец дольше меню. Удаление
/// переспрашивает, потом восемь секунд его можно вернуть с плашки, см.
/// `Bin`.
struct PlantMenu: ViewModifier {
    let id: Plant.ID

    /// Вид полки: у строки списка и предпросмотр — строкой, а не карточкой
    /// на попа.
    var look: Settings.Look = .grid

    /// В правке меню нет: долгое нажатие там сразу поднимает карточку.
    var enabled = true

    @Environment(Garden.self) private var garden

    /// Своё гашение накладывается на внешнее, а не отменяет его.
    @Environment(\.sproutHalos) private var halos

    @State private var moving = false
    @State private var roomDraft = ""

    /// Чьи настройки открыты — номер берётся у жильца в миг нажатия.
    @State private var tuning: Plant.ID?

    /// Кого смотрят в дополненной реальности — так же, у жильца.
    @State private var staging: Plant.ID?

    /// Открыто ли меню — по предпросмотру: другого признака у контекстного
    /// меню нет.
    @State private var previewing = false

    /// Ореол погашен: с меню — сразу, после меню — ещё на выдержку, пока
    /// предпросмотр возвращается на место.
    @State private var dimmed = false

    @State private var tenant = Tenant()

    /// Чужой полив меньше часа назад, о котором спрашиваем перед своим, как
    /// у капли, см. `WaterDrop`.
    @State private var asking: Watering?

    private var plant: Plant? { garden.plant(id: tenant.id) }

    func body(content: Content) -> some View {
        menu(content
            // Заселяем ячейку первым делом: замыкания меню читают отсюда.
            .onChange(of: id, initial: true) { _, now in tenant.id = now }
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) }
                action: { keep($0) }
            .environment(\.sproutHalos, halos && !dimmed))
            .confirmationDialog(asking.map { Family.again($0) } ?? "",
                                isPresented: Binding(
                                    get: { asking != nil },
                                    set: { if !$0 { asking = nil } }),
                                titleVisibility: .visible) {
                // Следом может спросить защита от перелива: лист поднимается,
                // когда этот уже ушёл.
                Button("Полить") {
                    Task { @MainActor in
                        try? await Task.sleep(for: .seconds(0.4))
                        pour()
                    }
                }
                Button("Отмена", role: .cancel) {}
            }
            .alert("Новая комната", isPresented: $moving) {
                TextField("Балкон", text: $roomDraft)
                Button("Отмена", role: .cancel) {}
                Button("Переместить") { relocate(to: roomDraft) }
            } message: {
                Text("Растение переедет туда, и комната появится в списке.")
            }
            .sheet(isPresented: Binding(get: { tuning != nil },
                                        set: { if !$0 { tuning = nil } })) {
                if let tuning {
                    PlantSettingsView(plantID: tuning).environment(garden)
                }
            }
            .fullScreenCover(isPresented: Binding(
                get: { staging != nil },
                set: { if !$0 { staging = nil } })) {
                if let staging {
                    PlantAR(plantID: staging).environment(garden)
                }
            }
            // Меню закрылось — ореол возвращается с выдержкой, см.
            // `Motion.haloBack`. Открыли снова до срока — ожидание отменяется.
            .task(id: previewing) {
                guard !previewing, dimmed else { return }
                await Motion.haloBack { dimmed = false }
            }
    }

    /// Ветвлением, а не пустым списком: пустое меню всё равно может подняться
    /// предпросмотром и спорить с перетаскиванием.
    @ViewBuilder
    private func menu(_ base: some View) -> some View {
        if enabled {
            base.contextMenu {
                Button { ask() } label: {
                    Label("Полить", systemImage: "drop.fill")
                }
                if plant?.needsWaterToday == true {
                    Button { snooze() } label: {
                        Label("Отложить на день", systemImage: "moon.zzz")
                    }
                }
                Button { tuning = tenant.id } label: {
                    Label("Настройки", systemImage: "slider.horizontal.3")
                }
                if PlantAR.available {
                    LookInAR(plant: plant) { staging = tenant.id }
                }
                // Комнаты — по номеру узла: пункты строятся при каждой сборке
                // тела. Запечатываются только нажатия, и они идут через
                // жильца.
                MoveMenu(current: garden.roomName(of: id),
                         rooms: garden.rooms.map(\.name),
                         move: relocate,
                         ask: {
                             roomDraft = ""
                             moving = true
                         })
                Button { Bin.shared.askRetire(tenant.id, in: garden) } label: {
                    Label("Растение погибло — в архив",
                          systemImage: "archivebox")
                }
                Button(role: .destructive) { toss() } label: {
                    Label("Удалить", systemImage: "trash")
                }
            } preview: {
                preview
            }
            // То же, что свайпы списка, — для VoiceOver и Переключателей.
            .accessibilityAction(named: Text("Полить")) { ask() }
            .accessibilityAction(named: Text("Отложить на день")) { snooze() }
            .accessibilityAction(named: Text("Настройки")) { tuning = tenant.id }
        } else {
            base
        }
    }

    /// Пустой замер отводим: пока меню открыто, система отвечает то нулём, то
    /// геометрией поднятой копии, и волна шла бы из угла экрана.
    private func keep(_ rect: CGRect) {
        guard !previewing, rect.width > 0, rect.height > 0 else { return }
        Cards.shared.put(rect, for: tenant.id)
    }

    private var previewWidth: CGFloat {
        guard look == .list else { return Metrics.previewCard }
        let wide = Cards.shared.rect(tenant.id).width
        return wide > 0 ? wide : Screen.width - 2 * Metrics.contentMargin
    }

    /// Полить: недавно полил кто-то из семьи — сперва вопрос, иначе сразу;
    /// влажную землю переспросит защита от перелива, см. `Overflow`.
    private func ask() {
        let id = tenant.id
        if let recent = Kinship.shared.recent(id, in: garden.log) {
            asking = recent
        } else {
            pour()
        }
    }

    private func pour() {
        let id = tenant.id
        Overflow.shared.water(id, in: garden) {
            // Волна — от карточки, а не от меню: поливают растение.
            let spot = Cards.shared.rect(id)
            Cheer.shared.now(from: spot == .zero ? Screen.middle : spot)
            Feel.water()
        }
    }

    /// «Отложить на день»: растение сутки не числится ждущим воды.
    private func snooze() {
        let id = tenant.id
        withAnimation(Motion.arrange) { garden.snooze(id) }
        Feel.pick()
    }

    private func toss() {
        let who = tenant.id
        Bin.shared.ask(who, from: Cards.shared.rect(who), in: garden)
    }

    private func relocate(to room: String) {
        let who = tenant.id
        withAnimation(Motion.appear) { garden.relocate(who, to: room) }
    }

    /// Свой предпросмотр: системный снимок унёс бы ореол. Он же сообщает, что
    /// меню закрылось, — тогда ореол возвращается. Вид — как на полке:
    /// строка списка поднимается строкой, лёжа, а не встаёт карточкой.
    @ViewBuilder
    private var preview: some View {
        if let plant {
            Group {
                switch look {
                case .grid: PlantCard(plant: plant)
                case .list: PlantRow(plant: plant)
                }
            }
                // Ширина числом: предпросмотру размера не предлагают, и
                // карточка свернулась бы. Строка — шириной своей строки.
                .frame(width: previewWidth)
                .environment(\.sproutHalos, false)
                .onAppear {
                    previewing = true
                    dimmed = true
                }
                .onDisappear { previewing = false }
        }
    }
}

/// «Посмотреть в AR» в меню карточки. Модель есть всегда — готовая модель
/// вида; пока собирается своя по снимку, под пунктом её проценты. Своим
/// вью: доли меняются на каждый процент, и перерисовываться с ними должен
/// только пункт, а не меню каждой карточки.
private struct LookInAR: View {
    let plant: Plant?
    let open: () -> Void

    var body: some View {
        let share = plant.flatMap { Bench.shared.share($0) }
        Button(action: open) {
            if let share, share < 1 {
                Label {
                    Text("Посмотреть в AR")
                    Text(Bench.preparing(share))
                } icon: {
                    Image(systemName: "arkit")
                }
            } else {
                Label("Посмотреть в AR", systemImage: "arkit")
            }
        }
    }
}
