package com.ledro6.sprout.ui.stats

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.produceState
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.ledro6.sprout.R
import com.ledro6.sprout.app.LocalSprout
import com.ledro6.sprout.design.LocalPalette
import com.ledro6.sprout.model.Almanac
import com.ledro6.sprout.model.Garden
import com.ledro6.sprout.model.Hint
import com.ledro6.sprout.model.Lang
import com.ledro6.sprout.model.Term
import com.ledro6.sprout.model.Walk
import com.ledro6.sprout.platform.Feel
import com.ledro6.sprout.ui.Go
import com.ledro6.sprout.ui.components.Plate
import com.ledro6.sprout.ui.components.RowShape
import com.ledro6.sprout.ui.components.SproutDivider
import com.ledro6.sprout.ui.components.SproutGroup
import com.ledro6.sprout.ui.components.TabScreen
import com.ledro6.sprout.ui.components.TermHint
import com.ledro6.sprout.ui.components.enter
import com.ledro6.sprout.ui.components.hintSpot
import com.ledro6.sprout.model.Days
import kotlinx.coroutines.delay
import java.time.LocalDate

/** Период статистики — общий для обзора и экрана растения. */
object StatsPeriod {
    var period by mutableStateOf(Almanac.Period.WEEK)
}

/** Список растений в статистике: чаще, реже, суше. */
enum class Board(private val key: String) {
    MOST("Чаще всех"), LEAST("Реже всех"), DRIEST("Суше всех");

    val title: String get() = Lang.text(key)
}

/**
 * Статистика сада. Пересчитывается при поливе, смене периода и раз в три
 * секунды: сад сохнет, «сейчас» и прогноз живые, но не мелькают.
 */
@Composable
fun StatsScreen(go: Go, outer: PaddingValues) {
    val sprout = LocalSprout.current
    val garden = sprout.garden
    val settings = sprout.settings
    val period = StatsPeriod.period
    val first = remember { count(garden, period) }
    val book by produceState(first, period, garden.log, garden.roster) {
        while (true) {
            value = count(garden, period)
            delay(3_000)
        }
    }
    val colour = LocalPalette.current.swatch(settings.waveTint)

    TabScreen(Lang.text("Статистика"), Walk.STATS, onSettings = go::settings) { inner ->
        Column(
            Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(top = inner.calculateTopPadding())
                .padding(horizontal = 16.dp)
                .padding(top = 8.dp, bottom = outer.calculateBottomPadding() + 28.dp),
            verticalArrangement = Arrangement.spacedBy(26.dp),
        ) {
            if (book.plants.isEmpty() && book.total == 0) {
                Blank()
                return@Column
            }
            Segments(Almanac.Period.entries, period, { it.title }, Modifier.hintSpot(Hint.Target.STATS_PERIOD)) {
                StatsPeriod.period = it
                Feel.pick()
            }
            Now(book.now, Modifier.hintSpot(Hint.Target.STATS_NOW))
            OrreryTeaser(Modifier.hintSpot(Hint.Target.STATS_ORRERY), onClick = go::orrery)
            Summary(book, Modifier.hintSpot(Hint.Target.STATS_SUM))
            Waterings(book, colour)
            Aim(book.aim, Lang.text("Точность полива"), Modifier.hintSpot(Hint.Target.STATS_AIM), histogram = true)
            Habits(book)
            Calendar(book, colour, Modifier.hintSpot(Hint.Target.STATS_CALENDAR))
            if (book.records.total > 0) Records(book.records)
            Forecast(book, Modifier.hintSpot(Hint.Target.STATS_AHEAD))
            val rooms = book.rooms.filter { it.plants > 0 }.sortedBy { it.moisture ?: 1.0 }
            if (rooms.isNotEmpty()) Rooms(rooms)
            if (book.plants.isNotEmpty()) Plants(book, go, Modifier.hintSpot(Hint.Target.STATS_PLANTS))
        }
    }
}

private fun count(garden: Garden, period: Almanac.Period): Almanac =
    Almanac.of(garden.log, garden.rooms, period, garden.since, System.currentTimeMillis(), Days.current)

