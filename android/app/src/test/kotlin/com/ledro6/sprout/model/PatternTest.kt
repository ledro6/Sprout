package com.ledro6.sprout.model

import org.junit.Test
import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.sqrt

/** Узор, отклик в руке, кадр и снимок — чистая арифметика, без телефона. */
class PatternTest {
    @Test
    fun weave() = checks {
        var clashes = 0
        val arrangements = HashMap<Int, MutableSet<List<Int>>>()
        for (count in 1..4) {
            val seen = mutableSetOf<List<Int>>()
            for (twistX in 0 until 64) for (twistY in 0 until 64) for (start in 0 until 64) {
                val weave = Weave.of(count, twistX, twistY, start)
                seen.add(listOf(weave.stepX, weave.stepY, weave.shift))
                if (count <= 1) continue
                for (row in -3..3) for (node in -6..6) {
                    // Как на iOS: номер узла делится на столбец и гнездо с усечением.
                    val here = weave.index(node / 2, node % 2, row, count)
                    val right = weave.index((node + 1) / 2, (node + 1) % 2, row, count)
                    val below = weave.index(node / 2, node % 2, row + 1, count)
                    if (here == right || here == below) clashes += 1
                }
            }
            arrangements[count] = seen
        }
        check("$clashes", "0", "одинаковые не стоят рядом")
        check("${arrangements[1]!!.size}", "1", "при одной фигурке раскладка одна")
        check("${arrangements[2]!!.size}", "2", "при двух — две")
        check("${arrangements[3]!!.size}", "12", "при трёх — двенадцать")
        check("${arrangements[4]!!.size}", "16", "при четырёх — шестнадцать")
        check("${Weave().index(3, 1, 2, 1)}", "0", "одна фигурка стоит везде")
    }

    @Test
    fun front() = checks {
        val w = 400.0
        val h = 800.0
        fun turn(front: Front, x: Double, y: Double) = front.turn(x, y, w, h)
        val corner = Front.Point(0.0, 0.0)
        check(round2(turn(corner, 0.0, 0.0)), "0.00", "из угла: угол первым")
        check(round2(turn(corner, 900.0, 0.0)), "1.00", "на мерке — единица")
        check(round2(turn(corner, 2000.0, 0.0)), "1.00", "дальше мерки — та же")
        val middle = Front.Point(200.0, 400.0)
        check(round2(turn(middle, 650.0, 400.0)), "0.50", "полмерки — половина черёда")
        check(round2(turn(corner, 450.0, 0.0)), "0.50", "из угла столько же: скорость одна")
        val inward = Front.Collapse(200.0, 400.0)
        check(round2(turn(inward, 200.0, 400.0)), "1.00", "обратная: точка нажатия последней")
        check(round2(turn(inward, 0.0, 0.0)), "0.00", "дальний угол — первым")
        var late = 0
        for ((sx, sy) in listOf(0.0 to 0.0, 200.0 to 400.0, 400.0 to 800.0, 399.0 to 1.0)) {
            val back = Front.Collapse(sx, sy)
            var first = 1.0
            var x = 0.0
            while (x <= 400) {
                var y = 0.0
                while (y <= 800) {
                    first = minOf(first, turn(back, x, y))
                    y += 10
                }
                x += 10
            }
            if (first > 1e-6) late += 1
        }
        check("$late", "0", "откуда ни нажми, волна трогается сразу")
        val up = Front.Sweep(-PI / 2)
        check(turn(up, 200.0, 800.0) < turn(up, 200.0, 0.0), "полосой вверх: низ раньше верха")
        check(round2(turn(up, 200.0, 800.0)) == "0.00" && round2(turn(up, 200.0, 0.0)) == "1.00", "кромки ровно на 0 и 1")
        var outside = 0
        for (front in listOf(corner, middle, inward, up, Front.Point(-300.0, 900.0))) {
            var x = -200.0
            while (x <= 600) {
                var y = -200.0
                while (y <= 1000) {
                    val value = turn(front, x, y)
                    if (value < 0 || value > 1 || value.isNaN()) outside += 1
                    y += 25
                }
                x += 25
            }
        }
        check("$outside", "0", "черёд нигде не выходит за 0…1")
        check(!Front.Point(1.0, 1.0).turn(5.0, 5.0, 0.0, 0.0).isNaN(), "на пустом холсте — без деления на ноль")
    }

