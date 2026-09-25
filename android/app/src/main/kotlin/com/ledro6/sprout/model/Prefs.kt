package com.ledro6.sprout.model

/**
 * Хранилище настроек: несколько чисел и строк, нужных до первого экрана. На
 * телефоне — `SharedPreferences`, в прогоне модели — словарь в памяти.
 */
interface Prefs {
    fun has(key: String): Boolean
    fun string(key: String): String?
    fun int(key: String, fallback: Int = 0): Int
    fun double(key: String, fallback: Double = 0.0): Double
    fun bool(key: String, fallback: Boolean = false): Boolean
    fun strings(key: String): List<String>?

    fun put(key: String, value: String?)
    fun put(key: String, value: Int)
    fun put(key: String, value: Double)
    fun put(key: String, value: Boolean)
    fun put(key: String, value: List<String>)
}

/** Настройки в памяти — для проверок и на случай, если файл настроек не открылся. */
class MemoryPrefs : Prefs {
    private val values = HashMap<String, Any>()

    override fun has(key: String) = values.containsKey(key)
    override fun string(key: String) = values[key] as? String
    override fun int(key: String, fallback: Int) = (values[key] as? Int) ?: fallback
    override fun double(key: String, fallback: Double) = (values[key] as? Double) ?: fallback
    override fun bool(key: String, fallback: Boolean) = (values[key] as? Boolean) ?: fallback

    @Suppress("UNCHECKED_CAST")
    override fun strings(key: String) = values[key] as? List<String>

    override fun put(key: String, value: String?) {
        if (value == null) values.remove(key) else values[key] = value
    }

    override fun put(key: String, value: Int) { values[key] = value }
    override fun put(key: String, value: Double) { values[key] = value }
    override fun put(key: String, value: Boolean) { values[key] = value }
    override fun put(key: String, value: List<String>) { values[key] = value.toList() }
}
