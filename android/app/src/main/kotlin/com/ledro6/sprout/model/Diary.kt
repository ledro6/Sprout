package com.ledro6.sprout.model


/** Поливы одного растения — из общего журнала. Время настоящее. */
data class Diary(val entries: List<Long>) {
    val total: Int get() = entries.size

    /** Средний промежуток в миллисекундах; пусто, пока поливов меньше двух. */
    val average: Double?
        get() {
            if (entries.size < 2) return null
            return (entries.first() - entries.last()).toDouble() / (entries.size - 1)
        }

    companion object {
        const val SHOWN = 6

        fun of(log: List<Watering>, plant: String) =
            Diary(log.filter { it.plant == plant }.map { it.at }.sortedDescending())

        /** «Сегодня, 14:05», «Вчера, 9:12», «20 сентября, 18:40». */
        fun label(moment: Long, now: Long, days: Days): String {
            val at = days.moment(moment)
            val time = Skeleton.time(at)
            val day = at.toLocalDate()
            val today = days.day(now)
            if (day == today) return Lang.format("Сегодня, %@", time)
            if (day == today.minusDays(1)) return Lang.format("Вчера, %@", time)
            val date = Skeleton.format(at, if (day.year != today.year) "dMMMMy" else "dMMMM")
            return Lang.format("%1\$@, %2\$@", date, time)
        }

        /** «раз в 3 дня», «раз в 5 ч» — крупнейшей единицей. */
        fun rhythm(millis: Double): String {
            val seconds = millis / 1000
            if (seconds < 60) return Lang.text("чаще раза в минуту")
            if (seconds < 3_600) {
                val minutes = (seconds / 60).roundedInt()
                return if (minutes <= 1) Lang.text("раз в минуту") else Lang.format("раз в %lld минут", minutes)
            }
            if (seconds < 86_400) {
                val hours = (seconds / 3_600).roundedInt()
                return if (hours <= 1) Lang.text("раз в час") else Lang.format("раз в %lld часов", hours)
            }
            val count = (seconds / 86_400).roundedInt()
            return if (count <= 1) Lang.text("раз в день") else Lang.format("раз в %lld дней", count)
        }
    }
}