@Composable
private fun Blank() {
    Plate(Modifier.fillMaxWidth().enter(1)) {
        Column(
            Modifier.padding(horizontal = 28.dp, vertical = 40.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(14.dp),
        ) {
            Icon(painterResource(R.drawable.ic_bar_chart), null, tint = MaterialTheme.colorScheme.outline, modifier = Modifier.size(30.dp))
            Text(
                Lang.text("В саду пока пусто. Посадите первое растение во вкладке «Добавить» — и здесь появятся цифры."),
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                textAlign = TextAlign.Center,
            )
        }
    }
}

@Composable
private fun Now(state: Almanac.Now, modifier: Modifier) {
    val palette = LocalPalette.current
    SproutGroup(Lang.text("Сейчас"), modifier) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(18.dp)) {
            ThirstRing(state) {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Text(Stats.percent(state.content), style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.SemiBold)
                    Text(Lang.text("Довольны"), style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            }
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Legend(palette.green, state.calm, Lang.text("Довольны"))
                Legend(palette.warn, state.warn, Lang.text("Скоро пить"))
                Legend(palette.alarm, state.alarm, Lang.text("Ждут воды"))
            }
        }
        MoistureStrip(state.levels)
        state.average?.let { average ->
            Row(verticalAlignment = Alignment.CenterVertically) {
                var line = Lang.format("Средняя влажность — %@.", Stats.percent(average))
                state.driest?.let { line += " " + Lang.format("Суше всех — %@.", it) }
                Note(line, Modifier.weight(1f, fill = false))
                TermHint(Term.MOISTURE)
            }
        }
    }
}

/** Вход в планетарий: маленький живой циферблат и пара слов. */
@Composable
fun OrreryTeaser(modifier: Modifier = Modifier, onClick: () -> Unit) {
    val palette = LocalPalette.current
    Plate(modifier.fillMaxWidth(), onClick = onClick) {
        Row(Modifier.padding(16.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(14.dp)) {
            Box(Modifier.size(92.dp).clip(CircleShape).background(palette.space)) {
                LiveDial(Modifier.fillMaxSize(), small = true)
            }
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    Text(Lang.text("Планетарий сада"), style = MaterialTheme.typography.titleMedium)
                    Icon(painterResource(R.drawable.ic_auto_awesome), null, tint = MaterialTheme.colorScheme.primary, modifier = Modifier.size(16.dp))
                }
                Note(Lang.text("Растения кружат по орбитам полива. Послушайте, как звучит месяц."))
            }
            Icon(painterResource(R.drawable.ic_chevron_right), null, tint = MaterialTheme.colorScheme.outline)
        }
    }
}

@Composable
private fun Summary(book: Almanac, modifier: Modifier) {
    val palette = LocalPalette.current
    val change = book.change
    SproutGroup(Lang.text("Итог"), modifier) {
        TileRow { weight ->
            StatTile(
                Lang.number(book.total), Lang.text("Поливов"), weight,
                note = change?.let {
                    when {
                        it == 0 -> Lang.text("как в прошлый раз")
                        it > 0 -> Lang.format("%@ к прошлому периоду", "+$it")
                        else -> Lang.format("%@ к прошлому периоду", "−${-it}")
                    }
                },
                tone = change?.takeIf { it != 0 }?.let { if (it > 0) palette.green else palette.warn },
                icon = change?.takeIf { it != 0 }?.let { if (it > 0) R.drawable.ic_north_east else R.drawable.ic_south_east },
            )
            StatTile(Lang.format("%1\$lld из %2\$lld", book.active, book.length), Lang.text("Дней с поливом"), weight)
        }
        TileRow { weight ->
            StatTile(
                Lang.number(book.streak), Lang.text("Череда, дней"), weight,
                note = if (book.best > 0) Lang.format("лучшая — %lld", book.best) else null,
            )
            StatTile(
                if (book.aim.known > 0) Stats.percent(book.aim.share(Almanac.Aim.Zone.ON_TIME)) else "—",
                Lang.text("Вовремя"), weight,
            )
        }
    }
}

@Composable
private fun Waterings(book: Almanac, colour: androidx.compose.ui.graphics.Color) {
    var picked by rememberSaveable(book.period, book.bars.size) { mutableStateOf<Int?>(null) }
    val bar = picked?.let { book.bars.getOrNull(it) }
    val average = book.total.toDouble() / maxOf(book.bars.size, 1)
    val caption = if (bar != null) {
        val date = if (book.byMonth) Stats.date(bar.start, "MMMMy") else Stats.date(bar.start, "dMMMM")
        if (bar.count == 0) Lang.format("%@ — без поливов", date)
        else Lang.format("%1\$@ — %2\$@", date, Lang.format("%lld поливов", bar.count))
    } else {
        val figure = Lang.decimal(average)
        if (book.byMonth) Lang.format("В среднем %@ в месяц", figure) else Lang.format("В среднем %@ в день", figure)
    }
    SproutGroup(Lang.text("Поливы")) {
        Note(caption)
        AnimatedContent(book.total == 0, transitionSpec = { fadeIn() togetherWith fadeOut() }, label = "поливы") { empty ->
            if (empty) {
                Text(Lang.text("За этот период поливов не было."), style = MaterialTheme.typography.bodyLarge)
            } else {
                val stride = when {
                    book.byMonth -> maxOf(1, book.bars.size / 6)
                    book.period == Almanac.Period.WEEK -> 1
                    else -> 7
                }
                ColumnChart(
                    counts = book.bars.map { it.count },
                    colour = colour,
                    picked = picked,
                    pick = { index ->
                        if (index != picked) {
                            picked = index
                            if (index != null) Feel.pick()
                        }
                    },
                    label = { index ->
                        if (index % stride != 0) null else book.bars.getOrNull(index)?.let { mark(book, it.start) }
                    },
                    description = caption,
                    average = average,
                )
            }
        }
    }
}

