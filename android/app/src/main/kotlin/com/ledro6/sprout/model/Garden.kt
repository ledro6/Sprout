package com.ledro6.sprout.model

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import java.util.UUID
import kotlin.math.max
import kotlin.math.min

/** Где лежит сад и снимки. На телефоне — файлы приложения, в прогоне — память. */
interface Shelf {
    fun read(): GardenState?

    /** Отвечает, записалось ли; не записалось — сад в памяти цел. */
    fun write(state: GardenState): Boolean

    /** Снимок растения больше не нужен. */
    fun drop(shot: String)
}

/**
 * Живой сад: комнаты, растения, время и файл. Влажность сохнет по часам, а
 * не по числу тактов: такт может задержаться. Меняется только с главного
 * потока — экраны, виджет и уведомление зовут его оттуда.
 */
class Garden(
    private val shelf: Shelf,
    private val clock: () -> Long = System::currentTimeMillis,
) {
    var owner: String by mutableStateOf(Seed.OWNER)
        private set
    var rooms: List<Room> by mutableStateOf(emptyList())
        private set
    var log: List<Watering> by mutableStateOf(emptyList())
        private set

    /** Счётчик изменений состава сада: клички, растения, комнаты. */
    var roster: Int by mutableIntStateOf(0)
        private set

    var since: Long by mutableLongStateOf(0L)
        private set

    private var lastTick: Long = clock()

    /** Миг последнего такта — планетарий досчитывает от него. */
    val ticked: Long get() = lastTick

    /** Метка слепка в памяти: другая в файле — его записал кто-то ещё. */
    private var written: String? = null

    /** После записи — виджету пора перерисоваться. */
    var saved: (() -> Unit)? = null

    init {
        // Битый файл — тоже «нет файла»: лучше макетный сад, чем не запуститься.
        val state = runCatching { shelf.read() }.getOrNull() ?: Seed.state(clock())
        take(state)
        lastTick = clock()
    }

    private fun take(state: GardenState) {
        owner = state.owner
        rooms = state.rooms
        log = state.log
        since = state.since
        written = state.stamp
    }

    /** Файл поменяли без нас — берём его. */
    fun reload() {
        val state = runCatching { shelf.read() }.getOrNull() ?: return
        if (state.stamp == written) return
        take(state)
        lastTick = clock()
        roster += 1
    }

    // Время

    fun advance(now: Long = clock()) {
        val elapsed = now - lastTick
        lastTick = now
        if (elapsed <= 0) return
        val days = elapsed / 1000.0 * SPEED / 86_400
        rooms = rooms.map { room -> room.copy(plants = room.plants.map { it.dried(days) }) }
    }

    // Что где растёт

    /** Пустое имя — «ещё не назвался». */
    val signed: String get() = owner.ifEmpty { Seed.stranger }

    val plantCount: Int get() = rooms.sumOf { it.plants.size }

    val plants: List<Plant> get() = rooms.flatMap { it.plants }

    fun plant(id: String): Plant? {
        for (room in rooms) room.plants.firstOrNull { it.id == id }?.let { return it }
        return null
    }

    fun roomName(id: String): String? = rooms.firstOrNull { room -> room.plants.any { it.id == id } }?.name

    fun search(query: String): List<Plant> = Seed.search(query, rooms)

    fun score(now: Long = clock(), days: Days = Days.current): Score = Score.of(log, rooms, now, days)

    // Что с ними делают

    /** Отвечает, что было до полива, — для отмены. */
    fun water(id: String, at: Long = clock()): Pour? {
        val before = plant(id) ?: return null
        log = log + Watering(id, at, before.moisture)
        change(id) { it.copy(moisture = 1.0) }
        return Pour(id, before.name, before.moisture, at)
    }

    /** Запись уходит из журнала, влажность — на прежнюю, за вычетом высохшего. */
    fun unwater(pour: Pour) {
        val entry = Watering(pour.plant, pour.at)
        val index = log.indexOfLast { it.same(entry) }
        if (index >= 0) log = log.filterIndexed { i, _ -> i != index }
        if (plant(pour.plant) == null) {
            save()
            return
        }
        change(pour.plant) { it.copy(moisture = max(0.0, pour.moisture - (1 - it.moisture))) }
    }

    /** Ошибочная запись из истории. Влажность не трогаем. */
    fun forget(entry: Watering) {
        val index = log.indexOfLast { it.same(entry) }
        if (index < 0) return
        log = log.filterIndexed { i, _ -> i != index }
        save()
    }

    /** Нет такой комнаты — заводим и её. */
    fun add(plant: Plant, room: String) {
        val index = rooms.indexOfFirst { it.name == room }
        rooms = if (index >= 0) {
            rooms.mapIndexed { i, r -> if (i == index) r.copy(plants = r.plants + plant) else r }
        } else {
            rooms + Room(room, listOf(plant))
        }
        roster += 1
        save()
    }

    /** Имя хозяина и день начала остаются: стирают сад, а не себя. */
    fun erase() {
        for (shot in plants.mapNotNull { it.shot }) shelf.drop(shot)
        rooms = emptyList()
        log = emptyList()
        roster += 1
        save()
    }

    fun renameOwner(name: String) {
        val trimmed = name.trim()
        if (trimmed.isEmpty()) return
        owner = trimmed
        save()
    }

    /** Пустое имя не сохраняем: безымянная карточка — поломка. */
    fun rename(id: String, name: String) {
        val trimmed = name.trim()
        if (trimmed.isEmpty()) return
        change(id) { it.copy(name = trimmed) }
        roster += 1
    }

    /** Настройки растения; срок пересчитывает влажность, см. `Plant.retimed`. */
    fun tune(id: String, name: String, species: String, dryingDays: Double) {
        val old = plant(id) ?: return
        val nickname = name.trim()
        val kind = species.trim()
        change(id) { plant ->
            var next = plant
            if (nickname.isNotEmpty()) next = next.copy(name = nickname)
            if (kind.isNotEmpty() && kind != next.species) {
                next = next.copy(species = kind, plan = next.plan?.copy(preset = Preset.of(kind)))
            }
            next.retimed(dryingDays)
        }
        if (nickname.isNotEmpty() && nickname != old.name) roster += 1
    }

    /** Своя модель по снимку: черты — в чертёж. */
    fun imagine(id: String, traits: Traits, kind: Preset? = null) {
        val plant = plant(id) ?: return
        val preset = Preset.known(plant.species) ?: kind ?: Preset.of(plant.species)
        change(id) { it.copy(plan = Blueprint(preset, traits, id)) }
    }

    /** Назад к готовой модели вида. */
    fun unmodel(id: String) {
        val plant = plant(id) ?: return
        if (plant.plan == null) return
        change(id) { it.copy(plan = null) }
    }

    fun feed(id: String) {
        if (plant(id) == null) return
        change(id) { it.copy(care = it.tending.copy(sinceFed = 0.0)) }
    }

    /** Пересадили: свежая земля кормит сама — счёт подкормки тоже заново. */
    fun repot(id: String) {
        if (plant(id) == null) return
        change(id) { it.copy(care = it.tending.copy(sinceRepot = 0.0, sinceFed = 0.0)) }
    }

    fun tend(id: String, feedEvery: Double?, repotEvery: Double?) {
        val old = plant(id) ?: return
        val tended = old.tending.copy(feedEvery = feedEvery, repotEvery = repotEvery)
        if (tended == old.care) return
        change(id) { it.copy(care = tended) }
    }

    fun quiet(id: String, days: Double) {
        if (plant(id) == null) return
        change(id) { it.copy(quiet = days) }
    }

    /** Пустая заметка — её нет. */
    fun note(id: String, text: String) {
        val trimmed = text.trim()
        val kept = trimmed.ifEmpty { null }
        val plant = plant(id) ?: return
        if (plant.note == kept) return
        change(id) { it.copy(note = kept) }
    }

    /** Растение занимает место другого: вперёд — встаёт за ним, назад — перед. */
    fun move(id: String, target: String) {
        if (id == target) return
        for ((roomIndex, room) in rooms.withIndex()) {
            val from = room.plants.indexOfFirst { it.id == id }
            if (from < 0) continue
            val to = room.plants.indexOfFirst { it.id == target }
            if (to < 0) return
            val list = room.plants.toMutableList()
            val plant = list.removeAt(from)
            list.add(to, plant)
            rooms = rooms.mapIndexed { i, r -> if (i == roomIndex) r.copy(plants = list) else r }
            save()
            return
        }
    }

    /** Комната встаёт в порядке с экрана; кого нет в списке — в хвосте. */
    fun line(ids: List<String>) {
        val first = ids.firstOrNull() ?: return
        val roomIndex = rooms.indexOfFirst { room -> room.plants.any { it.id == first } }
        if (roomIndex < 0) return
        val plants = rooms[roomIndex].plants
        val rank = HashMap<String, Int>()
        for ((place, id) in ids.withIndex()) if (id !in rank) rank[id] = place
        val lined = plants.withIndex()
            .sortedBy { rank[it.value.id] ?: (ids.size + it.index) }
            .map { it.value }
        if (lined.map { it.id } == plants.map { it.id }) return
        rooms = rooms.mapIndexed { i, r -> if (i == roomIndex) r.copy(plants = lined) else r }
        save()
    }

    /** Убрать, запомнив откуда. Снимок остаётся на диске до конца отсчёта. */
    fun remove(id: String): Removal? {
        for ((roomIndex, room) in rooms.withIndex()) {
            val index = room.plants.indexOfFirst { it.id == id }
            if (index < 0) continue
            val plant = room.plants[index]
            rooms = rooms.mapIndexed { i, r ->
                if (i == roomIndex) r.copy(plants = r.plants.filterIndexed { j, _ -> j != index }) else r
            }
            roster += 1
            save()
            return Removal(plant, room.name, roomIndex, index)
        }
        return null
    }

    /** Комнату за отсчёт могли удалить — тогда она заводится там, где стояла. */
    fun putBack(gone: Removal) {
        if (plant(gone.plant.id) != null) return
        val roomIndex = rooms.indexOfFirst { it.name == gone.room }
        rooms = if (roomIndex >= 0) {
            rooms.mapIndexed { i, r ->
                if (i != roomIndex) r else {
                    val list = r.plants.toMutableList()
                    list.add(min(gone.index, list.size), gone.plant)
                    r.copy(plants = list)
                }
            }
        } else {
            val list = rooms.toMutableList()
            list.add(min(gone.roomIndex, list.size), Room(gone.room, listOf(gone.plant)))
            list
        }
        roster += 1
        save()
    }

    /** Снимок убранного насовсем растения. */
    fun dropShot(shot: String?) {
        if (shot != null && plants.none { it.shot == shot }) shelf.drop(shot)
    }

    // Комнаты

    private fun taken(name: String, except: String? = null): Boolean =
        rooms.any { it.name != except && it.name.equals(name, ignoreCase = true) }

    fun addRoom(name: String): Boolean {
        val trimmed = name.trim()
        if (trimmed.isEmpty() || taken(trimmed)) return false
        rooms = rooms + Room(trimmed, emptyList())
        roster += 1
        save()
        return true
    }

    fun renameRoom(old: String, name: String): Boolean {
        val trimmed = name.trim()
        val index = rooms.indexOfFirst { it.name == old }
        if (trimmed.isEmpty() || index < 0) return false
        if (trimmed == old) return true
        if (taken(trimmed, except = old)) return false
        rooms = rooms.mapIndexed { i, r -> if (i == index) r.copy(name = trimmed) else r }
        roster += 1
        save()
        return true
    }

    /** Комната переезжает с места `from` на место `to` — как при перетаскивании. */
    fun moveRoom(from: Int, to: Int) {
        if (from !in rooms.indices || to !in rooms.indices || from == to) return
        val list = rooms.toMutableList()
        val room = list.removeAt(from)
        list.add(to, room)
        rooms = list
        save()
    }

    fun deleteRoom(name: String) {
        val index = rooms.indexOfFirst { it.name == name }
        if (index < 0) return
        val gone = rooms[index]
        rooms = rooms.filterIndexed { i, _ -> i != index }
        roster += 1
        save()
        for (shot in gone.plants.mapNotNull { it.shot }) shelf.drop(shot)
    }

    /** В конец новой комнаты: новосёла видно сразу. */
    fun relocate(id: String, room: String) {
        val target = room.trim()
        if (target.isEmpty() || roomName(id) == target) return
        val gone = remove(id) ?: return
        add(gone.plant, target)
    }

    private fun change(id: String, edit: (Plant) -> Plant) {
        for ((roomIndex, room) in rooms.withIndex()) {
            val index = room.plants.indexOfFirst { it.id == id }
            if (index < 0) continue
            val plants = room.plants.toMutableList()
            plants[index] = edit(plants[index])
            rooms = rooms.mapIndexed { i, r -> if (i == roomIndex) r.copy(plants = plants) else r }
            save()
            return
        }
    }

    // Файл

    val state: GardenState
        get() = GardenState(owner, rooms, clock(), log, since, written, Season.stretch)

    /** На действиях хозяина и при уходе в фон, но не на каждом такте часов. */
    fun save() {
        val snapshot = state.copy(stamp = UUID.randomUUID().toString())
        if (runCatching { shelf.write(snapshot) }.getOrDefault(false)) {
            written = snapshot.stamp
            saved?.invoke()
        }
    }

    companion object {
        /** Во сколько раз время сада быстрее настоящего: сутки за восемь часов. */
        const val SPEED = 3.0
    }
}
