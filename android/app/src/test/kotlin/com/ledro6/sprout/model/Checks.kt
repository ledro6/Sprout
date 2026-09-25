package com.ledro6.sprout.model

import android.content.Context
import android.content.res.Configuration
import androidx.test.core.app.ApplicationProvider
import com.ledro6.sprout.platform.Platform
import kotlinx.serialization.json.Json
import org.junit.Assert.fail
import java.util.Locale

/**
 * Проверки модели — тем же словом, что на iOS: каждая с подписью, и в конце
 * список всего, что не сошлось, а не первое же падение.
 */
class Checks {
    private val failures = mutableListOf<String>()

    fun check(got: String, want: String, what: String) {
        if (got != want) failures.add("$what: получили «$got», ждали «$want»")
    }

    fun check(got: Boolean, what: String) {
        if (!got) failures.add(what)
    }

    fun done() {
        if (failures.isNotEmpty()) fail("не сошлось ${failures.size}:\n" + failures.joinToString("\n"))
    }
}

fun checks(block: Checks.() -> Unit) {
    val checks = Checks()
    checks.block()
    checks.done()
}

/** До сотых — чтобы не спорить с последним битом. */
fun round2(value: Double): String = String.format(Locale.ROOT, "%.2f", (value * 100).rounded() / 100)

fun plant(moisture: Double, dryingDays: Double = 7.0) =
    Plant("x", "x", "x", moisture, dryingDays, Day(2024, 1, 1))

fun plantNamed(name: String, moisture: Double, dryingDays: Double) =
    Plant(name, name, "x", moisture, dryingDays, Day(2024, 1, 1))

/** Сад в памяти, но через JSON — как в файле. */
class MemoryShelf(private var text: String? = null) : Shelf {
    val dropped = mutableListOf<String>()
    var writes = 0

    override fun read(): GardenState? = text?.let { json.decodeFromString(GardenState.serializer(), it) }

    override fun write(state: GardenState): Boolean {
        text = json.encodeToString(GardenState.serializer(), state)
        writes += 1
        return true
    }

    override fun drop(shot: String) {
        dropped.add(shot)
    }

    companion object {
        val json = Json { ignoreUnknownKeys = true }
    }
}

/** Часы сада, которые двигает проверка. */
class Hands(var now: Long = 1_790_000_000_000L) {
    fun move(seconds: Double) {
        now += (seconds * 1000).toLong()
    }
}

fun garden(hands: Hands = Hands(), shelf: MemoryShelf = MemoryShelf()) = Garden(shelf) { hands.now }

/** Язык приложения — как на телефоне: ресурсы Android нужного языка. */
fun speak(tag: String) {
    val base = ApplicationProvider.getApplicationContext<Context>()
    val config = Configuration(base.resources.configuration)
    config.setLocale(Locale.forLanguageTag(tag))
    Platform.speak(base.createConfigurationContext(config))
    Skeleton.hours24 = true
}
