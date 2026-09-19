import Foundation
import Observation

/// Что искали раньше.
///
/// Нужны затем, что искать в квартире обычно приходится одно и то же:
/// имена у растений свои, набирать их каждый раз заново — работа на
/// пустом месте. Пустой экран поиска без них тоже пуст зря: на нём есть
/// место, и лучше ему что-то предлагать.
///
/// В `UserDefaults`: несколько строк, которые надо помнить между
/// запусками. Сад — данные хозяина, ему место в Documents; это же —
/// удобство, и потерять его не жалко.
@Observable
final class Recents {
    static let shared = Recents()

    /// От свежего к старому — так их и показывают.
    private(set) var queries: [String] = []

    /// Сколько помним. Больше на экран всё равно не поставить, а длинный
    /// список перестаёт быть подсказкой и становится историей, которую
    /// никто не просил.
    static let keep = 6

    /// Короче этого не запоминаем: по одной букве находится половина
    /// квартиры, и такой запрос ничего не значит.
    static let shortest = 2

    @ObservationIgnored private let store: UserDefaults
    private static let key = "recentSearches"

    init(store: UserDefaults = .standard) {
        self.store = store
        queries = store.stringArray(forKey: Self.key) ?? []
    }

    /// Запомнить запрос.
    ///
    /// Зовётся не на каждую букву, а когда запросом воспользовались —
    /// нажали «Найти» или открыли найденное. Иначе в списке оседали бы
    /// огрызки слов, набранные по дороге к нужному.
    ///
    /// Повтор не заводит второй строки, а поднимает прежнюю наверх — и без
    /// оглядки на регистр: «Баксик» и «баксик» это один запрос.
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
