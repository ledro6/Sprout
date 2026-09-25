package com.ledro6.sprout.platform

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.DpSize
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.ColorFilter
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.GlanceTheme
import androidx.glance.Image
import androidx.glance.ImageProvider
import androidx.glance.LocalSize
import androidx.glance.action.ActionParameters
import androidx.glance.action.actionParametersOf
import androidx.glance.action.actionStartActivity
import androidx.glance.action.clickable
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.GlanceAppWidgetReceiver
import androidx.glance.appwidget.SizeMode
import androidx.glance.appwidget.action.ActionCallback
import androidx.glance.appwidget.action.actionRunCallback
import androidx.glance.appwidget.cornerRadius
import androidx.glance.appwidget.provideContent
import androidx.glance.appwidget.updateAll
import androidx.glance.background
import androidx.glance.layout.Alignment
import androidx.glance.layout.Box
import androidx.glance.layout.Column
import androidx.glance.layout.Row
import androidx.glance.layout.Spacer
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.fillMaxWidth
import androidx.glance.layout.height
import androidx.glance.layout.padding
import androidx.glance.layout.size
import androidx.glance.layout.width
import androidx.glance.semantics.contentDescription
import androidx.glance.semantics.semantics
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextStyle
import androidx.glance.unit.ColorProvider
import com.ledro6.sprout.MainActivity
import com.ledro6.sprout.R
import com.ledro6.sprout.app.Sprout
import com.ledro6.sprout.model.Lang
import com.ledro6.sprout.model.Thirst
import com.ledro6.sprout.model.roundedInt
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

/** Виджеты: сад записали — пора перерисоваться. */
object Widgets {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)

    fun nudge(context: Context) {
        val app = context.applicationContext
        scope.launch { runCatching { ThirstWidget().updateAll(app) } }
    }
}

/** Растение на виджете — снимок того, что было в саду в миг перерисовки. */
private class Sprig(val id: String, val name: String, val room: String, val moisture: Double, val label: String, val thumb: Bitmap?) {
    val percent: String get() = Lang.format("%lld%%", (moisture * 100).roundedInt())
    val thirst: Thirst get() = Thirst.of(moisture)
}

/**
 * «Кого полить» на рабочий стол: самые сухие растения и кнопка «Полить» у
 * каждого. Три размера — одно растение, три в ряд, список из шести. Цвета —
 * Material You, как у системных виджетов.
 */
class ThirstWidget : GlanceAppWidget() {
    override val sizeMode = SizeMode.Responsive(setOf(SMALL, MEDIUM, LARGE))

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        val sprigs = withContext(Dispatchers.Main) {
            val sprout = Sprout.get(context)
            sprout.garden.reload()
            sprout.garden.rooms.flatMap { room -> room.plants.map { room.name to it } }
        }.sortedBy { it.second.moisture }.take(6).map { (room, plant) ->
            Sprig(plant.id, plant.name, room, plant.moisture, plant.wateringLabel, plant.shot?.let { thumb(it) })
        }
        provideContent {
            GlanceTheme {
                Box(
                    GlanceModifier
                        .fillMaxSize()
                        .background(GlanceTheme.colors.widgetBackground)
                        .cornerRadius(24.dp)
                        .padding(12.dp)
                        .clickable(actionStartActivity<MainActivity>()),
                ) {
                    when {
                        sprigs.isEmpty() -> Blank(Lang.text("В саду пока пусто."))
                        LocalSize.current.width < MEDIUM.width -> Small(sprigs[0])
                        LocalSize.current.height < LARGE.height -> Medium(sprigs.take(3))
                        else -> Large(sprigs)
                    }
                }
            }
        }
    }

    private fun thumb(name: String): Bitmap? = runCatching {
        val file = Shots.file(name) ?: return null
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(file.path, bounds)
        var sample = 1
        while (bounds.outWidth / (sample * 2) >= 128) sample *= 2
        BitmapFactory.decodeFile(file.path, BitmapFactory.Options().apply { inSampleSize = sample })
    }.getOrNull()

    companion object {
        val SMALL = DpSize(110.dp, 110.dp)
        val MEDIUM = DpSize(250.dp, 110.dp)
        val LARGE = DpSize(250.dp, 250.dp)
        val PLANT = ActionParameters.Key<String>("plant")
    }
}

private fun tone(thirst: Thirst): ColorProvider = ColorProvider(
    when (thirst) {
        Thirst.CALM -> Color(0xFF37B551)
        Thirst.WARN -> Color(0xFFFF9500)
        Thirst.ALARM -> Color(0xFFFF3B30)
    },
)

@Composable
private fun Blank(line: String) {
    Column(GlanceModifier.fillMaxSize(), horizontalAlignment = Alignment.CenterHorizontally, verticalAlignment = Alignment.CenterVertically) {
        Image(ImageProvider(R.drawable.ic_eco), null, GlanceModifier.size(28.dp), colorFilter = ColorFilter.tint(GlanceTheme.colors.primary))
        Spacer(GlanceModifier.height(8.dp))
        Text(line, style = TextStyle(color = GlanceTheme.colors.onSurfaceVariant, fontSize = 12.sp))
    }
}

@Composable
private fun Thumb(sprig: Sprig, side: Int) {
    val modifier = GlanceModifier.size(side.dp).cornerRadius((side * 0.28f).dp)
    if (sprig.thumb != null) {
        Image(ImageProvider(sprig.thumb), null, modifier, contentScale = androidx.glance.layout.ContentScale.Crop)
    } else {
        Box(modifier.background(GlanceTheme.colors.secondaryContainer), contentAlignment = Alignment.Center) {
            Image(
                ImageProvider(R.drawable.ic_eco), null, GlanceModifier.size((side * 0.5f).dp),
                colorFilter = ColorFilter.tint(GlanceTheme.colors.onSecondaryContainer),
            )
        }
    }
}

