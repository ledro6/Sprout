package com.ledro6.sprout.model

import kotlinx.serialization.Serializable

/**
 * Оттенок узора или волны. У каждого две ипостаси — бледная для покоя и
 * насыщенная для волны. Числа — те же, что на iOS: бледные подобраны под
 * светлоту #CFF8C9, чтобы смена цвета не меняла заметность узора.
 */
enum class Tint(val pale: Channels, val vivid: Channels) {
    GREEN(Channels(207.0, 248.0, 201.0), Channels(10.0, 199.0, 51.0)),
    BLUE(Channels(222.0, 238.0, 255.0), Channels(0.0, 122.0, 255.0)),
    VIOLET(Channels(240.0, 233.0, 254.0), Channels(97.0, 24.0, 242.0)),
    AMBER(Channels(255.0, 233.0, 208.0), Channels(255.0, 136.0, 0.0)),
    ROSE(Channels(255.0, 230.0, 236.0), Channels(255.0, 13.0, 73.0)),
    TEAL(Channels(205.0, 245.0, 238.0), Channels(0.0, 168.0, 160.0)),
    SKY(Channels(212.0, 241.0, 251.0), Channels(0.0, 172.0, 230.0)),
    INDIGO(Channels(233.0, 235.0, 255.0), Channels(72.0, 58.0, 222.0)),
    FUCHSIA(Channels(250.0, 231.0, 250.0), Channels(206.0, 38.0, 196.0)),
    CORAL(Channels(255.0, 232.0, 222.0), Channels(255.0, 94.0, 58.0)),
    LEMON(Channels(245.0, 238.0, 190.0), Channels(226.0, 186.0, 0.0));

    val title: String
        get() = when (this) {
            GREEN -> Lang.text("Зелёный")
            BLUE -> Lang.text("Синий")
            VIOLET -> Lang.text("Сиреневый")
            AMBER -> Lang.text("Медовый")
            ROSE -> Lang.text("Розовый")
            TEAL -> Lang.text("Бирюзовый")
            SKY -> Lang.text("Небесный")
            INDIGO -> Lang.text("Индиго")
            FUCHSIA -> Lang.text("Фуксия")
            CORAL -> Lang.text("Коралловый")
            LEMON -> Lang.text("Лимонный")
        }

    companion object {
        val defaultPattern = GREEN
        val defaultWave = BLUE
        val defaultAvatar = GREEN

        fun of(raw: Int): Tint? = entries.getOrNull(raw)
    }
}

@Serializable
data class Channels(val red: Double, val green: Double, val blue: Double) {
    companion object {
        fun mix(from: Channels, to: Channels, k: Double): Channels {
            val part = k.coerceIn(0.0, 1.0)
            return Channels(
                from.red + (to.red - from.red) * part,
                from.green + (to.green - from.green) * part,
                from.blue + (to.blue - from.blue) * part,
            )
        }
    }
}

/** Оттенок каналами, готовый к рисованию: во время смены цвета — смесь двух. */
data class Shade(val pale: Channels, val vivid: Channels) {
    constructor(tint: Tint) : this(tint.pale, tint.vivid)

    companion object {
        fun mix(from: Shade, to: Shade, k: Double) =
            Shade(Channels.mix(from.pale, to.pale, k), Channels.mix(from.vivid, to.vivid, k))
    }
}
