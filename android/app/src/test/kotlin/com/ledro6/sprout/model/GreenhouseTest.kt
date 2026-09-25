package com.ledro6.sprout.model

import com.ledro6.sprout.ar.Sidecar
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.float
import org.junit.Test
import java.io.File
import java.nio.ByteBuffer
import java.nio.ByteOrder
import kotlin.math.abs
import kotlin.math.cos
import kotlin.math.sin
import kotlin.random.Random

/**
 * AR без телефона: то, что считается, — числами, как на iPhone; модели —
 * файлами: каждая открывается, у каждой детали есть узел, а поза узла в
 * GLB совпадает с той, что посчитает телефон.
 */
class GreenhouseTest {
    private val assets = File("src/main/assets")

    @Test
    fun moisture() = checks {
        check(round2(Greenhouse.sag(1.0).toDouble()), "0.00", "мокрое не провисает")
        check(round2(Greenhouse.sag(0.5).toDouble()), "0.00", "провисание — с половины")
        check(round2(Greenhouse.sag(0.25).toDouble()), "0.50", "четверть — половина провиса")
        check(round2(Greenhouse.sag(0.0).toDouble()), "1.00", "сухое провисает до конца")
        check(round2(Greenhouse.wither(0.5).toDouble()), "0.00", "выше тревоги лист зелёный")
        check(round2(Greenhouse.wither(0.2).toDouble()), "0.50", "на полпути — половина желтизны")
        check(round2(Greenhouse.wither(0.0).toDouble()), "1.00", "сухой лист — вся ступень")
        check(round2(Greenhouse.wither(0.39).toDouble()), "0.00", "ступень, а не каждая капля")
        check(round2(Greenhouse.unfurl(0.0)), "0.00", "не распустилось")
        check(round2(Greenhouse.unfurl(1.0)), "1.00", "распустилось")
        check((1..99).any { Greenhouse.unfurl(it / 100.0) > 1.0 }, "распускание с лёгким перелётом")
        val wet = Greenhouse.wetTint(1.0)
        check(round2(wet.red), "112.00", "мокрая земля темнее")
        check(round2(Greenhouse.wetTint(0.0).red), "255.00", "сухая земля — как есть")
    }

    @Test
    fun paint() = checks {
        val green = Channels(48.0, 113.0, 62.0)
        val plain = Paint.factor(Role.LEAF, green, null, wilts = true, wets = false, moisture = 1.0)
        check(plain.all { abs(it - 1f) < 1e-4 }, "мокрый лист без своей модели — краска как есть")
        val dry = Paint.factor(Role.LEAF, green, null, wilts = true, wets = false, moisture = 0.0)
        check(dry[0] > 1.5f && dry[1] < 1f, "сухой лист желтеет: красного больше, зелёного меньше")
        val soil = Paint.factor(Role.SOIL, Channels(136.0, 102.0, 73.0), null, wilts = false, wets = true, moisture = 1.0)
        check(soil.all { it < 1f }, "политая земля темнеет")
        val traits = Traits(leaf = Channels(160.0, 200.0, 90.0), flower = Channels(40.0, 60.0, 200.0), pot = Channels(20.0, 20.0, 20.0))
        val leaf = Paint.factor(Role.LEAF, green, traits, wilts = true, wets = false, moisture = 1.0)
        check(leaf[0] > 1f, "лист «по фото» светлее — множитель больше единицы")
        val flower = Paint.factor(Role.FLOWER, Channels(195.0, 30.0, 53.0), traits, wilts = false, wets = false, moisture = 1.0)
        check(flower[2] > flower[0], "красный цветок «по фото» синеет")
        val pot = Paint.factor(Role.POT, Channels(189.0, 102.0, 69.0), traits, wilts = false, wets = false, moisture = 1.0)
        check(pot.all { it < 0.2f }, "горшок «по фото» тёмный")
        val other = Paint.factor(Role.OTHER, green, traits, wilts = false, wets = false, moisture = 0.0)
        check(other.all { abs(it - 1f) < 1e-4 }, "стебли и корни не перекрашиваются")
        check(Greenhouse.shift(Channels(0.0, 0.0, 0.0), Channels(200.0, 0.0, 0.0))[0] == 1f, "чёрное не делим на ноль")
    }

    /** Поворот вокруг оси — формулой Родрига, как `turned(around:by:)` на iPhone. */
    private fun turned(p: DoubleArray, axis: DoubleArray, angle: Double): DoubleArray {
        val c = cos(angle)
        val s = sin(angle)
        val dot = axis[0] * p[0] + axis[1] * p[1] + axis[2] * p[2]
        val cross = doubleArrayOf(axis[1] * p[2] - axis[2] * p[1], axis[2] * p[0] - axis[0] * p[2], axis[0] * p[1] - axis[1] * p[0])
        return DoubleArray(3) { p[it] * c + cross[it] * s + axis[it] * dot * (1 - c) }
    }

