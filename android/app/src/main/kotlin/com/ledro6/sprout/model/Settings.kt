package com.ledro6.sprout.model

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import java.text.Collator
import kotlin.properties.ReadWriteProperty
import kotlin.reflect.KProperty

/**
 * Настройки приложения — в `Prefs`: это несколько чисел, нужных до первого
 * экрана, а не данные сада. Ключи — те же, что на iOS.
 */
class Settings(private val store: Prefs) {
    enum class Theme(val raw: String) {
        SYSTEM("system"), LIGHT("light"), DARK("dark");

        val title: String
            get() = when (this) {
                SYSTEM -> Lang.text("Как в системе")
                LIGHT -> Lang.text("Светлая")
                DARK -> Lang.text("Тёмная")
            }

        /** Для ряда из трёх кнопок, где «Как в системе» не помещается. */
        val short: String
            get() = when (this) {
                SYSTEM -> Lang.text("Система")
                LIGHT -> Lang.text("Светлая")
                DARK -> Lang.text("Тёмная")
            }
    }

    enum class Look(val raw: String) {
        GRID("grid"), LIST("list");

        val title: String
            get() = when (this) {
                GRID -> Lang.text("Плиткой")
                LIST -> Lang.text("Списком")
            }
    }

    /** Порядок растений. Сортировки ручной порядок не трогают. */
    enum class Order(val raw: String) {
        MANUAL("manual"), THIRSTY("thirsty"), NAME("name"), NEWEST("newest");

        val title: String
            get() = when (this) {
                MANUAL -> Lang.text("Вручную")
                THIRSTY -> Lang.text("Сначала сухие")
                NAME -> Lang.text("По имени")
                NEWEST -> Lang.text("Сначала новые")
            }

        /**
         * Равные остаются в ручном порядке. «Сначала сухие» — по дням до
         * полива, а не по процентам: 20% у папоротника — день, у кактуса — две
         * недели.
         */
        fun arrange(plants: List<Plant>): List<Plant> = when (this) {
            MANUAL -> plants
            THIRSTY -> plants.withIndex()
                .sortedWith(compareBy<IndexedValue<Plant>> { it.value.moisture * it.value.dryingDays }.thenBy { it.index })
                .map { it.value }
            NAME -> {
                val collator = Collator.getInstance(Lang.locale).apply { strength = Collator.SECONDARY }
                plants.withIndex()
                    .sortedWith { a, b ->
                        val order = natural(a.value.name, b.value.name, collator)
                        if (order != 0) order else a.index.compareTo(b.index)
                    }
                    .map { it.value }
            }
            NEWEST -> plants.withIndex()
                .sortedWith(compareByDescending<IndexedValue<Plant>> { it.value.addedOn.number }.thenBy { it.index })
                .map { it.value }
        }

        companion object {
            /** Как `localizedStandardCompare`: «Фикус 2» раньше «Фикус 10». */
            fun natural(a: String, b: String, collator: Collator): Int {
                val left = chunks(a)
                val right = chunks(b)
                for (i in 0 until minOf(left.size, right.size)) {
                    val x = left[i]
                    val y = right[i]
                    val order = if (x[0].isDigit() && y[0].isDigit()) {
                        val nx = x.trimStart('0')
                        val ny = y.trimStart('0')
                        if (nx.length != ny.length) nx.length.compareTo(ny.length) else nx.compareTo(ny)
                    } else {
                        collator.compare(x, y)
                    }
                    if (order != 0) return order
                }
                return left.size.compareTo(right.size)
            }

            private fun chunks(text: String): List<String> {
                val out = mutableListOf<String>()
                val part = StringBuilder()
                for (c in text) {
                    if (part.isNotEmpty() && part[0].isDigit() != c.isDigit()) {
                        out.add(part.toString())
                        part.clear()
                    }
                    part.append(c)
                }
                if (part.isNotEmpty()) out.add(part.toString())
                return out
            }
        }
    }

    var theme: Theme by Kept(Theme.entries.firstOrNull { it.raw == store.string(Key.THEME) } ?: Theme.SYSTEM) {
        store.put(Key.THEME, it.raw)
    }

    /** Вид и порядок — одни на главную и поиск. */
    var look: Look by Kept(Look.entries.firstOrNull { it.raw == store.string(Key.LOOK) } ?: Look.GRID) {
        store.put(Key.LOOK, it.raw)
    }

    var order: Order by Kept(Order.entries.firstOrNull { it.raw == store.string(Key.ORDER) } ?: Order.MANUAL) {
        store.put(Key.ORDER, it.raw)
    }

    var patternTint: Tint by Kept(tint(Key.PATTERN_TINT) ?: Tint.defaultPattern) {
        store.put(Key.PATTERN_TINT, it.ordinal)
    }

    var waveTint: Tint by Kept(tint(Key.WAVE_TINT) ?: Tint.defaultWave) {
        store.put(Key.WAVE_TINT, it.ordinal)
    }

    var avatarTint: Tint by Kept(tint(Key.AVATAR_TINT) ?: Tint.defaultAvatar) {
        store.put(Key.AVATAR_TINT, it.ordinal)
    }

    /** Фото хозяина — имя снимка; нет — кружок с буквой. */
    var avatarShot: String? by Kept(store.string(Key.AVATAR_SHOT)) { store.put(Key.AVATAR_SHOT, it) }

    /** Набор фигурок узора; ставится через `toggle` — последнюю не выключить. */
    var shapes: Set<Int> by mutableStateOf(readShapes())
        private set

    val chosen: List<Int> get() = shapes.sorted()

