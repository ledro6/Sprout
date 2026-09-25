package com.ledro6.sprout.ui.stats

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.animate
import androidx.compose.animation.core.withInfiniteAnimationFrameMillis
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.FilledTonalButton
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Slider
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.State
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.produceState
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ColorFilter
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.translate
import androidx.compose.ui.graphics.painter.Painter
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextMeasurer
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.drawText
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.ledro6.sprout.R
import com.ledro6.sprout.app.LocalSprout
import com.ledro6.sprout.design.Effects
import com.ledro6.sprout.design.LocalPalette
import com.ledro6.sprout.design.Motion
import com.ledro6.sprout.design.Palette
import com.ledro6.sprout.design.SproutTheme
import com.ledro6.sprout.model.Garden
import com.ledro6.sprout.model.Hint
import com.ledro6.sprout.model.Lang
import com.ledro6.sprout.model.Orrery
import com.ledro6.sprout.model.Plant
import com.ledro6.sprout.model.Spheres
import com.ledro6.sprout.model.Term
import com.ledro6.sprout.model.Thirst
import com.ledro6.sprout.model.Walk
import com.ledro6.sprout.model.roundedInt
import com.ledro6.sprout.platform.Feel
import com.ledro6.sprout.platform.SpheresPlayer
import com.ledro6.sprout.ui.Go
import com.ledro6.sprout.ui.components.Plate
import com.ledro6.sprout.ui.components.RowShape
import com.ledro6.sprout.ui.components.SproutDivider
import com.ledro6.sprout.ui.components.SubScreen
import com.ledro6.sprout.ui.components.TermHint
import com.ledro6.sprout.ui.components.hintSpot
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.hypot
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sin

/** Кадры, пока экран виден. В проверках бесконечная анимация стоит — кадр один. */
@Composable
fun rememberFrames(): State<Long> = produceState(0L) {
    while (true) withInfiniteAnimationFrameMillis { value = it }
}

/** Сколько суток сада прошло с последнего такта — планеты едут плавно между тактами. */
private fun drift(garden: Garden, now: Long): Double = (now - garden.ticked) / 1000.0 * Garden.SPEED / 86_400

/** Живой циферблат без касаний — для входа в планетарий. */
@Composable
fun LiveDial(modifier: Modifier = Modifier, small: Boolean = false) {
    val garden = LocalSprout.current.garden
    val palette = LocalPalette.current
    val frames = rememberFrames()
    val measurer = rememberTextMeasurer()
    val drop = painterResource(R.drawable.ic_water_drop_fill)
    Canvas(modifier.clearAndSetSemantics {}) {
        frames.value
        val orbits = Orrery.orbits(garden.plants)
        val planets = Orrery.sky(orbits, 0.0, drift(garden, System.currentTimeMillis()))
        dial(DialFrame(planets, small = small), palette, drop, measurer, TextStyle.Default)
    }
}

/** Что рисует циферблат в этот кадр. */
class DialFrame(
    val planets: List<Orrery.Planet>,
    val flashes: List<Orrery.Flash> = emptyList(),
    val picked: String? = null,
    val beat: Double = 0.0,
    val small: Boolean = false,
)

private fun DrawScope.reach(small: Boolean) = min(size.width, size.height) / 2 - (if (small) 5 else 16).dp.toPx()

private fun DrawScope.spot(radius: Double, angle: Double, small: Boolean): Offset {
    val full = reach(small) * radius.toFloat()
    return Offset(size.width / 2 + full * sin(angle).toFloat(), size.height / 2 - full * cos(angle).toFloat())
}

/** Где планета на циферблате данного размера — для касаний. */
fun planetAt(planet: Orrery.Planet, size: Size, density: Float): Offset {
    val full = (min(size.width, size.height) / 2 - 16 * density) * planet.radius.toFloat()
    return Offset(size.width / 2 + full * sin(planet.angle).toFloat(), size.height / 2 - full * cos(planet.angle).toFloat())
}

