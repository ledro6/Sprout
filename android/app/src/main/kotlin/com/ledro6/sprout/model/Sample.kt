package com.ledro6.sprout.model

import kotlin.math.max
import kotlin.math.min

/** Квадратный кадр, вырезанный из снимка, — в точках снимка, а не экрана. */
data class Crop(val x: Double, val y: Double, val side: Double) {
    fun inside(width: Double, height: Double): Boolean {
        val slip = 1e-6
        return x >= -slip && y >= -slip && x + side <= width + slip && y + side <= height + slip
    }

    companion object {
        /** Дальше снимок рассыпается на точки. */
        const val DEEPEST = 4.0

        /**
         * Кадр, видимый в окне: снимок вписан «враспор», увеличен в `scale` раз и
         * сдвинут на `offset`. Сдвиг держится в границах — пустого угла не будет.
         */
        fun of(width: Double, height: Double, window: Double, scale: Double, offsetX: Double, offsetY: Double): Crop {
            val w = max(width, 1.0)
            val h = max(height, 1.0)
            val side = max(window, 1.0)
            val cover = max(side / w, side / h)
            val zoom = cover * scale.coerceIn(1.0, DEEPEST)
            val (heldX, heldY) = hold(offsetX, offsetY, width, height, window, scale)
            val left = (w * zoom - side) / 2 - heldX
            val top = (h * zoom - side) / 2 - heldY
            return Crop(left / zoom, top / zoom, side / zoom)
        }

        fun hold(offsetX: Double, offsetY: Double, width: Double, height: Double, window: Double, scale: Double): Pair<Double, Double> {
            val (roomX, roomY) = slack(width, height, window, scale)
            return offsetX.coerceIn(-roomX, roomX) to offsetY.coerceIn(-roomY, roomY)
        }

        /** Сколько снимок больше окна с каждой стороны; ноль — двигать некуда. */
        fun slack(width: Double, height: Double, window: Double, scale: Double): Pair<Double, Double> {
            val w = max(width, 1.0)
            val h = max(height, 1.0)
            val side = max(window, 1.0)
            val zoom = max(side / w, side / h) * scale.coerceIn(1.0, DEEPEST)
            return max(0.0, (w * zoom - side) / 2) to max(0.0, (h * zoom - side) / 2)
        }
    }
}

/**
 * Разбор снимка для своей модели: годится ли он и какие на нём цвета. Только
 * арифметика над пикселями — проверяется без телефона.
 */
object Sample {
    enum class Verdict {
        FINE, BLURRY, DARK, BRIGHT, EMPTY;

        val line: String
            get() = when (this) {
                FINE -> Lang.text("Модель построю по снимку.")
                BLURRY -> Lang.text("Снимок мыльный — снимите почётче.")
                DARK -> Lang.text("Снимок тёмный — снимите при свете.")
                BRIGHT -> Lang.text("Снимок пересвечен — снимите без прямого солнца.")
                EMPTY -> Lang.text("Растения на снимке не видно — снимите его целиком.")
            }
    }

    data class Reading(val verdict: Verdict, val traits: Traits? = null)

    const val SHARP_ENOUGH = 40f

    private class Bucket {
        val r = ArrayList<Int>()
        val g = ArrayList<Int>()
        val b = ArrayList<Int>()
        val size get() = r.size

        fun keep(rgba: ByteArray, at: Int) {
            r.add(rgba[at].toInt() and 0xFF)
            g.add(rgba[at + 1].toInt() and 0xFF)
            b.add(rgba[at + 2].toInt() and 0xFF)
        }

        fun median(): Channels {
            fun middle(values: List<Int>) = values.sorted()[values.size / 2].toDouble()
            return Channels(middle(r), middle(g), middle(b))
        }
    }