private fun mark(book: Almanac, day: LocalDate): String = when {
    book.byMonth && book.bars.size > 12 -> Stats.date(day, "MMMyy")
    book.byMonth -> Stats.date(day, "LLLLL")
    book.period == Almanac.Period.WEEK -> Stats.date(day, "EEEEE")
    else -> Stats.date(day, "dMMM")
}

/** Сколько воды было в земле, когда поливали: обычно, зоны и их доли. */
@Composable
fun Aim(aim: Almanac.Aim, title: String, modifier: Modifier = Modifier, histogram: Boolean = false) {
    SproutGroup(title, modifier) {
        val typical = aim.typical
        if (typical == null) {
            Note(Lang.text("Полейте растение — и здесь появится, сколько воды было в земле в этот миг."))
            return@SproutGroup
        }
        Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(
                    Lang.format("Обычно — при %@ воды в земле", Stats.percent(typical)),
                    style = MaterialTheme.typography.titleMedium,
                    modifier = Modifier.weight(1f, fill = false),
                )
                TermHint(Term.ACCURACY)
            }
            Note(Stats.verdict(Almanac.Aim.zone(typical)))
        }
        if (histogram) AimHistogram(aim.bins, typical)
        ZoneBar(aim)
        for (zone in Almanac.Aim.Zone.entries) ZoneRow(zone, aim)
    }
}

@Composable
private fun Habits(book: Almanac) {
    SproutGroup(Lang.text("Привычки")) {
        if (book.total == 0) {
            Note(Lang.text("Когда появятся поливы, здесь будет видно, в какие часы и дни вы поливаете."))
            return@SproutGroup
        }
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(16.dp)) {
            HourClock(book.hours, Modifier.size(150.dp))
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(16.dp)) {
                StatTile(book.peakHour?.let { Stats.hour(it) } ?: "—", Lang.text("Любимый час"))
                StatTile(book.peakDay?.name ?: "—", Lang.text("Любимый день"))
            }
        }
        WeekBars(book.weekdays)
    }
}

@Composable
private fun Calendar(book: Almanac, colour: androidx.compose.ui.graphics.Color, modifier: Modifier) {
    var picked by remember { mutableStateOf<LocalDate?>(null) }
    val cell = picked?.let { day -> book.cells.firstOrNull { it.day == day } }
    val caption = if (cell == null) Lang.text("Квадрат — день: чем гуще цвет, тем больше поливов.")
    else Lang.format("%1\$@: %2\$@", Stats.date(cell.day, "dMMMM"), Lang.format("%lld поливов", cell.count))
    SproutGroup(Lang.text("Календарь поливов"), modifier) {
        Note(caption)
        WateringCalendar(book.cells, colour, picked) { picked = it }
    }
}

@Composable
private fun Records(records: Almanac.Records) {
    SproutGroup(Lang.text("Рекорды")) {
        TileRow { weight ->
            StatTile(
                records.busiest?.let { Lang.number(it.count) } ?: "—", Lang.text("Больше всего за день"), weight,
                note = records.busiest?.let { Stats.date(it.day, "dMMMMy") },
            )
            StatTile(Lang.format("%lld дней", records.longest), Lang.text("Самая длинная череда"), weight)
        }
        TileRow { weight ->
            StatTile(records.earliest?.let { Stats.time(it) } ?: "—", Lang.text("Самый ранний полив"), weight)
            StatTile(records.latest?.let { Stats.time(it) } ?: "—", Lang.text("Самый поздний полив"), weight)
        }
    }
}

@Composable
private fun Forecast(book: Almanac, modifier: Modifier) {
    val palette = LocalPalette.current
    var picked by remember { mutableStateOf<Int?>(null) }
    val day = picked?.let { book.ahead.getOrNull(it) }
    val caption = if (day != null) {
        Lang.format("%1\$@: %2\$@", Stats.day(day.offset), if (day.count == 0) Lang.text("никто не ждёт") else Stats.names(day.names))
    } else {
        Lang.format("Сегодня ждут воды: %@", Lang.format("%lld растений", book.ahead.firstOrNull()?.count ?: 0))
    }
    SproutGroup(Lang.text("Прогноз"), modifier) {
        Note(caption)
        ColumnChart(
            counts = book.ahead.map { it.count },
            colour = palette.water,
            picked = picked,
            pick = { index ->
                if (index != picked) {
                    picked = index
                    if (index != null) Feel.pick()
                }
            },
            label = { index ->
                when (index) {
                    0 -> Lang.text("Сегодня")
                    7, Almanac.HORIZON - 1 -> "+$index"
                    else -> null
                }
            },
            description = caption,
            height = 140.dp,
        )
    }
}