/**
 * Циферблат: орбиты, светлый сектор и луч полива, следы пройденного пути,
 * вспышки у луча, солнце-капля и планеты цвета влажности.
 */
fun DrawScope.dial(dial: DialFrame, palette: Palette, drop: Painter, measurer: TextMeasurer, style: TextStyle) {
    val small = dial.small
    val middle = center
    val full = reach(small)
    val sun = (if (small) 40 * 0.45f else 40f).dp.toPx()

    for (planet in dial.planets) {
        val lit = planet.id == dial.picked
        drawCircle(
            Color.White.copy(alpha = if (lit) 0.4f else 0.1f), full * planet.radius.toFloat(), middle,
            style = Stroke((if (lit) 1.4f else 0.6f).dp.toPx()),
        )
    }

    val wedge = Path().apply {
        moveTo(middle.x, middle.y)
        for (step in 0..12) {
            val angle = -Orrery.GATE + 2 * Orrery.GATE * step / 12
            lineTo(middle.x + (full + 8.dp.toPx()) * sin(angle).toFloat(), middle.y - (full + 8.dp.toPx()) * cos(angle).toFloat())
        }
        close()
    }
    drawPath(wedge, palette.water.copy(alpha = 0.1f))
    drawLine(
        Brush.verticalGradient(
            listOf(palette.water.copy(alpha = 0.15f), palette.water.copy(alpha = 0.9f)),
            startY = middle.y - full, endY = middle.y,
        ),
        Offset(middle.x, middle.y - sun / 2), Offset(middle.x, middle.y - full - 6.dp.toPx()),
        (if (small) 1.5f else 2.5f).dp.toPx(), StrokeCap.Round,
    )

    for (planet in dial.planets) {
        val travelled = planet.angle
        val steps = max((travelled / (2 * PI) * 72).toInt(), 1)
        val trail = Path()
        for (step in 0..steps) {
            val at = spot(planet.radius, travelled * step / steps, small)
            if (step == 0) trail.moveTo(at.x, at.y) else trail.lineTo(at.x, at.y)
        }
        drawPath(
            trail, palette.level(planet.moisture).copy(alpha = 0.3f),
            style = Stroke((if (small) 1.2f else 2f).dp.toPx(), cap = StrokeCap.Round),
        )
    }

    for (flash in dial.flashes) {
        val at = spot(flash.radius, 0.0, small)
        val r = (5 + (1 - flash.strength) * 18).toFloat().dp.toPx()
        drawCircle(palette.water.copy(alpha = flash.strength.toFloat().coerceIn(0f, 1f)), r, at, style = Stroke(2.dp.toPx()))
    }

    val halo = sun * 0.7f + sun / 3
    drawCircle(
        Brush.radialGradient(listOf(palette.water.copy(alpha = 0.55f), palette.water.copy(alpha = 0f)), middle, halo),
        halo, middle,
    )
    drawCircle(Brush.radialGradient(listOf(Color.White, palette.water), middle, sun / 2), sun / 2, middle)
    val glyph = sun * 0.42f
    translate(middle.x - glyph / 2, middle.y - glyph * 0.6f) {
        with(drop) { draw(Size(glyph, glyph * 1.2f), colorFilter = ColorFilter.tint(palette.space.copy(alpha = 0.8f))) }
    }

    fun diameter(planet: Orrery.Planet): Float {
        val base = if (planet.id == dial.picked) 20f else 11f
        val scaled = if (small) base * 0.62f else base
        val beat = if (Thirst.of(planet.moisture) == Thirst.ALARM) 1 + 0.3f * dial.beat.toFloat() else 1f
        return (scaled * beat).dp.toPx()
    }

    val blur = (if (small) 2 else 5).dp.toPx()
    for (planet in dial.planets) {
        val at = spot(planet.radius, planet.angle, small)
        val r = diameter(planet) * 0.9f + blur
        val colour = palette.level(planet.moisture)
        drawCircle(Brush.radialGradient(listOf(colour.copy(alpha = 0.8f), colour.copy(alpha = 0f)), at, r), r, at)
    }
    for (planet in dial.planets) {
        val at = spot(planet.radius, planet.angle, small)
        val r = diameter(planet) / 2
        drawCircle(palette.level(planet.moisture), r, at)
        if (planet.id == dial.picked) {
            drawCircle(Color.White, r, at, style = Stroke(2.dp.toPx()))
            val name = measurer.measure(planet.name, style, maxLines = 1, overflow = TextOverflow.Ellipsis)
            val right = at.x < size.width * 0.7f
            val x = if (right) at.x + r + 6.dp.toPx() else at.x - r - 6.dp.toPx() - name.size.width
            drawText(name, topLeft = Offset(x, at.y - name.size.height / 2f))
        }
    }
}