    /** Пиксели RGBA рядами сверху вниз; маска — байт на пиксель. Нет маски — середина кадра. */
    fun read(rgba: ByteArray, mask: ByteArray?, width: Int, height: Int): Reading {
        if (width <= 8 || height <= 8 || rgba.size < width * height * 4) return Reading(Verdict.EMPTY)
        val inside: BooleanArray = if (mask != null && mask.size >= width * height) {
            BooleanArray(width * height) { (mask[it].toInt() and 0xFF) > 127 }
        } else {
            centre(width, height)
        }
        var left = width
        var right = -1
        var top = height
        var bottom = -1
        var count = 0
        var light = 0f
        for (y in 0 until height) {
            for (x in 0 until width) {
                if (!inside[y * width + x]) continue
                count += 1
                left = min(left, x)
                right = max(right, x)
                top = min(top, y)
                bottom = max(bottom, y)
                val at = (y * width + x) * 4
                light += (0.3f * u(rgba[at]) + 0.59f * u(rgba[at + 1]) + 0.11f * u(rgba[at + 2])) / 255f
            }
        }
        if (count <= width * height / 50) return Reading(Verdict.EMPTY)
        val mean = light / count
        if (mean < 0.08f) return Reading(Verdict.DARK)
        if (mean > 0.93f) return Reading(Verdict.BRIGHT)
        if (sharpness(rgba, width, height, left, right, top, bottom) < SHARP_ENOUGH) return Reading(Verdict.BLURRY)

        val leaves = Bucket()
        val pale = Bucket()
        val petals = HashMap<Int, Bucket>()
        val pot = Bucket()
        val boxHeight = max(bottom - top, 1)
        for (y in top..bottom) {
            val low = (y - top).toFloat() / boxHeight > 0.65f
            for (x in left..right) {
                if (!inside[y * width + x]) continue
                val at = (y * width + x) * 4
                val (hue, saturation, value) = hsv(u(rgba[at]), u(rgba[at + 1]), u(rgba[at + 2]))
                val green = hue in 55f..175f && saturation >= 0.18f && value >= 0.12f
                when {
                    green -> leaves.keep(rgba, at)
                    low -> pot.keep(rgba, at)
                    saturation < 0.2f && value > 0.72f -> pale.keep(rgba, at)
                    saturation >= 0.35f && value >= 0.3f -> petals.getOrPut((hue / 30).toInt() % 12) { Bucket() }.keep(rgba, at)
                }
            }
        }
        if (leaves.size <= count / 50) return Reading(Verdict.EMPTY)
        val leaf = leaves.median()
        val variegation = if (pale.size > leaves.size / 8) pale.median() else null
        val bloom = petals.values.maxByOrNull { it.size }
        val flower = if ((bloom?.size ?: 0) > count / 100) bloom?.median() else null
        val pottery = if (pot.size > count * 3 / 100) pot.median() else null
        val area = ((right - left + 1) * (bottom - top + 1)).toFloat()
        val thick = leaves.size / area
        val density = 0.75 + 0.6 * ((thick - 0.15f) / 0.45f).coerceIn(0f, 1f)
        val ratio = (bottom - top + 1).toDouble() / (right - left + 1)
        val stretch = (ratio / 1.15).coerceIn(0.8, 1.3)
        return Reading(Verdict.FINE, Traits(leaf, variegation, flower, pottery, density, stretch))
    }

    private fun u(byte: Byte): Float = (byte.toInt() and 0xFF).toFloat()

    /** Разброс лапласиана по яркости: у резкого снимка края рвутся. */
    fun sharpness(rgba: ByteArray, width: Int, height: Int, boxLeft: Int, boxRight: Int, boxTop: Int, boxBottom: Int): Float {
        fun gray(x: Int, y: Int): Float {
            val at = (y * width + x) * 4
            return 0.3f * u(rgba[at]) + 0.59f * u(rgba[at + 1]) + 0.11f * u(rgba[at + 2])
        }
        val left = max(boxLeft, 1)
        val right = min(boxRight, width - 2)
        val top = max(boxTop, 1)
        val bottom = min(boxBottom, height - 2)
        if (left >= right || top >= bottom) return 0f
        var sum = 0f
        var square = 0f
        var count = 0f
        for (y in top..bottom) {
            for (x in left..right) {
                val edge = gray(x - 1, y) + gray(x + 1, y) + gray(x, y - 1) + gray(x, y + 1) - 4 * gray(x, y)
                sum += edge
                square += edge * edge
                count += 1
            }
        }
        val mean = sum / count
        return square / count - mean * mean
    }

    /** Тон в градусах, насыщенность и яркость 0…1. */
    fun hsv(r: Float, g: Float, b: Float): Triple<Float, Float, Float> {
        val red = r / 255
        val green = g / 255
        val blue = b / 255
        val top = maxOf(red, green, blue)
        val bottom = minOf(red, green, blue)
        val spread = top - bottom
        if (spread <= 1e-5f) return Triple(0f, 0f, top)
        var hue = when (top) {
            red -> (green - blue) / spread
            green -> (blue - red) / spread + 2
            else -> (red - green) / spread + 4
        }
        hue *= 60
        if (hue < 0) hue += 360
        return Triple(hue, spread / top, top)
    }

    /** Без маски растение ищется в середине кадра — эллипс на семь десятых. */
    private fun centre(width: Int, height: Int): BooleanArray {
        val inside = BooleanArray(width * height)
        for (y in 0 until height) {
            for (x in 0 until width) {
                val dx = (x.toFloat() / width - 0.5f) / 0.35f
                val dy = (y.toFloat() / height - 0.5f) / 0.35f
                inside[y * width + x] = dx * dx + dy * dy <= 1
            }
        }
        return inside
    }
}