    fun toggle(shape: Int): Boolean {
        if (shape !in 0 until SHAPE_COUNT) return false
        val next = if (shape in shapes) {
            if (shapes.size <= 1) return false
            shapes - shape
        } else {
            shapes + shape
        }
        shapes = next
        store.put(Key.SHAPES, next.fold(0) { mask, s -> mask or (1 shl s) })
        return true
    }

    private fun readShapes(): Set<Int> {
        val mask = store.int(Key.SHAPES)
        if (mask != 0) {
            val set = (0 until SHAPE_COUNT).filter { mask and (1 shl it) != 0 }.toSet()
            if (set.isNotEmpty()) return set
        }
        return DEFAULT_SHAPES
    }

    /** Сила отклика в руке, 0…1; ноль — отклика нет. */
    var hapticStrength: Double by Kept(
        if (store.has(Key.STRENGTH)) store.double(Key.STRENGTH).coerceIn(0.0, 1.0) else 1.0,
        clean = { it.coerceIn(0.0, 1.0) },
    ) { store.put(Key.STRENGTH, it) }

    val haptics: Boolean get() = hapticStrength > 0

    var sounds: Boolean by Kept(!store.bool(Key.MUTED)) { store.put(Key.MUTED, !it) }

    /** Узор за наклоном. */
    var parallax: Boolean by Kept(!store.bool(Key.STILL_PATTERN)) { store.put(Key.STILL_PATTERN, !it) }

    /** Фигурки плывут порознь. */
    var sway: Boolean by Kept(!store.bool(Key.STIFF_SHAPES)) { store.put(Key.STIFF_SHAPES, !it) }

    /** Срок полива длиннее зимой и короче летом. */
    var seasons: Boolean by Kept(!store.bool(Key.FLAT_YEAR)) { store.put(Key.FLAT_YEAR, !it) }

    var reminders: Boolean by Kept(store.bool(Key.REMINDERS)) { store.put(Key.REMINDERS, it) }

    /** Порог напоминания — любым целым процентом 1…99. */
    var threshold: Double by Kept(threshold(store.double(Key.THRESHOLD)), clean = ::threshold) {
        store.put(Key.THRESHOLD, it)
    }

    /** Цвета обоев телефона вместо своих — только Android 12 и новее. */
    var dynamicColor: Boolean by Kept(store.bool(Key.DYNAMIC)) { store.put(Key.DYNAMIC, it) }

    /** Замок на приложении — отпечаток, лицо или код телефона. */
    var lock: Boolean by Kept(store.bool(Key.LOCK)) { store.put(Key.LOCK, it) }

    var toured: Boolean by Kept(store.bool(Key.TOURED)) { store.put(Key.TOURED, it) }

    /** Экраны, чьи подсказки уже показаны. */
    var walked: Set<String> by mutableStateOf((store.strings(Key.WALKED) ?: emptyList()).toSet())
        private set

    fun seen(walk: Walk): Boolean = walk.raw in walked

    fun mark(walk: Walk) {
        if (walk.raw in walked) return
        walked = walked + walk.raw
        store.put(Key.WALKED, walked.sorted())
    }

    fun rewalk() {
        walked = emptySet()
        store.put(Key.WALKED, emptyList())
    }

    /** Который по счёту запуск: подсказки сами показываются только в первый. */
    var launches: Int by mutableIntStateOf(maxOf(store.int(Key.LAUNCHES), if (store.bool(Key.TOURED)) 1 else 0))
        private set

    val firstRun: Boolean get() = launches <= 1

    fun launched() {
        launches += 1
        store.put(Key.LAUNCHES, launches)
    }

    private fun tint(key: String): Tint? = if (store.has(key)) Tint.of(store.int(key)) else null

    private object Key {
        const val THEME = "theme"
        const val LOOK = "plantLook"
        const val ORDER = "plantOrder"
        const val SHAPES = "patternShapes"
        const val REMINDERS = "reminders"
        const val THRESHOLD = "remindThreshold"
        const val PATTERN_TINT = "patternTint"
        const val WAVE_TINT = "waveTint"
        const val AVATAR_TINT = "avatarTint"
        const val AVATAR_SHOT = "avatarShot"
        const val STRENGTH = "hapticStrength"
        const val MUTED = "mutedSounds"
        const val STILL_PATTERN = "stillPattern"
        const val STIFF_SHAPES = "stiffShapes"
        const val FLAT_YEAR = "ignoreSeasons"
        const val TOURED = "toured"
        const val WALKED = "walkedScreens"
        const val LAUNCHES = "launches"
        const val DYNAMIC = "dynamicColor"
        const val LOCK = "lock"
    }

    /** Настройка в памяти экранов и сразу на диске. */
    private class Kept<T>(
        initial: T,
        private val clean: (T) -> T = { it },
        private val save: (T) -> Unit,
    ) : ReadWriteProperty<Any?, T> {
        private val state = mutableStateOf(initial)

        override fun getValue(thisRef: Any?, property: KProperty<*>): T = state.value

        override fun setValue(thisRef: Any?, property: KProperty<*>, value: T) {
            val kept = clean(value)
            state.value = kept
            save(kept)
        }
    }

    companion object {
        const val SHAPE_COUNT = 4

        fun threshold(value: Double): Double {
            val level = (value * 100).roundedInt()
            return if (level in THRESHOLDS) level / 100.0 else DEFAULT_THRESHOLD
        }
        val DEFAULT_SHAPES = setOf(0, 1)
        val THRESHOLDS = 1..99
        const val DEFAULT_THRESHOLD = 0.2
    }
}
