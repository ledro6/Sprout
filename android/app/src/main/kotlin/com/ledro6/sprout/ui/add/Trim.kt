package com.ledro6.sprout.ui.add

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.RectF
import androidx.compose.foundation.Image
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.gestures.detectTransformGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import com.ledro6.sprout.model.Crop
import com.ledro6.sprout.model.Lang
import com.ledro6.sprout.platform.Feel
import com.ledro6.sprout.ui.components.CardShape
import com.ledro6.sprout.ui.components.Plate
import com.ledro6.sprout.ui.components.SubScreen

/**
 * Кадр для карточки: квадрат из снимка. Сдвиг и увеличение держатся в
 * границах — пустого угла на карточке не бывает. Счёт кадра — `Crop`, тот
 * же, что на iPhone.
 */
@Composable
fun Trim(image: Bitmap, cancel: () -> Unit, done: (Bitmap) -> Unit) {
    var scale by remember { mutableFloatStateOf(1f) }
    var offset by remember { mutableStateOf(Offset.Zero) }
    var side by remember { mutableFloatStateOf(1f) }
    val w = image.width.toDouble()
    val h = image.height.toDouble()

    fun held(o: Offset, s: Float): Offset {
        val (x, y) = Crop.hold(o.x.toDouble(), o.y.toDouble(), w, h, side.toDouble(), s.toDouble())
        return Offset(x.toFloat(), y.toFloat())
    }

    Dialog(onDismissRequest = cancel, properties = DialogProperties(usePlatformDefaultWidth = false, decorFitsSystemWindows = false)) {
        SubScreen(
            title = Lang.text("Кадр"),
            onBack = cancel,
            actions = {
                TextButton(onClick = {
                    val crop = Crop.of(w, h, side.toDouble(), scale.toDouble(), offset.x.toDouble(), offset.y.toDouble())
                    done(cut(image, crop))
                }) { Text(Lang.text("Готово")) }
            },
        ) { inner ->
            Column(
                Modifier.fillMaxSize().padding(inner).padding(16.dp),
                verticalArrangement = Arrangement.spacedBy(18.dp, Alignment.CenterVertically),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                Plate(Modifier.fillMaxWidth().aspectRatio(1f)) {
                    Box(
                        Modifier
                            .fillMaxSize()
                            .clip(CardShape)
                            .onSizeChanged { side = it.width.toFloat().coerceAtLeast(1f) }
                            .pointerInput(Unit) {
                                detectTransformGestures { _, pan, zoom, _ ->
                                    scale = (scale * zoom).coerceIn(1f, Crop.DEEPEST.toFloat())
                                    offset = held(offset + pan, scale)
                                }
                            }
                            .pointerInput(Unit) {
                                detectTapGestures(onDoubleTap = {
                                    scale = 1f
                                    offset = Offset.Zero
                                    Feel.pick()
                                })
                            },
                    ) {
                        Image(
                            image.asImageBitmap(),
                            contentDescription = Lang.text("Кадр снимка"),
                            contentScale = ContentScale.Crop,
                            modifier = Modifier
                                .fillMaxSize()
                                .graphicsLayer {
                                    scaleX = scale
                                    scaleY = scale
                                    translationX = offset.x
                                    translationY = offset.y
                                },
                        )
                    }
                }
                Text(
                    Lang.text("Потяните снимок или разведите пальцы. Двойное нажатие вернёт как было."),
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    textAlign = TextAlign.Center,
                    modifier = Modifier.padding(horizontal = 24.dp),
                )
            }
        }
    }
}

/** Вырезать кадр: не больше 1024 и не меньше 600 точек — крошечный кусок был бы мылом. */
fun cut(image: Bitmap, crop: Crop): Bitmap {
    val out = crop.side.coerceIn(600.0, 1024.0).toInt()
    val result = Bitmap.createBitmap(out, out, Bitmap.Config.ARGB_8888)
    val zoom = (out / crop.side).toFloat()
    Canvas(result).drawBitmap(
        image,
        null,
        RectF(
            (-crop.x * zoom).toFloat(),
            (-crop.y * zoom).toFloat(),
            (-crop.x * zoom + image.width * zoom).toFloat(),
            (-crop.y * zoom + image.height * zoom).toFloat(),
        ),
        Paint(Paint.FILTER_BITMAP_FLAG),
    )
    return result
}