/** Звёздное небо планетария: мерцание медленное, звёзды те же, что на iPhone. */
@Composable
fun StarField(modifier: Modifier = Modifier) {
    val palette = LocalPalette.current
    val frames = rememberFrames()
    val stars = remember {
        var seed = 0x5EEDL
        fun next(): Double {
            seed = seed * 6_364_136_223_846_793_005L + 1_442_695_040_888_963_407L
            return (seed ushr 11).toDouble() / (1L shl 53).toDouble()
        }
        List(90) { doubleArrayOf(next(), next(), 0.6 + next() * 1.6, next()) }
    }
    Canvas(modifier.fillMaxSize().clearAndSetSemantics {}) {
        frames.value
        drawRect(
            Brush.radialGradient(
                listOf(palette.spaceGlow, palette.space),
                Offset(size.width / 2, size.height * 0.3f),
                max(size.width, size.height) * 0.8f,
            ),
        )
        val time = System.currentTimeMillis() / 1000.0
        for (star in stars) {
            val twinkle = (sin((time / 2.6 + star[3]) * 2 * PI) + 1) / 2
            val r = (star[2] * (0.7 + 0.3 * twinkle)).toFloat().dp.toPx()
            drawCircle(
                Color.White.copy(alpha = (0.25 + 0.55 * twinkle).toFloat()), r / 2,
                Offset((star[0] * size.width).toFloat(), (star[1] * size.height).toFloat()),
            )
        }
    }
}

/**
 * Планетарий сада. Растение — планета, срок полива — её год; наверху луч
 * полива. Машина времени показывает сад через N дней, парады — дни, когда
 * пить просят сразу многие, а «Проиграть месяц» превращает поливы в ноты.
 * Всегда тёмный: это ночное небо.
 */
@Composable
fun OrreryScreen(go: Go) {
    val sprout = LocalSprout.current
    SproutTheme(dark = true, dynamic = sprout.settings.dynamicColor) {
        Planetarium(go)
    }
}

