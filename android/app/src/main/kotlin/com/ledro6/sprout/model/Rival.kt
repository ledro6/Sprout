package com.ledro6.sprout.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import java.util.Base64

/**
 * Счёт друга, который прислал свой код. Сервера у Sprout нет: друг присылает
 * строку в переписке, её вставляют, и его счёт встаёт рядом. Код тот же, что
 * у iOS: друзья с айфоном и с Android меряются друг с другом.
 */
@Serializable
data class Rival(
    @SerialName("n") val name: String,
    @SerialName("t") val total: Int,
    @SerialName("s") val streak: Int,
    @SerialName("b") val best: Int,
    @SerialName("p") val plants: Int,
    /** Сутки от 1970 года. */
    @SerialName("d") val day: Int,
) {
    /** Без оглядки на регистр: друг, приславший код дважды, — одна строка. */
    val id: String get() = name.lowercase()

    val stamp: Long get() = day * 86_400_000L

    val card: String
        get() {
            val score = Lang.format(
                "%1\$@ в Sprout: %2\$@, череда %3\$@, лучшая %4\$lld.",
                name, Lang.format("%lld поливов", total), Lang.format("%lld дней", streak), best,
            )
            val invite = Lang.text(
                "Позвать меня в соперники: скопируйте это сообщение целиком и нажмите " +
                    "«Вставить» в Sprout → Профиль → Друзья.",
            )
            return score + "\n" + invite + "\n" + code
        }

    val code: String get() = MARK + pack(json.encodeToString(serializer(), this).toByteArray())

    companion object {
        const val MARK = "SPROUT1."

        private val json = Json { ignoreUnknownKeys = true }

        fun day(millis: Long): Int = Math.floorDiv(millis, 86_400_000L).toInt()

        fun mine(owner: String, score: Score, plants: Int, now: Long) =
            Rival(owner, score.total, score.streak, score.best, plants, day(now))

        /** Ищем метку, а не разбираем текст целиком: вставляют всё сообщение. */
        fun read(text: String): Rival? {
            for (piece in text.split(Regex("\\s+"))) {
                val start = piece.indexOf(MARK)
                if (start < 0) continue
                val token = piece.substring(start + MARK.length).takeWhile { allowed(it) }
                val data = unpack(token) ?: continue
                val rival = runCatching {
                    json.decodeFromString(serializer(), String(data, Charsets.UTF_8))
                }.getOrNull() ?: continue
                if (rival.name.isBlank()) continue
                return rival
            }
            return null
        }

        private fun allowed(c: Char) =
            c.code < 128 && (c.isLetterOrDigit() || c == '-' || c == '_')

        private fun pack(data: ByteArray): String =
            Base64.getUrlEncoder().withoutPadding().encodeToString(data)

        private fun unpack(token: String): ByteArray? {
            if (token.isEmpty()) return null
            return runCatching { Base64.getUrlDecoder().decode(token) }.getOrNull()
        }
    }
}
