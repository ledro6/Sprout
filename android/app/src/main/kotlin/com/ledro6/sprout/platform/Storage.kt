package com.ledro6.sprout.platform

import android.content.Context
import android.content.SharedPreferences
import android.util.AtomicFile
import com.ledro6.sprout.model.GardenState
import com.ledro6.sprout.model.Prefs
import com.ledro6.sprout.model.Shelf
import kotlinx.serialization.json.Json
import org.json.JSONArray
import java.io.File
import java.util.UUID

/** Настройки — в `SharedPreferences`: несколько чисел, нужных до первого экрана. */
class AndroidPrefs(context: Context) : Prefs {
    private val store: SharedPreferences =
        context.getSharedPreferences("sprout", Context.MODE_PRIVATE)

    override fun has(key: String) = store.contains(key)

    override fun string(key: String): String? = runCatching { store.getString(key, null) }.getOrNull()

    override fun int(key: String, fallback: Int) = runCatching { store.getInt(key, fallback) }.getOrDefault(fallback)

    override fun double(key: String, fallback: Double): Double =
        runCatching {
            if (!store.contains(key)) fallback
            else java.lang.Double.longBitsToDouble(store.getLong(key, 0))
        }.getOrDefault(fallback)

    override fun bool(key: String, fallback: Boolean) =
        runCatching { store.getBoolean(key, fallback) }.getOrDefault(fallback)

    override fun strings(key: String): List<String>? {
        val raw = string(key) ?: return null
        return runCatching {
            val array = JSONArray(raw)
            List(array.length()) { array.getString(it) }
        }.getOrNull()
    }

    override fun put(key: String, value: String?) {
        store.edit().apply { if (value == null) remove(key) else putString(key, value) }.apply()
    }

    override fun put(key: String, value: Int) = store.edit().putInt(key, value).apply()

    override fun put(key: String, value: Double) =
        store.edit().putLong(key, java.lang.Double.doubleToRawLongBits(value)).apply()

    override fun put(key: String, value: Boolean) = store.edit().putBoolean(key, value).apply()

    override fun put(key: String, value: List<String>) = put(key, JSONArray(value).toString())
}

/**
 * Сад — файлом garden.json в личной папке приложения: её не вычищают ради
 * места, и она попадает в резервную копию Android. Запись атомарная: сбой
 * посреди записи оставит прежний файл, а не половину нового.
 */
class FileShelf(context: Context) : Shelf {
    private val file = AtomicFile(File(context.filesDir, NAME))

    override fun read(): GardenState? = runCatching {
        json.decodeFromString(GardenState.serializer(), String(file.readFully(), Charsets.UTF_8))
    }.getOrNull()

    override fun write(state: GardenState): Boolean {
        val stream = runCatching { file.startWrite() }.getOrNull() ?: return false
        return try {
            stream.write(json.encodeToString(GardenState.serializer(), state).toByteArray(Charsets.UTF_8))
            file.finishWrite(stream)
            true
        } catch (_: Exception) {
            file.failWrite(stream)
            false
        }
    }

    override fun drop(shot: String) {
        Shots.drop(shot)
    }

    companion object {
        const val NAME = "garden.json"
        val json = Json { ignoreUnknownKeys = true; encodeDefaults = false }
    }
}

/** Снимки растений и хозяина — в личной папке приложения; в файле сада только имя. */
object Shots {
    @Volatile
    private var folder: File? = null

    fun open(context: Context) {
        folder = File(context.filesDir, "Shots").apply { mkdirs() }
    }

    fun file(name: String): File? {
        // Имя — только своё: без путей, иначе чужой файл сада увёл бы наружу.
        if (name.contains('/') || name.contains("..")) return null
        return folder?.let { File(it, name) }
    }

    fun keep(bytes: ByteArray): String? {
        val name = UUID.randomUUID().toString() + ".jpg"
        val target = file(name) ?: return null
        return runCatching {
            val atomic = AtomicFile(target)
            val stream = atomic.startWrite()
            try {
                stream.write(bytes)
                atomic.finishWrite(stream)
            } catch (error: Exception) {
                atomic.failWrite(stream)
                throw error
            }
            name
        }.getOrNull()
    }

    fun drop(name: String) {
        file(name)?.delete()
    }
}