@Composable
private fun Planetarium(go: Go) {
    val sprout = LocalSprout.current
    val garden = sprout.garden
    val settings = sprout.settings
    val palette = LocalPalette.current
    val scope = rememberCoroutineScope()
    val player = remember { SpheresPlayer() }
    var ahead by remember { mutableFloatStateOf(0f) }
    var picked by remember { mutableStateOf<String?>(null) }
    var playing by remember { mutableStateOf<Long?>(null) }
    var preparing by remember { mutableStateOf(false) }
    val splashed = remember { mutableStateMapOf<String, Long>() }
    val orbits = Orrery.orbits(garden.plants)
    val crossings = remember(orbits) { Orrery.crossings(orbits, Orrery.REACH) }

    fun shown(at: Long): Double {
        val started = playing ?: return ahead.toDouble()
        val done = (at - started) / 1e9 / Spheres.SECONDS
        return done.coerceIn(0.0, 1.0) * Orrery.REACH
    }

    fun glide(to: Float) {
        scope.launch { animate(ahead, to, animationSpec = Motion.enter) { value, _ -> ahead = value } }
    }

    fun stop() {
        player.stop()
        if (playing == null) return
        val reached = shown(System.nanoTime())
        playing = null
        ahead = ((reached * 4).roundedInt() / 4.0).toFloat()
    }

    fun start() {
        picked = null
        val notes = Spheres.notes(crossings, orbits.size)
        if (!settings.sounds) {
            playing = System.nanoTime()
            return
        }
        preparing = true
        scope.launch {
            player.prepare(notes)
            val began = player.start()
            preparing = false
            playing = began ?: System.nanoTime()
        }
    }

    LaunchedEffect(playing) {
        val started = playing ?: return@LaunchedEffect
        val left = Spheres.SECONDS - (System.nanoTime() - started) / 1e9
        delay((max(left, 0.0) * 1000).toLong())
        if (playing == started) {
            playing = null
            ahead = Orrery.REACH.toFloat()
        }
    }
    DisposableEffect(Unit) { onDispose { player.stop() } }

    SubScreen(Lang.text("Планетарий"), onBack = go::back, walk = Walk.ORRERY, backdrop = { StarField() }) { inner ->
        Column(
            Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(inner)
                .padding(horizontal = 16.dp)
                .padding(top = 8.dp, bottom = 40.dp),
            verticalArrangement = Arrangement.spacedBy(26.dp),
        ) {
            Box(Modifier.fillMaxWidth().aspectRatio(1f).hintSpot(Hint.Target.ORRERY_DIAL)) {
                Planets(orbits, crossings, picked, splashed, ::shown) { id ->
                    picked = if (id == null || id == picked) null else id
                    if (id != null) Feel.pick()
                }
                Icon(
                    painterResource(R.drawable.ic_water_drop_fill), null, tint = palette.water,
                    modifier = Modifier
                        .align(Alignment.TopCenter)
                        .padding(4.dp)
                        .size(16.dp)
                        .hintSpot(Hint.Target.ORRERY_GATE),
                )
            }
            Card(picked, orbits, crossings, ahead.toDouble(), playing == null && ahead == 0f, go, Modifier.hintSpot(Hint.Target.ORRERY_CARD)) { id ->
                if (sprout.bin.water(id)) {
                    val now = System.nanoTime()
                    splashed.keys.filter { now - (splashed[it] ?: 0) > 2_000_000_000L }.forEach { splashed.remove(it) }
                    splashed[id] = now
                    Feel.water()
                }
            }
            Plate(Modifier.fillMaxWidth().hintSpot(Hint.Target.ORRERY_TIME)) {
                Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        Icon(painterResource(R.drawable.ic_history), null, tint = MaterialTheme.colorScheme.primary)
                        Text(Lang.text("Машина времени"), style = MaterialTheme.typography.titleMedium, modifier = Modifier.weight(1f))
                        Text(
                            if (ahead == 0f) Lang.text("Сейчас") else Stats.day(ahead.toDouble().roundedInt()),
                            style = MaterialTheme.typography.bodyMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        Icon(painterResource(R.drawable.ic_schedule), null, Modifier.size(18.dp), tint = MaterialTheme.colorScheme.onSurfaceVariant)
                        Slider(
                            value = ahead,
                            onValueChange = { next ->
                                val low = min(ahead, next).toDouble()
                                val high = max(ahead, next).toDouble()
                                if (crossings.any { it.day > low && it.day <= high }) Feel.pick()
                                ahead = next
                            },
                            valueRange = 0f..Orrery.REACH.toFloat(),
                            steps = (Orrery.REACH * 4).toInt() - 1,
                            enabled = playing == null,
                            modifier = Modifier
                                .weight(1f)
                                .semantics { contentDescription = Lang.text("Машина времени") },
                        )
                        Text(Lang.format("%lld дней", Orrery.REACH.toInt()), style = MaterialTheme.typography.labelSmall)
                    }
                    AnimatedVisibility(ahead > 0f && playing == null) {
                        TextButton(onClick = { glide(0f) }) { Text(Lang.text("Вернуться в сейчас")) }
                    }
                }
            }
            Column(Modifier.hintSpot(Hint.Target.ORRERY_PLAY), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Button(
                    onClick = { if (playing != null) stop() else start() },
                    enabled = !preparing && orbits.isNotEmpty(),
                    modifier = Modifier.fillMaxWidth().height(56.dp),
                ) {
                    if (preparing) {
                        CircularProgressIndicator(Modifier.size(20.dp), strokeWidth = 2.dp)
                    } else {
                        Icon(painterResource(if (playing == null) R.drawable.ic_play_arrow_fill else R.drawable.ic_stop_fill), null)
                    }
                    Text(
                        if (playing == null) Lang.text("Проиграть месяц") else Lang.text("Остановить"),
                        Modifier.padding(start = 8.dp),
                        style = MaterialTheme.typography.titleMedium,
                    )
                }
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    Icon(
                        painterResource(if (settings.sounds) R.drawable.ic_music_note else R.drawable.ic_volume_off), null,
                        Modifier.size(16.dp), tint = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                    Note(
                        if (settings.sounds) Lang.text("Каждый полив — нота: ближние планеты поют выше.")
                        else Lang.text("Звуки выключены в настройках — будет без музыки."),
                    )
                }
            }
            Parades(orbits, Modifier.hintSpot(Hint.Target.ORRERY_PARADES)) { day ->
                stop()
                glide(day.toFloat())
            }
        }
    }
}

