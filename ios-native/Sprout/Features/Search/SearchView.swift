import SwiftUI

/// Поиск. Поле — системное: `searchable` висит внутри стека навигации, иначе
/// система ставит поле по-старому, сверху, а не внизу у панели.
struct SearchView: View {
    @Environment(Garden.self) private var garden

    @State private var query = ""

    private let recents = Recents.shared

    @Namespace private var cardZoom

    @State private var path: [Plant.ID] = []
    @State private var opening: Plant.ID?

    private var asked: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var results: [Plant] {
        Settings.shared.order.arrange(garden.search(query))
    }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    SproutHead("Поиск", walk: .search)
                    Group {
                        if asked.isEmpty {
                            history
                        } else if results.isEmpty {
                            nothing
                        } else {
                            grid
                        }
                    }
                    .hintSpot(.searchBoard)
                }
            }
            .background { SproutBackground() }
            // Строки комнаты здесь нет — верх держит подложка под вырезом.
            .sproutNotchCover()
            .walk(.search)
            .navigationDestination(for: Plant.ID.self) { id in
                PlantView(plantID: id)
                    .navigationTransition(.zoom(sourceID: id, in: cardZoom))
            }
            .searchable(text: $query, prompt: "Найти растение")
            .searchToolbarBehavior(.minimize)
            // Подстановку запроса делает `searchCompletion`.
            .searchSuggestions {
                ForEach(recents.queries, id: \.self) { past in
                    Label(past, systemImage: "clock.arrow.circlepath")
                        .searchCompletion(past)
                }
            }
            .onSubmit(of: .search) { recents.remember(asked) }
        }
        // Ореол вернувшейся карточки — с выдержкой, как на главной.
        .task(id: path.isEmpty) {
            guard path.isEmpty, opening != nil else { return }
            await Motion.haloBack { opening = nil }
        }
    }

    /// Прежние запросы — и плашкой на самом экране: подсказка под полем
    /// видна, только пока оно раскрыто.
    @ViewBuilder
    private var history: some View {
        if recents.queries.isEmpty {
            hint(Lang.text("Найдётся по кличке или по виду — «Баксик», «Монстера»."),
                 icon: "magnifyingglass")
        } else {
            VStack(alignment: .leading, spacing: 14) {
                SproutGroup("Недавно искали") {
                    ForEach(Array(recents.queries.enumerated()),
                            id: \.element) { item in
                        if item.offset > 0 { SproutDivider() }
                        Button { again(item.element) } label: {
                            SproutLink(item.element,
                                       icon: "clock.arrow.circlepath")
                        }
                        .buttonStyle(.plain)
                        .transition(.blurReplace)
                        .contextMenu {
                            Button(role: .destructive) {
                                withAnimation(Motion.pill) {
                                    recents.forget(item.element)
                                }
                            } label: {
                                Label("Забыть", systemImage: "xmark")
                            }
                        }
                    }
                }
                .sproutRide()
                .hintSpot(.searchRecents)

                Button("Очистить") {
                    withAnimation(Motion.pill) { recents.clear() }
                }
                .buttonStyle(.glass)
                .font(Typography.settingNote)
            }
            .padding(.horizontal, Metrics.contentMargin)
            .padding(.top, 8)
            .padding(.bottom, 28)
        }
    }

    private var nothing: some View {
        hint(Lang.format("По запросу «%@» в квартире ничего не растёт.", asked),
             icon: "leaf")
    }

    private func hint(_ text: String, icon: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 30, weight: .regular))
                .foregroundStyle(.tertiary)
            Text(text)
                .font(Typography.settingNote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 48)
        .padding(.top, 140)
    }

    private var grid: some View {
        Shelf(Settings.shared.look) {
            ForEach(results) { plant in
                PlantTile(plant: plant, look: Settings.shared.look,
                          opening: opening, zoom: cardZoom, open: show)
                    .id(plant.id)
            }
        }
        .padding(.horizontal, Metrics.contentMargin)
        .padding(.top, 14)
        .padding(.bottom, 28)
    }

    private func again(_ past: String) {
        query = past
        recents.remember(past)
    }

    /// Гашение ореола и переход — разными проходами, см. главную. Нашли и
    /// открыли — запрос был нужен.
    private func show(_ id: Plant.ID) {
        recents.remember(asked)
        opening = id
        Task { @MainActor in path.append(id) }
    }
}
