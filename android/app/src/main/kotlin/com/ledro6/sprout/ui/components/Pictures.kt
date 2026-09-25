package com.ledro6.sprout.ui.components

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.BlurMaskFilter
import android.graphics.Paint
import android.os.Build
import android.util.LruCache
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.Image
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.ui.Alignment
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.drawIntoCanvas
import androidx.compose.ui.graphics.drawscope.withTransform
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.asComposePath
import androidx.compose.ui.graphics.nativeCanvas
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.graphics.Matrix
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.ui.graphics.Path
import com.ledro6.sprout.R
import com.ledro6.sprout.design.LocalPalette
import com.ledro6.sprout.design.Metrics
import com.ledro6.sprout.design.Motion
import com.ledro6.sprout.design.SproutShapes
import com.ledro6.sprout.model.Plant
import com.ledro6.sprout.model.Thirst
import com.ledro6.sprout.platform.Shots
import kotlin.math.pow
import kotlin.math.sqrt

/** Снимки — ужатыми и в кэше: карточка спрашивает их каждый кадр. */
object Snapshot {
    private val cache = object : LruCache<String, ImageBitmap>(24 * 1024 * 1024) {
        override fun sizeOf(key: String, value: ImageBitmap) = value.width * value.height * 4
    }

    fun image(name: String, side: Int = 1024): ImageBitmap? {
        cache.get("$name@$side")?.let { return it }
        val file = Shots.file(name) ?: return null
        if (!file.exists()) return null
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(file.path, bounds)
        var sample = 1
        while (bounds.outWidth / (sample * 2) >= side && bounds.outHeight / (sample * 2) >= side) sample *= 2
        val bitmap: Bitmap = runCatching {
            BitmapFactory.decodeFile(file.path, BitmapFactory.Options().apply { inSampleSize = sample })
        }.getOrNull() ?: return null
        val image = bitmap.asImageBitmap()
        cache.put("$name@$side", image)
        return image
    }

    fun forget(name: String) {
        cache.snapshot().keys.filter { it.startsWith("$name@") }.forEach { cache.remove(it) }
    }
}

/** Картинка растения: снимок хозяина или рисунок монстеры из макета. */
@Composable
fun PlantPhoto(plant: Plant, modifier: Modifier = Modifier, radius: Dp = 16.dp) {
    val shot = plant.shot?.let { remember(it) { Snapshot.image(it) } }
    if (shot != null) {
        Image(
            shot,
            contentDescription = null,
            contentScale = ContentScale.Crop,
            modifier = modifier.clip(RoundedCornerShape(radius)),
        )
    } else {
        Image(
            painterResource(R.drawable.monstera),
            contentDescription = null,
            contentScale = ContentScale.Fit,
            modifier = modifier,
        )
    }
}

/**
 * Тревожная тень вокруг плашки: оранжевая ниже 40%, красная ниже 20%, сила —
 * плавно. У досохшего до нуля — медленно дышит, у каждого со своим периодом.
 */
@Composable
fun Modifier.plantGlow(plant: Plant, radius: Dp = Metrics.CARD_RADIUS.dp, shown: Boolean = true): Modifier =
    if (!shown || plant.thirst == Thirst.CALM) this else glow(plant, radius)

@Composable
private fun Modifier.glow(plant: Plant, radius: Dp): Modifier {
    val palette = LocalPalette.current
    val colour = if (plant.thirst == Thirst.ALARM) palette.alarm else palette.warn
    val strength = Metrics.GLOW_FAINT + (Metrics.GLOW_FULL - Metrics.GLOW_FAINT) * plant.alarm.toFloat()
    val period = (Motion.PULSE_PERIOD * (1 + Motion.PULSE_SPREAD * (plant.pulsePhase - 0.5)) * 1000).toInt()
    val breath = if (plant.moisture <= 0) {
        val transition = rememberInfiniteTransition(label = "дыхание")
        val value by transition.animateFloat(1f, Motion.PULSE_LOW, infiniteRepeatable(tween(period), RepeatMode.Reverse), label = "дыхание")
        value
    } else {
        1f
    }
    val paint = remember { Paint(Paint.ANTI_ALIAS_FLAG) }
    val alpha = strength * breath
    if (Build.VERSION.SDK_INT < 28) {
        return border(2.dp, colour.copy(alpha = alpha), RoundedCornerShape(radius))
    }
    return drawBehind {
        val blur = Metrics.GLOW_BLUR * density
        paint.color = colour.copy(alpha = alpha).toArgb()
        paint.maskFilter = BlurMaskFilter(blur, BlurMaskFilter.Blur.OUTER)
        val corner = radius.toPx()
        drawIntoCanvas {
            it.nativeCanvas.drawRoundRect(0f, 0f, size.width, size.height, corner, corner, paint)
        }
    }
}