    @Test
    fun frolic() = checks {
        fun look(elapsed: Double, turn: Double) = Frolic(elapsed).look(turn)
        check(look(0.0, 0.0) == (0 to 1.0) && look(-1.0, 0.0).first == 0, "в начале узор обычный")
        check(look(Frolic.BEAT, 1.0).first == 0 && look(Frolic.BEAT, 0.0).first == 1, "дальняя ещё стоит, ближняя уже в беспорядке")
        check(look(Frolic.BEAT * 0.5, 0.0).second < 0.05, "к середине такта сжата почти в ноль")
        check(look(Frolic.BEAT * 0.25, 0.0).second > 0.8, "в первой четверти ещё почти целая")
        check(look(Frolic.BEAT * 0.75, 0.0).first == 1, "после нуля — следующим состоянием")
        check(look(Frolic.SECONDS, 0.0).first == Frolic.BEATS && look(Frolic.SECONDS, 1.0) == (Frolic.BEATS to 1.0), "кончается обычным узором")
        check(!Frolic.chaotic(0) && !Frolic.chaotic(Frolic.BEATS) && Frolic.chaotic(1) && Frolic.chaotic(Frolic.BEATS - 1), "беспорядок — между краями")
        var wild = 0
        var tick = -0.5
        while (tick <= Frolic.SECONDS + 1) {
            var turn = 0.0
            while (turn <= 1.0) {
                val (state, scale) = look(tick, turn)
                if (scale < -1e-9 || scale > 1 + 1e-9 || scale.isNaN() || state < 0 || state > Frolic.BEATS) wild += 1
                turn += 0.05
            }
            tick += 0.01
        }
        check("$wild", "0", "размер и состояние в своих границах")
        check(Frolic.SECONDS > 4.5 && Frolic.SECONDS < 5.5, "кутерьма — около пяти секунд")
    }

    @Test
    fun sway() = checks {
        check(Sway.layer(3, 5, 1, 2) == Sway.layer(3, 5, 1, 2), "внутри захода слой один")
        val byLayer = IntArray(Sway.eases.size)
        var moved = 0
        var cells = 0
        for (column in 0 until 40) for (row in 0 until 40) for (slot in 0 until 2) {
            val here = Sway.layer(column, row, slot, 0)
            byLayer[here] += 1
            if (Sway.layer(column, row, slot, 1) != here) moved += 1
            cells += 1
        }
        check(byLayer.all { it > 0 }, "все слои кому-то достались")
        check(byLayer.all { abs(it.toDouble() / cells - 0.2) < 0.03 }, "и поровну: ${byLayer.toList()}")
        check(moved.toDouble() / cells > 0.6, "со сменой захода плывут другие")
        // Качок: цель разгоняется полсекунды, дальше телефон держат ровно.
        var common = 0.0
        val places = DoubleArray(Sway.eases.size * 2)
        val peak = DoubleArray(Sway.eases.size)
        val peakFrame = IntArray(Sway.eases.size)
        var after = 0.0
        var lateSway = 0.0
        val ramp = 30
        for (frame in 0 until ramp + 90) {
            val goal = minOf(frame.toDouble() / ramp, 1.0) * 14
            common += (goal - common) * 0.12
            Sway.settle(places, goal, goal)
            val step = (0 until Sway.eases.size).map { abs(Sway.hold(places[2 * it] - common)) }
            for ((i, size) in step.withIndex()) if (size > peak[i]) {
                peak[i] = size
                peakFrame[i] = frame
            }
            if (frame == ramp + 45) after = step.max()
            if (frame == ramp + 89) lateSway = step.max()
        }
        check(peak[2] < 0.001, "слой вровень с узором не уезжает")
        check(peak[0] > 1.0 && peak[4] > 2.5, "лёгкий уходит вперёд, тяжёлый отстаёт")
        check(peak.all { it <= Sway.LIMIT + 0.001 }, "никто не выходит за упор")
        check(peakFrame[4] >= ramp - 6, "тяжёлый расходится сильнее всего на исходе наклона")
        check(after > 0.3 && after < 1.5, "через ¾ секунды ещё плывут: $after")
        check(lateSway < 0.3, "через полторы — сошлись: $lateSway")
    }