@Composable
private fun Planets(
    orbits: List<Orrery.Orbit>,
    crossings: List<Orrery.Crossing>,
    picked: String?,
    splashed: Map<String, Long>,
    shown: (Long) -> Double,
    pick: (String?) -> Unit,
) {
    val garden = LocalSprout.current.garden
    val palette = LocalPalette.current
    val frames = rememberFrames()
    val measurer = rememberTextMeasurer()
    val drop = painterResource(R.drawable.ic_water_drop_fill)
    val style = MaterialTheme.typography.labelMedium.copy(color = Color.White, fontWeight = FontWeight.SemiBold)
    val label = Lang.text("Планетарий")
    val count = Lang.format("%lld растений", orbits.size)

    fun sky(nanos: Long, millis: Long): List<Orrery.Planet> =
        Orrery.sky(orbits, shown(nanos), drift(garden, millis))

    Canvas(
        Modifier
            .fillMaxSize()
            .clearAndSetSemantics { contentDescription = "$label, $count" }
            .pointerInput(orbits) {
                detectTapGestures { point ->
                    val planets = sky(System.nanoTime(), System.currentTimeMillis())
                    val area = Size(size.width.toFloat(), size.height.toFloat())
                    val nearest = planets.minByOrNull { planet ->
                        val at = planetAt(planet, area, density)
                        hypot(at.x - point.x, at.y - point.y)
                    }
                    val close = nearest?.let {
                        val at = planetAt(it, area, density)
                        hypot(at.x - point.x, at.y - point.y) < 30 * density
                    } ?: false
                    pick(if (close) nearest.id else null)
                }
            },
    ) {
        frames.value
        val nanos = System.nanoTime()
        val day = shown(nanos)
        val planets = sky(nanos, System.currentTimeMillis())
        val flashes = if (day > 0) {
            Orrery.flashes(crossings, orbits, day)
        } else {
            val radius = orbits.associate { it.id to it.radius }
            splashed.mapNotNull { (id, at) ->
                val since = (nanos - at) / 1e9 / 0.9
                val place = radius[id]
                if (since >= 1 || place == null) null else Orrery.Flash(place, 1 - since)
            }
        }
        val beat = if (Effects.still) 0.0 else (sin(nanos / 1e9 / (Motion.PULSE_PERIOD * 2) * 2 * PI) + 1) / 2
        dial(DialFrame(planets, flashes, picked, beat), palette, drop, measurer, style)
    }
}