/**
 * Логотип: три листа контуром и две капли. `reveal` — насколько собрался:
 * части вырастают снизу вверх, каждая вокруг своей середины.
 */
@Composable
fun SproutLogo(height: Dp, modifier: Modifier = Modifier, reveal: Float = 1f) {
    val palette = LocalPalette.current
    val aspect = (SproutShapes.LOGO_W + SproutShapes.LOGO_STROKE) / SproutShapes.LOGO_H
    val leaves = remember { SproutShapes.logoLeaves.map { it.asComposePath() } }
    val drops = remember { SproutShapes.logoDrops.map { it.asComposePath() } }
    Canvas(modifier.size(height * aspect, height)) {
        val pad = SproutShapes.LOGO_STROKE / 2
        val sx = size.width / (SproutShapes.LOGO_W + 2 * pad)
        val sy = size.height / SproutShapes.LOGO_H
        val stroke = Stroke(width = SproutShapes.LOGO_STROKE * sqrt(sx * sy), cap = StrokeCap.Butt, join = StrokeJoin.Miter)
        val parts = SproutShapes.logoParts
        for ((index, part) in parts.withIndex()) {
            val t = grown(reveal, index, parts.size)
            if (t <= 0f) continue
            val placed = { path: Path ->
                Path().apply {
                    addPath(path)
                    transform(Matrix().apply { scale(sx, sy) })
                    translate(androidx.compose.ui.geometry.Offset(pad * sx, 0f))
                }
            }
            val shapes = part.first.map { placed(leaves[it]) } to part.second.map { placed(drops[it]) }
            val bounds = (shapes.first + shapes.second).map { it.getBounds() }.reduce { a, b ->
                androidx.compose.ui.geometry.Rect(minOf(a.left, b.left), minOf(a.top, b.top), maxOf(a.right, b.right), maxOf(a.bottom, b.bottom))
            }
            val scale = Motion.LOGO_SCALE + (1 - Motion.LOGO_SCALE) * t
            withTransform({ scale(scale, scale, bounds.center) }) {
                for (leaf in shapes.first) drawPath(leaf, palette.green.copy(alpha = t), style = stroke)
                for (drop in shapes.second) drawPath(drop, palette.water.copy(alpha = t))
            }
        }
    }
}

private fun grown(reveal: Float, index: Int, count: Int): Float {
    if (reveal >= 1f) return 1f
    val span = 1 - (count - 1) * Motion.LOGO_LAG
    val step = ((reveal - index * Motion.LOGO_LAG) / span).toFloat()
    if (step <= 0f) return 0f
    if (step >= 1f) return 1f
    return 1 - (1 - step).pow(3)
}

/** Капсула с логотипом — знак приложения, светло-зелёная в обеих темах. */
@Composable
fun SproutBadge(modifier: Modifier = Modifier) {
    val palette = LocalPalette.current
    Row(
        modifier
            .clip(RoundedCornerShape(50))
            .drawBehind { drawRect(palette.greenSoft) }
            .padding(start = 8.dp, end = 10.dp, top = 5.dp, bottom = 5.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(3.dp),
    ) {
        SproutLogo(18.dp)
        Text("Sprout", color = Color.Black, style = MaterialTheme.typography.labelLarge)
    }
}

/** Вся картинка во весь размер — для фото хозяина и больших снимков. */
@Composable
fun ShotImage(name: String, modifier: Modifier = Modifier) {
    val image = remember(name) { Snapshot.image(name) }
    if (image != null) {
        Image(image, contentDescription = null, contentScale = ContentScale.Crop, modifier = modifier.fillMaxSize())
    }
}