    @Test
    fun pulse() = checks {
        for (pulse in listOf(Pulse.sprout, Pulse.bloom, Pulse.frenzy)) check(pulse.valid, "рисунок годится")
        val drops = Rain.drops(2.4, 7)
        check(drops.size in 16..59, "за волну — десятки тычков (${drops.size})")
        check(drops.first().at == 0.0 && drops.first().strength >= 0.85, "начинается сильным ударом")
        check(drops.all { it.strength >= Pulse.FAINTEST && it.strength <= 1 && it.edge in 0.0..1.0 }, "силы и резкости в границах")
        check(drops.zipWithNext().all { it.second.at - it.first.at >= Rain.CLOSEST - 1e-9 }, "по времени вперёд и не сливаются")
        check(drops.all { it.at <= 2.4 + 1e-9 }, "не выпадают за время")
        check(Rain.drops(2.4, 7) == drops, "то же зерно — тот же рисунок")
        val alike = (1..20).count { seed -> Rain.drops(2.4, seed * 7919L).map { it.at } == drops.map { it.at } }
        check("$alike", "0", "другое зерно — другие капли")
        val gaps = drops.zipWithNext { a, b -> b.at - a.at }
        val mean = gaps.average()
        val spread = sqrt(gaps.map { (it - mean) * (it - mean) }.average())
        check(spread / mean > 0.25, "промежутки неровные")
        check(drops.map { (it.edge * 10).toInt() }.toSet().size >= 5, "резкость разная")
        val early = drops.filter { it.at > 0 && it.at < 0.8 }.map { it.strength }.average()
        val late = drops.filter { it.at > 1.6 }.map { it.strength }.average()
        check(early > late * 1.5, "к концу волны слабеют")
        check(Rain.drops(0.0, 1).isEmpty(), "на нулевом времени капель нет")
        for (taps in listOf(Knock.pick, Knock.done, Knock.toss, Knock.back, Knock.wrong)) {
            check(
                taps.isNotEmpty() && taps.first().at == 0.0 && taps.zipWithNext().all { it.first.at < it.second.at } &&
                    taps.all { it.strength > 0 && it.strength <= 1 && it.edge in 0.0..1.0 },
                "короткий отклик годится",
            )
        }
        check(round2(Pulse.scaled(0.8, 0.0)), "0.00", "на нуле отклика нет")
        check((1..20).all { Pulse.scaled(it * 0.05, 1.0) >= it * 0.05 - 1e-12 }, "на полной силе не слабее задуманного")
        check(Pulse.scaled(0.3, 1.0) - 0.3 > Pulse.scaled(0.9, 1.0) - 0.9, "слабые подтягиваются сильнее")
        check(Pulse.scaled(0.5, 0.4) < Pulse.scaled(0.5, 0.8), "ползунок больше — сильнее")
        check(Pulse.scaled(3.0, 7.0) <= 1 && Pulse.scaled(-1.0, 1.0) == 0.0, "за 0…1 не выходит")
        val rise = Pulse.sprout
        check(rise.taps(1.1).size > 8, "всходы — с десяток тычков")
        check(rise.strength(0.55) > rise.strength(0.0) && rise.strength(1.0) < rise.strength(0.55), "набирают и садятся")
        val romp = Pulse.frenzy
        check("${romp.envelope.size}", "${Frolic.BEATS * 2 + 1}", "по паре точек на такт и хвост")
        val bumps = (0 until Frolic.BEATS).map { romp.strength((it + 0.4) / (Frolic.BEATS + 1)) }
        check(bumps.zipWithNext().all { it.first < it.second }, "каждый бугор сильнее прежнего")
        check(round2(romp.strength(1.0)), "0.00", "под конец стихает")
        var out = 0
        for (pulse in listOf(Pulse.sprout, Pulse.bloom, Pulse.frenzy)) {
            var step = -0.5
            while (step <= 1.5) {
                val value = pulse.strength(step)
                if (value < 0 || value > 1 || value.isNaN()) out += 1
                step += 0.01
            }
            for (span in listOf(0.2, 0.55, 1.1, 2.4, 5.0)) {
                if (pulse.taps(span).any { it.at < 0 || it.at > span + 1e-9 || it.strength < 0 || it.strength > 1 }) out += 1
            }
        }
        check("$out", "0", "сила и время тычков в границах")
        fun bad(pulse: Pulse) = !pulse.valid
        check(bad(Pulse(13.0, envelope = listOf(Moment(0.0, 0.5)))), "одна точка — не огибающая")
        check(bad(Pulse(13.0, envelope = listOf(Moment(0.0, 0.5), Moment(0.6, 0.2)))), "обязана дойти до конца")
        check(bad(Pulse(13.0, envelope = listOf(Moment(0.2, 0.5), Moment(1.0, 0.2)))), "и начаться в начале")
        check(bad(Pulse(13.0, envelope = listOf(Moment(0.0, 0.5), Moment(0.7, 0.2), Moment(0.3, 0.9), Moment(1.0, 0.0)))), "только вперёд")
        check(bad(Pulse(13.0, strike = 1.4, envelope = listOf(Moment(0.0, 0.5), Moment(1.0, 0.0)))), "сила больше единицы")
        check(bad(Pulse(0.0, envelope = listOf(Moment(0.0, 0.5), Moment(1.0, 0.0)))), "без частоты")
        check(bad(Pulse(200.0, envelope = listOf(Moment(0.0, 0.5), Moment(1.0, 0.0)))), "двести в секунду — не тычки")
    }

