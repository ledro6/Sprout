package com.ledro6.sprout.ui.stats

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectHorizontalDragGestures
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.TextAutoSize
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SegmentedButtonDefaults
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextLayoutResult
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.drawText
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.ledro6.sprout.design.Effects
import com.ledro6.sprout.design.LocalPalette
import com.ledro6.sprout.design.Motion
import com.ledro6.sprout.design.Palette
import com.ledro6.sprout.model.Almanac
import com.ledro6.sprout.model.Lang
import com.ledro6.sprout.model.Skeleton
import com.ledro6.sprout.model.Thirst
import com.ledro6.sprout.model.roundedInt
import com.ledro6.sprout.platform.Feel
import kotlinx.coroutines.delay
import java.time.LocalDate
import java.time.LocalTime
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.floor
import kotlin.math.log10
import kotlin.math.max
import kotlin.math.min
import kotlin.math.pow
import kotlin.math.sin

/** Цвет влажности — как у свечения карточки. */
fun Palette.level(moisture: Double): Color = when (Thirst.of(moisture)) {
    Thirst.CALM -> green
    Thirst.WARN -> warn
    Thirst.ALARM -> alarm
}

/** Цвет зоны точности: вода, оранжевый, красный, бурый. */
fun Palette.zone(zone: Almanac.Aim.Zone): Color = when (zone) {
    Almanac.Aim.Zone.EARLY -> water
    Almanac.Aim.Zone.ON_TIME -> warn
    Almanac.Aim.Zone.LAST_MOMENT -> alarm
    Almanac.Aim.Zone.DRY -> parched
}

/** Подписи статистики — те же слова, что на iPhone. */
object Stats {
    fun percent(share: Double): String = Lang.format("%lld%%", (share * 100).roundedInt())

    fun day(offset: Int): String = when {
        offset <= 0 -> Lang.text("Сегодня")
        offset == 1 -> Lang.text("Завтра")
        else -> Lang.format("Через %@", Lang.format("%lld дней", offset))
    }

    fun names(names: List<String>): String = when (names.size) {
        0 -> ""
        1 -> names[0]
        in 2..5 -> Lang.format("%1\$@ и %2\$@", names.dropLast(1).joinToString(", "), names.last())
        else -> Lang.format(
            "%1\$@ и ещё %2\$@", names.take(4).joinToString(", "),
            Lang.format("%lld растений", names.size - 4),
        )
    }

    fun hour(hour: Int): String = Skeleton.time(LocalTime.of(hour.coerceIn(0, 23), 0))

    fun time(minute: Int): String = Skeleton.time(LocalTime.of((minute / 60).coerceIn(0, 23), minute % 60))

    fun date(day: LocalDate, skeleton: String): String = Skeleton.format(day, skeleton)

    fun verdict(zone: Almanac.Aim.Zone): String = when (zone) {
        Almanac.Aim.Zone.EARLY -> Lang.text("Можно не спешить: земля ещё влажная, тени на карточке нет.")
        Almanac.Aim.Zone.ON_TIME -> Lang.text("В самый раз: карточка как раз светится оранжевым.")
        Almanac.Aim.Zone.LAST_MOMENT -> Lang.text("Поздновато: карточка уже горит красным.")
        Almanac.Aim.Zone.DRY -> Lang.text("Земля успевает пересохнуть — поливайте чуть раньше.")
    }
}

