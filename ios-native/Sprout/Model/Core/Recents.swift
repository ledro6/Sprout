import Foundation
import Observation

/// Что искали раньше. В `UserDefaults`, а не рядом с садом: это удобство, а
/// не данные хозяина.
@Observable
final class Recents {
    static let shared = Recents()

    private(set) var queries: [String] = []

    static let keep = 6

    /// Короче не запоминаем: по одной букве находится полквартиры.
    static let shortest = 2

    @ObservationIgnored private let store: UserDefaults
    private static let key = "recentSearches"

    init(store: UserDefaults = .standard) {
        self.store = store
        queries = store.stringArray(forKey: Self.key) ?? []
    }

    /// Зовётся, когда запросом воспользовались, а не на каждую букву — иначе
    /// оседали бы огрызки слов. Повтор без оглядки на регистр поднимает
    /// прежнюю строку наверх.
    func remember(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= Self.shortest else { return }
        var next = queries.filter { !$0.caseInsensitiveEquals(trimmed) }
        next.insert(trimmed, at: 0)
        queries = Array(next.prefix(Self.keep))
        save()
    }

    func forget(_ query: String) {
        queries.removeAll { $0.caseInsensitiveEquals(query) }
        save()
    }

    func clear() {
        queries = []
        save()
    }

    private func save() { store.set(queries, forKey: Self.key) }
}

private extension String {
    func caseInsensitiveEquals(_ other: String) -> Bool {
        compare(other, options: .caseInsensitive) == .orderedSame
    }
}