    @Test
    fun pose() = checks {
        val random = Random(7)
        repeat(200) {
            val yaw = random.nextDouble(-7.0, 7.0)
            val rise = random.nextDouble(-2.0, 2.0)
            val roll = random.nextDouble(-2.0, 2.0)
            val lean = random.nextDouble(-0.5, 0.5)
            val p = doubleArrayOf(random.nextDouble(-1.0, 1.0), random.nextDouble(-1.0, 1.0), random.nextDouble(-1.0, 1.0))
            // Как `Pose.turn` на iPhone: крен, потом подъём с наклоном, потом вертикаль.
            val want = turned(turned(turned(p, doubleArrayOf(1.0, 0.0, 0.0), roll), doubleArrayOf(0.0, 0.0, 1.0), rise - lean), doubleArrayOf(0.0, 1.0, 0.0), yaw)
            val q = Pose.orientation(yaw.toFloat(), rise.toFloat(), roll.toFloat(), lean.toFloat())
            val got = Pose.rotate(q, floatArrayOf(p[0].toFloat(), p[1].toFloat(), p[2].toFloat()))
            val miss = (0 until 3).maxOf { abs(got[it] - want[it]) }
            check(miss < 1e-4, "поворот детали совпадает с iPhone (промах $miss)")
        }
        val m = Pose.matrix(floatArrayOf(1f, 2f, 3f), Pose.orientation(0f, 0f, 0f), 2f)
        check(m[0] == 2f && m[5] == 2f && m[10] == 2f && m[12] == 1f && m[13] == 2f && m[14] == 3f, "матрица по столбцам: размер и место")
    }

    @Test
    fun plot() = checks {
        val one = Plot.layout(listOf(0.2f), listOf(0.4f))
        check(abs(one[0].first) < 1e-6, "одно растение — посередине")
        val two = Plot.layout(listOf(0.1f, 0.1f), listOf(0.3f, 0.5f))
        check(abs(two[0].first + two[1].first) < 1e-6, "двое — по обе стороны от середины")
        val five = Plot.layout(List(5) { 0.1f }, listOf(0.5f, 0.1f, 0.2f, 0.3f, 0.4f))
        check(five[0].second > five[1].second, "самое высокое — во втором ряду, дальше")
        check(five.count { it.second == five[1].second } == 4, "в ряду по четыре")
        check(Plot.layout(emptyList(), emptyList()).isEmpty(), "пустой сад — пустая расстановка")
    }

    @Test
    fun rig() = checks {
        val giga = 1_073_741_824L
        check(Rig.plants(12 * giga, lowRam = false, hot = false) == 12, "много памяти — дюжина")
        check(Rig.plants(6 * giga, lowRam = false, hot = false) == 8, "средний телефон — восемь")
        check(Rig.plants(3 * giga, lowRam = false, hot = false) == 4, "мало памяти — четыре")
        check(Rig.plants(12 * giga, lowRam = false, hot = true) == 8, "горячий телефон — ступенью ниже")
        check(Rig.plants(12 * giga, lowRam = true, hot = false) == 4, "телефон с малой памятью — четыре")
        val hidden = (0 until 1000).count { Rig.thinned(it, 0.75) }
        check(hidden in 200..300, "реже на четверть — скрыта примерно четверть листьев ($hidden)")
        check((0 until 100).none { Rig.thinned(it, 1.2) }, "гуще не прячет ничего")
    }

    @Test
    fun models() = checks {
        val json = Json { ignoreUnknownKeys = true }
        for (preset in Preset.entries) {
            val name = preset.raw
            val glb = File(assets, "models/$name.glb")
            val side = File(assets, "models/$name.json")
            val preview = File(assets, "previews/$name.png")
            check(glb.exists() && side.exists() && preview.exists(), "$name: модель, описание и картинка на месте")
            if (!glb.exists() || !side.exists()) continue
            val sidecar = json.decodeFromString(Sidecar.serializer(), side.readText())
            val gltf = chunk(glb.readBytes())
            val nodes = gltf["nodes"]!!.jsonArray
            val pieces = nodes.mapNotNull { node ->
                val obj = node.jsonObject
                val title = obj["name"]?.jsonPrimitive?.content ?: return@mapNotNull null
                if (!title.startsWith("piece-")) return@mapNotNull null
                title.removePrefix("piece-").toInt() to obj
            }.toMap()
            check(pieces.size == sidecar.pieces.size, "$name: узел на каждую деталь (${pieces.size} из ${sidecar.pieces.size})")
            check(sidecar.looks.any { it.kind == Role.POT } && sidecar.looks.any { it.kind == Role.SOIL }, "$name: есть горшок и земля")
            check(sidecar.looks.any { it.kind == Role.LEAF }, "$name: есть что желтить")
            for ((index, piece) in sidecar.pieces.withIndex()) {
                check(piece.look in sidecar.looks.indices, "$name: деталь $index — материал есть")
                val node = pieces[index] ?: continue
                val stored = node["rotation"]!!.jsonArray.map { it.jsonPrimitive.float }
                val q = Pose.orientation(piece.yaw, piece.rise, piece.roll)
                // q и −q — один поворот.
                val same = (0 until 4).all { abs(stored[it] - q[it]) < 1e-3 } || (0 until 4).all { abs(stored[it] + q[it]) < 1e-3 }
                check(same, "$name: поза детали $index в GLB — та же, что посчитает телефон")
            }
            check(sidecar.height > 0.1f && sidecar.height < 1f, "$name: высота правдоподобная (${sidecar.height} м)")
        }
    }

    private fun chunk(data: ByteArray): JsonObject {
        val buffer = ByteBuffer.wrap(data).order(ByteOrder.LITTLE_ENDIAN)
        check(buffer.getInt(0) == 0x46546C67) { "не GLB" }
        val length = buffer.getInt(12)
        return Json.parseToJsonElement(String(data, 20, length, Charsets.UTF_8)).jsonObject
    }
}