/** Выбор из нескольких — сегментами Material. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun <T> Segments(options: List<T>, picked: T, title: (T) -> String, modifier: Modifier = Modifier, pick: (T) -> Unit) {
    SingleChoiceSegmentedButtonRow(modifier.fillMaxWidth()) {
        options.forEachIndexed { index, option ->
            SegmentedButton(
                selected = option == picked,
                onClick = { if (option != picked) pick(option) },
                shape = SegmentedButtonDefaults.itemShape(index, options.size),
                icon = {},
                label = { Text(title(option), maxLines = 1, overflow = TextOverflow.Ellipsis) },
            )
        }
    }
}

/** Кольцо «Довольны — скоро пить — ждут воды»; при первом показе дорастает. */
@Composable
fun ThirstRing(now: Almanac.Now, modifier: Modifier = Modifier, center: @Composable () -> Unit) {
    val palette = LocalPalette.current
    val track = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.08f)
    val total = max(now.count, 1).toFloat()
    val calm by animateFloatAsState(now.calm / total, Motion.number, label = "довольны")
    val warn by animateFloatAsState(now.warn / total, Motion.number, label = "скоро")
    val alarm by animateFloatAsState(now.alarm / total, Motion.number, label = "ждут")
    val grown = remember { Animatable(if (Effects.still) 1f else 0f) }
    LaunchedEffect(Unit) {
        delay(150)
        grown.animateTo(1f, Motion.enter)
    }
    Box(modifier.size(118.dp), contentAlignment = Alignment.Center) {
        Canvas(Modifier.fillMaxSize().padding(7.dp)) {
            val stroke = Stroke(14.dp.toPx(), cap = StrokeCap.Butt)
            drawArc(track, 0f, 360f, false, style = stroke)
            var start = 0f
            for ((share, colour) in listOf(calm to palette.green, warn to palette.warn, alarm to palette.alarm)) {
                if (share > 0f) drawArc(colour, -90f + 360f * start, 360f * share * grown.value, false, style = stroke)
                start += share
            }
        }
        center()
    }
}

/** Влажность каждого растения — столбиком, от самого сухого. */
@Composable
fun MoistureStrip(levels: List<Double>, modifier: Modifier = Modifier) {
    val palette = LocalPalette.current
    Canvas(modifier.fillMaxWidth().height(34.dp).clearAndSetSemantics {}) {
        val count = max(levels.size, 1)
        val gap = (if (count > 40) 1 else 2).dp.toPx()
        val width = max((size.width - gap * (count - 1)) / count, 1f)
        levels.forEachIndexed { index, level ->
            val tall = max(size.height * level.toFloat().coerceIn(0f, 1f), width)
            drawRoundRect(
                palette.level(level),
                Offset(index * (width + gap), size.height - tall),
                Size(width, tall),
                CornerRadius(width / 2),
            )
        }
    }
}

/** Число, подпись и, если есть, заметка со стрелкой. */
@Composable
fun StatTile(value: String, caption: String, modifier: Modifier = Modifier, note: String? = null, tone: Color? = null, icon: Int? = null) {
    Column(modifier.semantics(mergeDescendants = true) {}, verticalArrangement = Arrangement.spacedBy(2.dp)) {
        // Длинная дата («23 сентября») мельчает, а не обрывается многоточием.
        val style = MaterialTheme.typography.headlineSmall
        Text(
            value,
            style = style,
            fontWeight = FontWeight.SemiBold,
            color = MaterialTheme.colorScheme.onSurface,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            autoSize = TextAutoSize.StepBased(minFontSize = 13.sp, maxFontSize = style.fontSize),
        )
        Text(caption, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
        if (note != null) {
            val colour = tone ?: MaterialTheme.colorScheme.onSurfaceVariant
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(3.dp)) {
                if (icon != null) Icon(painterResource(icon), null, tint = colour, modifier = Modifier.size(14.dp))
                Text(note, style = MaterialTheme.typography.bodySmall, color = colour)
            }
        }
    }
}

/** Две плитки в ряд. */
@Composable
fun TileRow(content: @Composable (Modifier) -> Unit) {
    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        content(Modifier.weight(1f))
    }
}

/** Доли зон одной полосой. */
@Composable
fun ZoneBar(aim: Almanac.Aim) {
    val palette = LocalPalette.current
    Row(
        Modifier
            .fillMaxWidth()
            .height(12.dp)
            .clip(CircleShape)
            .background(MaterialTheme.colorScheme.onSurface.copy(alpha = 0.08f))
            .clearAndSetSemantics {},
        horizontalArrangement = Arrangement.spacedBy(2.dp),
    ) {
        for (zone in Almanac.Aim.Zone.entries) {
            val share = aim.share(zone)
            if (share > 0) Box(Modifier.weight(share.toFloat()).fillMaxSize().background(palette.zone(zone)))
        }
    }
}