    @Test
    fun crop() = checks {
        val pane = 350.0
        val centred = Crop.of(4000.0, 3000.0, pane, 1.0, 0.0, 0.0)
        check(round2(centred.side) == "3000.00" && round2(centred.x) == "500.00" && round2(centred.y) == "0.00", "квадрат по высоте посередине")
        val upright = Crop.of(3000.0, 4000.0, pane, 1.0, 0.0, 0.0)
        check(round2(upright.side) == "3000.00" && round2(upright.y) == "500.00", "из высокого — по ширине")
        val closer = Crop.of(4000.0, 3000.0, pane, 2.0, 0.0, 0.0)
        check(round2(closer.side) == "1500.00" && round2(closer.x) == "1250.00", "вдвое ближе — вдвое меньше")
        check(Crop.of(4000.0, 3000.0, pane, 1.0, 100.0, 0.0).x < centred.x, "потянули вправо — кадр ушёл влево")
        val shoved = Crop.of(4000.0, 3000.0, pane, 1.0, 99_999.0, 99_999.0)
        check(round2(shoved.x) == "0.00" && shoved.inside(4000.0, 3000.0), "упирается в край")
        val pinned = Crop.of(3000.0, 4000.0, pane, 1.0, 0.0, -99_999.0)
        check(round2(pinned.y + pinned.side), "4000.00", "с другой стороны тоже")
        check(round2(Crop.slack(4000.0, 3000.0, pane, 1.0).second) == "0.00" && Crop.slack(4000.0, 3000.0, pane, 1.0).first > 0, "люфт по ширине")
        var escaped = 0
        for ((w, h) in listOf(4000.0 to 3000.0, 3000.0 to 4000.0, 1200.0 to 1200.0, 800.0 to 60.0)) {
            for (zoom in listOf(0.2, 1.0, 1.7, 4.0, 9.0)) {
                var dx = -900.0
                while (dx <= 900) {
                    var dy = -900.0
                    while (dy <= 900) {
                        val c = Crop.of(w, h, pane, zoom, dx, dy)
                        if (!c.inside(w, h) || c.side <= 0 || c.side.isNaN()) escaped += 1
                        dy += 75
                    }
                    dx += 75
                }
            }
        }
        check("$escaped", "0", "кадр не вылезает за снимок")
        check(round2(Crop.of(4000.0, 3000.0, pane, 0.1, 0.0, 0.0).side), "3000.00", "меньше «враспор» нельзя")
        check(
            round2(Crop.of(4000.0, 3000.0, pane, 99.0, 0.0, 0.0).side) == round2(Crop.of(4000.0, 3000.0, pane, Crop.DEEPEST, 0.0, 0.0).side),
            "дальше предела не приблизить",
        )
    }

