package com.ledro6.sprout.model

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import kotlinx.serialization.builtins.ListSerializer
import kotlinx.serialization.json.Json

/** Позванные соперники — в настройках: это не данные сада. */
class Friends(private val store: Prefs) {
    var rivals: List<Rival> by mutableStateOf(emptyList())
        private set

    init {
        val saved = store.string(KEY)?.let {
            runCatching { json.decodeFromString(ListSerializer(Rival.serializer()), it) }.getOrNull()
        }
        if (saved != null) rivals = ranked(saved)
    }

    /** Свой код в соперники не берём: строка хозяина в таблице уже есть. */
    fun take(text: String, mine: String): Rival? {
        val rival = Rival.read(text) ?: return null
        if (rival.id == mine.lowercase()) return null
        add(rival)
        return rival
    }

    /** Тот, кто уже в таблице, заменяется целиком. */
    fun add(rival: Rival) {
        rivals = ranked(rivals.filter { it.id != rival.id } + rival)
        save()
    }

    fun remove(id: String) {
        rivals = rivals.filter { it.id != id }
        save()
    }

    fun clear() {
        rivals = emptyList()
        save()
    }

    private fun save() {
        store.put(KEY, json.encodeToString(ListSerializer(Rival.serializer()), rivals))
    }

    companion object {
        private const val KEY = "rivals"
        private val json = Json { ignoreUnknownKeys = true }

        /** При равенстве — по кличке, чтобы строки не перескакивали. */
        fun ranked(list: List<Rival>): List<Rival> =
            list.sortedWith(compareByDescending<Rival> { it.total }.thenBy { it.name })
    }
}

/** Что искали раньше. Удобство, а не данные хозяина. */
class Recents(private val store: Prefs) {
    var queries: List<String> by mutableStateOf(store.strings(KEY) ?: emptyList())
        private set

    /** Зовётся, когда запросом воспользовались, а не на каждую букву. */
    fun remember(query: String) {
        val trimmed = query.trim()
        if (trimmed.length < SHORTEST) return
        val next = queries.filter { !it.equals(trimmed, ignoreCase = true) }
        queries = (listOf(trimmed) + next).take(KEEP)
        save()
    }

    fun forget(query: String) {
        queries = queries.filter { !it.equals(query, ignoreCase = true) }
        save()
    }

    fun clear() {
        queries = emptyList()
        save()
    }

    private fun save() = store.put(KEY, queries)

    companion object {
        const val KEEP = 6
        const val SHORTEST = 2
        private const val KEY = "recentSearches"
    }
}