@Composable
fun ZoneRow(zone: Almanac.Aim.Zone, aim: Almanac.Aim) {
    val palette = LocalPalette.current
    Row(
        Modifier.fillMaxWidth().semantics(mergeDescendants = true) {},
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Box(Modifier.size(10.dp).clip(CircleShape).background(palette.zone(zone)))
        Column(Modifier.weight(1f)) {
            Text(zone.title, style = MaterialTheme.typography.bodyLarge, color = MaterialTheme.colorScheme.onSurface)
            Text(zone.range, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
        Column(horizontalAlignment = Alignment.End) {
            Text(Stats.percent(aim.share(zone)), style = MaterialTheme.typography.titleSmall, color = MaterialTheme.colorScheme.onSurface)
            Text(Lang.format("%lld поливов", aim.count(zone)), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
    }
}

/** Часы привычек: лепесток на каждый час, длиннее — больше поливов. */
@Composable
fun HourClock(hours: List<Int>, modifier: Modifier = Modifier) {
    val measurer = rememberTextMeasurer()
    val accent = MaterialTheme.colorScheme.primary
    val ink = MaterialTheme.colorScheme.onSurface
    val style = MaterialTheme.typography.labelSmall.copy(color = MaterialTheme.colorScheme.onSurfaceVariant)
    val marks = remember(style) { listOf(0, 6, 12, 18).map { it to measurer.measure("$it", style) } }
    Canvas(modifier.aspectRatio(1f).clearAndSetSemantics {}) {
        val side = min(size.width, size.height)
        val middle = center
        val inner = side * 0.2f
        val outer = side * 0.5f - 12.dp.toPx()
        val most = max(hours.maxOrNull() ?: 0, 1)
        val peak = hours.maxOrNull() ?: 0
        drawCircle(ink.copy(alpha = 0.12f), inner, middle, style = Stroke(1.dp.toPx()))
        for (hour in 0 until 24) {
            val angle = hour / 24.0 * 2 * PI - PI / 2
            val dx = cos(angle).toFloat()
            val dy = sin(angle).toFloat()
            val count = hours.getOrElse(hour) { 0 }
            val reach = max(inner + (outer - inner) * count / most, inner + 4.dp.toPx())
            val from = inner + 3.dp.toPx()
            val colour = when {
                count == 0 -> ink.copy(alpha = 0.1f)
                count == peak -> accent
                else -> accent.copy(alpha = 0.45f)
            }
            drawLine(colour, middle + Offset(dx * from, dy * from), middle + Offset(dx * reach, dy * reach), side / 34, StrokeCap.Round)
        }
        for ((hour, layout) in marks) {
            val angle = hour / 24.0 * 2 * PI - PI / 2
            val far = outer + 8.dp.toPx()
            val at = middle + Offset(cos(angle).toFloat() * far, sin(angle).toFloat() * far)
            drawText(layout, topLeft = at - Offset(layout.size.width / 2f, layout.size.height / 2f))
        }
    }
}

/** Поливы по дням недели — с первого дня недели страны. */
@Composable
fun WeekBars(days: List<Almanac.Weekday>) {
    val accent = MaterialTheme.colorScheme.primary
    val most = max(days.maxOfOrNull { it.count } ?: 0, 1)
    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.Bottom) {
        for (day in days) {
            val share by animateFloatAsState(day.count.toFloat() / most, Motion.number, label = "день недели")
            val colour = when {
                day.count == most && day.count > 0 -> accent
                day.count == 0 -> accent.copy(alpha = 0.12f)
                else -> accent.copy(alpha = 0.45f)
            }
            Column(
                Modifier
                    .weight(1f)
                    .clearAndSetSemantics { contentDescription = "${day.name}, ${Lang.format("%lld поливов", day.count)}" },
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(5.dp),
            ) {
                Box(Modifier.fillMaxWidth().height(54.dp), contentAlignment = Alignment.BottomCenter) {
                    Box(
                        Modifier
                            .fillMaxWidth()
                            .height(max(54f * share, 6f).dp)
                            .clip(CircleShape)
                            .background(colour),
                    )
                }
                Text(
                    day.symbol,
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    maxLines = 1,
                    overflow = TextOverflow.Clip,
                )
            }
        }
    }
}

/** Календарь поливов: квадрат — день, гуще цвет — больше поливов. */
@Composable
fun WateringCalendar(cells: List<Almanac.Cell>, colour: Color, picked: LocalDate?, pick: (LocalDate?) -> Unit) {
    val ink = MaterialTheme.colorScheme.onSurface
    val most = max(cells.maxOfOrNull { it.count } ?: 0, 1)
    val today = cells.lastOrNull()?.day
    val shape = RoundedCornerShape(3.dp)
    val total = cells.sumOf { it.count }
    val label = Lang.text("Календарь поливов")
    Row(
        Modifier
            .fillMaxWidth()
            .clearAndSetSemantics { contentDescription = "$label, ${Lang.format("%lld поливов", total)}" },
        horizontalArrangement = Arrangement.spacedBy(3.dp),
        verticalAlignment = Alignment.Top,
    ) {
        for (week in cells.chunked(7)) {
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
                for (cell in week) {
                    val fill = if (cell.count == 0) ink.copy(alpha = 0.07f)
                    else colour.copy(alpha = 0.3f + 0.7f * cell.count / most)
                    val ring = when (cell.day) {
                        picked -> Modifier.border(1.5.dp, ink, shape)
                        today -> Modifier.border(1.5.dp, ink.copy(alpha = 0.35f), shape)
                        else -> Modifier
                    }
                    Box(
                        Modifier
                            .fillMaxWidth()
                            .aspectRatio(1f)
                            .clip(shape)
                            .background(fill)
                            .then(ring)
                            .clickable {
                                pick(if (picked == cell.day) null else cell.day)
                                Feel.pick()
                            },
                    )
                }
            }
        }
    }
}

/** Шаг делений оси: 1, 2, 5, 10… — около `count` делений до `top`. */
fun ticks(top: Double, count: Int = 3): List<Int> {
    if (top <= 0) return listOf(0)
    val rough = top / count
    val power = 10.0.pow(floor(log10(max(rough, 1.0))))
    val step = listOf(1.0, 2.0, 5.0, 10.0).map { it * power }.first { it >= rough }.roundedInt().coerceAtLeast(1)
    return (0..top.toInt() step step).toList()
}

/**
 * Столбики с осью слева: касание выбирает столбик, ведение пальцем — листает
 * их, повторное касание снимает выбор. Высота — от нуля: обрезанная снизу
 * ось раздувает разницу.
 */
@Composable
fun ColumnChart(
    counts: List<Int>,
    colour: Color,
    picked: Int?,
    pick: (Int?) -> Unit,
    label: (Int) -> String?,
    description: String,
    modifier: Modifier = Modifier,
    height: Dp = 170.dp,
    average: Double? = null,
) {
    val measurer = rememberTextMeasurer()
    val density = LocalDensity.current
    val ink = MaterialTheme.colorScheme.onSurface
    val style = MaterialTheme.typography.labelSmall.copy(color = MaterialTheme.colorScheme.onSurfaceVariant)
    val top = (counts.maxOrNull() ?: 0) + 1
    val marks = remember(top, style) { ticks(top.toDouble()).map { it to measurer.measure("$it", style) } }
    val axis = (marks.maxOfOrNull { it.second.size.width } ?: 0) + with(density) { 6.dp.toPx() }
    val labels = remember(counts.size, style, label) {
        counts.indices.mapNotNull { index -> label(index)?.let { index to measurer.measure(it, style) } }
    }
    val below = with(density) { 18.dp.toPx() }
    val current by rememberUpdatedState(picked)
    val choose by rememberUpdatedState(pick)

    fun slot(x: Float, width: Float): Int? {
        if (counts.isEmpty()) return null
        val inside = (x - axis) / (width - axis) * counts.size
        return floor(inside).toInt().coerceIn(0, counts.size - 1)
    }

    Canvas(
        modifier
            .fillMaxWidth()
            .height(height)
            .semantics { contentDescription = description }
            .pointerInput(counts.size, axis) {
                detectTapGestures { at ->
                    val index = slot(at.x, size.width.toFloat())
                    choose(if (index == current) null else index)
                }
            }
            .pointerInput(counts.size, axis) {
                detectHorizontalDragGestures(
                    onDragStart = { at -> choose(slot(at.x, size.width.toFloat())) },
                ) { change, _ ->
                    val index = slot(change.position.x, size.width.toFloat())
                    if (index != current) choose(index)
                }
            },
    ) {
        val plot = size.height - below
        val width = size.width - axis
        val step = width / max(counts.size, 1)
        fun y(value: Double) = plot - (plot * value / top).toFloat()
        for ((value, layout) in marks) {
            val at = y(value.toDouble())
            drawLine(ink.copy(alpha = 0.08f), Offset(axis, at), Offset(size.width, at), 1.dp.toPx())
            drawText(layout, topLeft = Offset(0f, (at - layout.size.height / 2f).coerceIn(0f, plot - layout.size.height)))
        }
        val bar = max(step * 0.72f, 2f)
        val round = CornerRadius(min(4.dp.toPx(), bar / 2))
        counts.forEachIndexed { index, count ->
            if (count <= 0) return@forEachIndexed
            val left = axis + step * index + (step - bar) / 2
            val tall = plot - y(count.toDouble())
            val shade = if (picked == null || picked == index) colour else colour.copy(alpha = 0.3f)
            drawRoundRect(shade, Offset(left, plot - tall), Size(bar, tall), round)
        }
        if (average != null && average > 0) {
            val at = y(average)
            drawLine(
                ink.copy(alpha = 0.35f), Offset(axis, at), Offset(size.width, at), 1.dp.toPx(),
                pathEffect = PathEffect.dashPathEffect(floatArrayOf(4.dp.toPx(), 4.dp.toPx())),
            )
        }
        axisLabels(labels, axis, step, plot + 4.dp.toPx())
    }
}

/** Подписи под столбиками: по центру своего места, без наложений и за краем. */
private fun DrawScope.axisLabels(labels: List<Pair<Int, TextLayoutResult>>, axis: Float, step: Float, top: Float) {
    var free = axis
    for ((index, layout) in labels) {
        val middle = axis + step * index + step / 2
        val left = (middle - layout.size.width / 2f).coerceIn(axis, size.width - layout.size.width)
        if (left < free) continue
        drawText(layout, topLeft = Offset(left, top))
        free = left + layout.size.width + 4.dp.toPx()
    }
}

/** Сколько воды было в земле при поливе — десять корзин по 10%, цвета зон. */
@Composable
fun AimHistogram(bins: List<Int>, typical: Double) {
    val palette = LocalPalette.current
    val measurer = rememberTextMeasurer()
    val ink = MaterialTheme.colorScheme.onSurface
    val style = MaterialTheme.typography.labelSmall.copy(color = MaterialTheme.colorScheme.onSurfaceVariant)
    val marks = remember(style) { (0..100 step 20).map { it to measurer.measure(Stats.percent(it / 100.0), style) } }
    Canvas(Modifier.fillMaxWidth().height(110.dp).clearAndSetSemantics {}) {
        val below = 18.dp.toPx()
        val plot = size.height - below
        val most = max(bins.maxOrNull() ?: 0, 1)
        fun x(percent: Double) = (size.width * percent / 100).toFloat()
        for ((value, _) in marks) {
            drawLine(ink.copy(alpha = 0.08f), Offset(x(value.toDouble()), 0f), Offset(x(value.toDouble()), plot), 1.dp.toPx())
        }
        bins.forEachIndexed { index, count ->
            if (count <= 0) return@forEachIndexed
            val left = x(index * 10 + 0.8)
            val right = x(index * 10 + 10 - 0.8)
            val tall = plot * 0.94f * count / most
            val zone = Almanac.Aim.zone((index + 0.5) / 10)
            drawRoundRect(palette.zone(zone), Offset(left, plot - tall), Size(right - left, tall), CornerRadius(3.dp.toPx()))
        }
        val at = x(typical * 100)
        drawLine(
            ink.copy(alpha = 0.7f), Offset(at, 0f), Offset(at, plot), 1.5.dp.toPx(),
            pathEffect = PathEffect.dashPathEffect(floatArrayOf(3.dp.toPx(), 3.dp.toPx())),
        )
        for ((value, layout) in marks) {
            val left = (x(value.toDouble()) - layout.size.width / 2f).coerceIn(0f, size.width - layout.size.width)
            drawText(layout, topLeft = Offset(left, plot + 4.dp.toPx()))
        }
    }
}

/** Точки поливов: когда и сколько воды оставалось; пунктиры — пороги 20% и 40%. */
@Composable
fun LevelChart(points: List<Pair<Long, Double>>, first: String, last: String, modifier: Modifier = Modifier) {
    val palette = LocalPalette.current
    val measurer = rememberTextMeasurer()
    val ink = MaterialTheme.colorScheme.onSurface
    val style = MaterialTheme.typography.labelSmall.copy(color = MaterialTheme.colorScheme.onSurfaceVariant)
    val marks = remember(style) { listOf(0, 20, 40, 100).map { it to measurer.measure(Stats.percent(it / 100.0), style) } }
    val ends = remember(first, last, style) { measurer.measure(first, style) to measurer.measure(last, style) }
    Canvas(modifier.fillMaxWidth().height(170.dp).clearAndSetSemantics {}) {
        val axis = (marks.maxOf { it.second.size.width }) + 6.dp.toPx()
        val below = 18.dp.toPx()
        val plot = size.height - below
        val pad = 8.dp.toPx()
        fun y(percent: Double) = pad + (plot - 2 * pad) * (1 - percent / 100).toFloat()
        for ((value, layout) in marks) {
            val at = y(value.toDouble())
            drawLine(ink.copy(alpha = 0.08f), Offset(axis, at), Offset(size.width, at), 1.dp.toPx())
            drawText(layout, topLeft = Offset(0f, at - layout.size.height / 2f))
        }
        for ((value, colour) in listOf(20.0 to palette.alarm, 40.0 to palette.warn)) {
            drawLine(
                colour.copy(alpha = 0.6f), Offset(axis, y(value)), Offset(size.width, y(value)), 1.dp.toPx(),
                pathEffect = PathEffect.dashPathEffect(floatArrayOf(4.dp.toPx(), 4.dp.toPx())),
            )
        }
        val from = points.minOf { it.first }
        val to = points.maxOf { it.first }
        val span = (to - from).coerceAtLeast(1)
        val dot = 4.7.dp.toPx()
        val left = axis + dot + 2.dp.toPx()
        val right = size.width - dot - 2.dp.toPx()
        for ((at, level) in points) {
            val x = if (to == from) (left + right) / 2 else left + (right - left) * (at - from).toFloat() / span
            drawCircle(palette.zone(Almanac.Aim.zone(level)), dot, Offset(x, y(level * 100)))
        }
        drawText(ends.first, topLeft = Offset(axis, plot + 4.dp.toPx()))
        if (to != from) drawText(ends.second, topLeft = Offset(size.width - ends.second.size.width, plot + 4.dp.toPx()))
    }
}

/** Точка с подписью и числом — легенда кольца. */
@Composable
fun Legend(colour: Color, count: Int, title: String, modifier: Modifier = Modifier) {
    Row(
        modifier.fillMaxWidth().semantics(mergeDescendants = true) {},
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Box(Modifier.size(10.dp).clip(CircleShape).background(colour))
        Text(
            title,
            style = MaterialTheme.typography.bodyLarge,
            color = MaterialTheme.colorScheme.onSurface,
            maxLines = 2,
            overflow = TextOverflow.Ellipsis,
            modifier = Modifier.weight(1f),
        )
        Spacer(Modifier.width(4.dp))
        Text(Lang.number(count), style = MaterialTheme.typography.titleMedium, color = MaterialTheme.colorScheme.onSurface)
    }
}

/** Мелкий пояснительный текст групп. */
@Composable
fun Note(text: String, modifier: Modifier = Modifier, style: TextStyle = MaterialTheme.typography.bodyMedium) {
    Text(text, modifier, style = style, color = MaterialTheme.colorScheme.onSurfaceVariant)
}