    @Test
    fun sample() = checks {
        fun photo(blur: Int = 0, dark: Boolean = false): ByteArray {
            val size = 96
            val pixels = ByteArray(size * size * 4) { 235.toByte() }
            for (y in 0 until size) for (x in 0 until size) {
                val at = (y * size + x) * 4
                var color = Triple(235, 235, 235)
                val dx = x - size / 2
                if (y > 64 && abs(dx) < 22) {
                    color = Triple(190, 100, 64)
                } else if (y in 13..64 && abs(dx) < 34) {
                    val ripple = (x / 3 + y / 3) % 2 == 0
                    color = if (ripple) Triple(46, 128, 52) else Triple(70, 160, 70)
                    if ((x - 30) * (x - 30) + (y - 24) * (y - 24) < 30) color = Triple(220, 30, 50)
                }
                if (dark) color = Triple(color.first / 12, color.second / 12, color.third / 12)
                pixels[at] = color.first.toByte()
                pixels[at + 1] = color.second.toByte()
                pixels[at + 2] = color.third.toByte()
                pixels[at + 3] = 255.toByte()
            }
            if (blur <= 0) return pixels
            val out = pixels.copyOf()
            for (y in 0 until size) for (x in 0 until size) for (channel in 0 until 3) {
                var sum = 0
                var count = 0
                for (yy in maxOf(y - blur, 0)..minOf(y + blur, size - 1)) for (xx in maxOf(x - blur, 0)..minOf(x + blur, size - 1)) {
                    sum += pixels[(yy * size + xx) * 4 + channel].toInt() and 0xFF
                    count += 1
                }
                out[(y * size + x) * 4 + channel] = (sum / count).toByte()
            }
            return out
        }
        val mask = ByteArray(96 * 96)
        for (y in 12 until 96) for (x in 0 until 96) if (abs(x - 48) < 34) mask[y * 96 + x] = 255.toByte()
        val sharp = Sample.read(photo(), mask, 96, 96)
        check(sharp.verdict == Sample.Verdict.FINE, "резкий снимок годится")
        val traits = sharp.traits
        check(traits != null && traits.leaf.green > traits.leaf.red + 40, "лист зелёный")
        check((traits?.pot?.red ?: 0.0) > 150, "горшок терракотовый")
        check((traits?.flower?.red ?: 0.0) > 180 && (traits?.flower?.green ?: 255.0) < 90, "цветы красные")
        check(traits != null && traits.density in 0.75..1.35 && traits.stretch in 0.8..1.3, "густота и рост в границах")
        val blurry = Sample.read(photo(blur = 4), mask, 96, 96)
        check(blurry.verdict == Sample.Verdict.BLURRY && blurry.traits == null, "мыльный — готовая модель")
        check(Sample.read(photo(dark = true), mask, 96, 96).verdict == Sample.Verdict.DARK, "тёмный — тоже")
        check(Sample.read(ByteArray(96 * 96 * 4) { 128.toByte() }, null, 96, 96).traits == null, "на сером растения нет")
        check(Sample.read(photo(), null, 96, 96).verdict == Sample.Verdict.FINE, "без маски — середина кадра")
        check(Sample.read(ByteArray(10), null, 96, 96).verdict == Sample.Verdict.EMPTY, "короткий снимок — пусто, а не падение")
    }
}