@Composable
private fun Rooms(rooms: List<Almanac.RoomLine>) {
    val palette = LocalPalette.current
    SproutGroup(Lang.text("Комнаты")) {
        rooms.forEachIndexed { index, room ->
            if (index > 0) SproutDivider()
            val level = room.moisture ?: 0.0
            val details = listOfNotNull(
                Lang.format("%lld растений", room.plants),
                Lang.format("%lld поливов", room.waterings),
                room.onTime?.let { Lang.format("вовремя %@", Stats.percent(it)) },
            )
            Column(Modifier.semantics(mergeDescendants = true) {}, verticalArrangement = Arrangement.spacedBy(6.dp)) {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text(room.name, style = MaterialTheme.typography.bodyLarge, maxLines = 1, overflow = TextOverflow.Ellipsis, modifier = Modifier.weight(1f, fill = false))
                    if (index == 0 && rooms.size > 1) {
                        Text(
                            Lang.text("Суше всех"),
                            style = MaterialTheme.typography.labelSmall,
                            fontWeight = FontWeight.SemiBold,
                            color = palette.alarm,
                            modifier = Modifier
                                .clip(CircleShape)
                                .background(palette.alarm.copy(alpha = 0.14f))
                                .padding(horizontal = 7.dp, vertical = 2.dp),
                        )
                    }
                    Box(Modifier.weight(1f))
                    Text(Stats.percent(level), style = MaterialTheme.typography.titleSmall, color = palette.level(level))
                }
                Box(
                    Modifier
                        .fillMaxWidth()
                        .height(8.dp)
                        .clip(CircleShape)
                        .background(MaterialTheme.colorScheme.onSurface.copy(alpha = 0.08f)),
                ) {
                    Box(
                        Modifier
                            .fillMaxWidth(level.toFloat().coerceIn(0.03f, 1f))
                            .height(8.dp)
                            .clip(CircleShape)
                            .background(palette.level(level)),
                    )
                }
                Note(details.joinToString(" · "), style = MaterialTheme.typography.bodySmall)
            }
        }
    }
}

@Composable
private fun Plants(book: Almanac, go: Go, modifier: Modifier) {
    val palette = LocalPalette.current
    var board by rememberSaveable { mutableStateOf(Board.MOST) }
    val ranked = when (board) {
        Board.MOST -> book.plants.sortedWith(compareByDescending<Almanac.PlantLine> { it.waterings }.thenBy { it.name })
        Board.LEAST -> book.plants.sortedWith(compareBy<Almanac.PlantLine> { it.waterings }.thenBy { it.name })
        Board.DRIEST -> book.plants.sortedBy { it.moisture }
    }
    SproutGroup(Lang.text("Растения"), modifier) {
        Segments(Board.entries, board, { it.title }) {
            board = it
            Feel.pick()
        }
        ranked.take(5).forEachIndexed { index, line ->
            if (index > 0) SproutDivider()
            Row(
                Modifier
                    .fillMaxWidth()
                    .clip(RowShape)
                    .clickable { go.book(line.id) }
                    .semantics(mergeDescendants = true) {}
                    .padding(vertical = 4.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                Text(Lang.number(index + 1), style = MaterialTheme.typography.titleSmall, color = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.width(22.dp))
                Column(Modifier.weight(1f)) {
                    Text(line.name, style = MaterialTheme.typography.bodyLarge, maxLines = 1, overflow = TextOverflow.Ellipsis)
                    Text(
                        listOf(line.species, line.room).filter { it.isNotEmpty() }.joinToString(" · "),
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                    )
                }
                Text(
                    if (board == Board.DRIEST) Stats.percent(line.moisture) else Lang.format("%lld поливов", line.waterings),
                    style = MaterialTheme.typography.bodyLarge,
                    color = if (board == Board.DRIEST) palette.level(line.moisture) else MaterialTheme.colorScheme.onSurface,
                )
                Icon(painterResource(R.drawable.ic_chevron_right), null, tint = MaterialTheme.colorScheme.outline, modifier = Modifier.size(20.dp))
            }
        }
        Note(Lang.text("Нажмите на растение — откроется его статистика."), style = MaterialTheme.typography.bodySmall)
    }
}