@Composable
private fun Pour(sprig: Sprig, wide: Boolean) {
    val done = sprig.moisture >= 0.99
    val action = actionRunCallback<WaterFromWidget>(actionParametersOf(ThirstWidget.PLANT to sprig.id))
    val base = GlanceModifier
        .cornerRadius(18.dp)
        .background(if (done) GlanceTheme.colors.surfaceVariant else GlanceTheme.colors.primary)
        .semantics { contentDescription = Lang.format("Полить: %@", sprig.name) }
    val tint = if (done) GlanceTheme.colors.onSurfaceVariant else GlanceTheme.colors.onPrimary
    val modifier = if (done) base else base.clickable(action)
    if (wide) {
        Row(modifier.fillMaxWidth().height(36.dp), verticalAlignment = Alignment.CenterVertically, horizontalAlignment = Alignment.CenterHorizontally) {
            Image(ImageProvider(R.drawable.ic_water_drop_fill), null, GlanceModifier.size(16.dp), colorFilter = ColorFilter.tint(tint))
            Spacer(GlanceModifier.width(6.dp))
            Text(Lang.text("Полить"), style = TextStyle(color = tint, fontWeight = FontWeight.Medium, fontSize = 13.sp))
        }
    } else {
        Box(modifier.size(36.dp), contentAlignment = Alignment.Center) {
            Image(ImageProvider(R.drawable.ic_water_drop_fill), null, GlanceModifier.size(18.dp), colorFilter = ColorFilter.tint(tint))
        }
    }
}

@Composable
private fun Small(sprig: Sprig) {
    Column(GlanceModifier.fillMaxSize()) {
        Row(GlanceModifier.fillMaxWidth()) {
            Thumb(sprig, 44)
            Spacer(GlanceModifier.defaultWeight())
            Text(sprig.percent, style = TextStyle(color = tone(sprig.thirst), fontWeight = FontWeight.Bold, fontSize = 20.sp))
        }
        Spacer(GlanceModifier.defaultWeight())
        Text(sprig.name, maxLines = 1, style = TextStyle(color = GlanceTheme.colors.onSurface, fontWeight = FontWeight.Medium, fontSize = 15.sp))
        Text(sprig.label, maxLines = 1, style = TextStyle(color = GlanceTheme.colors.onSurfaceVariant, fontSize = 11.sp))
        Spacer(GlanceModifier.height(6.dp))
        Pour(sprig, wide = true)
    }
}

@Composable
private fun Medium(sprigs: List<Sprig>) {
    Row(GlanceModifier.fillMaxSize(), verticalAlignment = Alignment.CenterVertically) {
        sprigs.forEachIndexed { index, sprig ->
            if (index > 0) Spacer(GlanceModifier.width(8.dp))
            Column(GlanceModifier.defaultWeight(), horizontalAlignment = Alignment.CenterHorizontally) {
                Thumb(sprig, 44)
                Text(sprig.name, maxLines = 1, style = TextStyle(color = GlanceTheme.colors.onSurface, fontWeight = FontWeight.Medium, fontSize = 12.sp))
                Text(sprig.percent, style = TextStyle(color = tone(sprig.thirst), fontWeight = FontWeight.Bold, fontSize = 16.sp))
                Pour(sprig, wide = false)
            }
        }
    }
}

@Composable
private fun Large(sprigs: List<Sprig>) {
    Column(GlanceModifier.fillMaxSize()) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Image(ImageProvider(R.drawable.ic_water_drop_fill), null, GlanceModifier.size(18.dp), colorFilter = ColorFilter.tint(GlanceTheme.colors.primary))
            Spacer(GlanceModifier.width(6.dp))
            Text(Lang.text("Кого полить"), style = TextStyle(color = GlanceTheme.colors.onSurface, fontWeight = FontWeight.Bold, fontSize = 15.sp))
        }
        Spacer(GlanceModifier.height(6.dp))
        for (sprig in sprigs) {
            Row(GlanceModifier.fillMaxWidth().padding(vertical = 3.dp), verticalAlignment = Alignment.CenterVertically) {
                Thumb(sprig, 36)
                Spacer(GlanceModifier.width(10.dp))
                Column(GlanceModifier.defaultWeight()) {
                    Text(sprig.name, maxLines = 1, style = TextStyle(color = GlanceTheme.colors.onSurface, fontWeight = FontWeight.Medium, fontSize = 13.sp))
                    Text(sprig.room, maxLines = 1, style = TextStyle(color = GlanceTheme.colors.onSurfaceVariant, fontSize = 11.sp))
                }
                Text(sprig.percent, style = TextStyle(color = tone(sprig.thirst), fontWeight = FontWeight.Bold, fontSize = 14.sp))
                Spacer(GlanceModifier.width(8.dp))
                Pour(sprig, wide = false)
            }
        }
    }
}

/** «Полить» на виджете: тот же сад, что в приложении, и та же отмена не нужна — полили. */
class WaterFromWidget : ActionCallback {
    override suspend fun onAction(context: Context, glanceId: GlanceId, parameters: ActionParameters) {
        val id = parameters[ThirstWidget.PLANT] ?: return
        withContext(Dispatchers.Main) {
            val sprout = Sprout.get(context)
            sprout.garden.reload()
            sprout.garden.advance()
            sprout.garden.water(id)
        }
        ThirstWidget().update(context, glanceId)
    }
}

class ThirstWidgetReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = ThirstWidget()
}