@Composable
private fun Card(
    picked: String?,
    orbits: List<Orrery.Orbit>,
    crossings: List<Orrery.Crossing>,
    ahead: Double,
    live: Boolean,
    go: Go,
    modifier: Modifier,
    water: (String) -> Unit,
) {
    val garden = LocalSprout.current.garden
    val palette = LocalPalette.current
    val plant: Plant? = picked?.let { garden.plant(it) }
    Plate(modifier.fillMaxWidth()) {
        Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            if (plant == null) {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Icon(painterResource(R.drawable.ic_touch_app), null, Modifier.size(18.dp), tint = MaterialTheme.colorScheme.onSurfaceVariant)
                    Note(Lang.text("Нажмите на планету — узнаете, кто это."))
                }
                return@Column
            }
            val orbit = orbits.firstOrNull { it.id == plant.id }
            val level = if (live) plant.moisture else orbit?.let { Orrery.moisture(it, ahead) } ?: plant.moisture
            val next = crossings.firstOrNull { it.id == plant.id && it.day > ahead }
            Row(verticalAlignment = Alignment.CenterVertically) {
                Column(Modifier.weight(1f)) {
                    Text(plant.name, style = MaterialTheme.typography.titleMedium)
                    Note(plant.species)
                }
                Text(Stats.percent(level), style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.SemiBold, color = palette.level(level))
            }
            Note(
                if (live) plant.wateringLabel
                else next?.let { Plant.wateringLabel((it.day - ahead).roundedInt()) }.orEmpty(),
            )
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                if (live) {
                    Button(onClick = { water(plant.id) }, modifier = Modifier.weight(1f)) {
                        Icon(painterResource(R.drawable.ic_water_drop_fill), null, Modifier.size(18.dp))
                        Text(Lang.text("Полить"), Modifier.padding(start = 8.dp), maxLines = 1)
                    }
                }
                FilledTonalButton(onClick = { go.plant(plant.id) }, modifier = Modifier.weight(1f)) {
                    Icon(painterResource(R.drawable.ic_arrow_outward), null, Modifier.size(18.dp))
                    Text(Lang.text("Открыть растение"), Modifier.padding(start = 8.dp), maxLines = 1, overflow = TextOverflow.Ellipsis)
                }
            }
        }
    }
}

@Composable
private fun Parades(orbits: List<Orrery.Orbit>, modifier: Modifier, choose: (Int) -> Unit) {
    val palette = LocalPalette.current
    val parades = Orrery.parades(orbits).take(3)
    Plate(modifier.fillMaxWidth()) {
        Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(Lang.text("Парады"), style = MaterialTheme.typography.titleMedium, modifier = Modifier.weight(1f, fill = false))
                TermHint(Term.PARADE)
            }
            if (parades.isEmpty()) {
                Note(Lang.text("В ближайший месяц парадов нет: растения просят воды вразнобой."))
            }
            parades.forEachIndexed { index, parade ->
                if (index > 0) SproutDivider()
                Row(
                    Modifier
                        .fillMaxWidth()
                        .clip(RowShape)
                        .clickable { choose(parade.day) }
                        .semantics(mergeDescendants = true) {},
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(12.dp),
                ) {
                    Box(Modifier.size(34.dp).clip(CircleShape).background(palette.water), contentAlignment = Alignment.Center) {
                        Text(Lang.number(parade.ids.size), style = MaterialTheme.typography.titleSmall, color = palette.space)
                    }
                    Column(Modifier.weight(1f)) {
                        Text(Stats.day(parade.day), style = MaterialTheme.typography.bodyLarge)
                        Text(
                            Stats.names(parade.names), style = MaterialTheme.typography.bodyMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant, maxLines = 2, overflow = TextOverflow.Ellipsis,
                        )
                    }
                    Icon(painterResource(R.drawable.ic_chevron_right), null, tint = MaterialTheme.colorScheme.outline)
                }
            }
        }
    }
}
