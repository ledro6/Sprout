package com.ledro6.sprout.platform

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import android.net.Uri
import androidx.core.graphics.scale
import androidx.exifinterface.media.ExifInterface
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.label.ImageLabeling
import com.google.mlkit.vision.label.defaults.ImageLabelerOptions
import com.ledro6.sprout.model.Guess
import com.ledro6.sprout.model.Sample
import com.ledro6.sprout.model.Sighting
import com.ledro6.sprout.model.Species
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withContext
import java.io.ByteArrayOutputStream
import kotlin.coroutines.resume
import kotlin.math.max
import kotlin.math.roundToInt

/**
 * Что на снимке: ML Kit прямо на телефоне, без сети (модель встроена в
 * приложение). Это подсказка, а не определитель — как и на iPhone. Любой
 * сбой — пустой ответ: подсказка необязательна.
 */
object Eye {
    /** Снимок с поворотом из EXIF, не больше `side` по длинной стороне. */
    fun load(context: Context, uri: Uri, side: Int): Bitmap? = runCatching {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        context.contentResolver.openInputStream(uri)?.use { BitmapFactory.decodeStream(it, null, bounds) }
        var sample = 1
        while (max(bounds.outWidth, bounds.outHeight) / (sample * 2) >= side) sample *= 2
        val raw = context.contentResolver.openInputStream(uri)?.use {
            BitmapFactory.decodeStream(it, null, BitmapFactory.Options().apply { inSampleSize = sample })
        } ?: return null
        val turn = context.contentResolver.openInputStream(uri)?.use {
            when (ExifInterface(it).getAttributeInt(ExifInterface.TAG_ORIENTATION, ExifInterface.ORIENTATION_NORMAL)) {
                ExifInterface.ORIENTATION_ROTATE_90 -> 90f
                ExifInterface.ORIENTATION_ROTATE_180 -> 180f
                ExifInterface.ORIENTATION_ROTATE_270 -> 270f
                else -> 0f
            }
        } ?: 0f
        val scale = minOf(1f, side.toFloat() / max(raw.width, raw.height))
        if (turn == 0f && scale >= 1f) return raw
        val matrix = Matrix().apply {
            postScale(scale, scale)
            postRotate(turn)
        }
        Bitmap.createBitmap(raw, 0, 0, raw.width, raw.height, matrix, true)
    }.getOrNull()

    suspend fun look(image: Bitmap): List<Sighting> = runCatching {
        val labeler = ImageLabeling.getClient(ImageLabelerOptions.Builder().setConfidenceThreshold(0.05f).build())
        try {
            suspendCancellableCoroutine { done ->
                labeler.process(InputImage.fromBitmap(image, 0))
                    .addOnSuccessListener { labels -> done.resume(labels.map { Sighting(it.text, it.confidence.toDouble()) }) }
                    .addOnFailureListener { done.resume(emptyList()) }
            }
        } finally {
            labeler.close()
        }
    }.getOrDefault(emptyList())

    suspend fun guess(image: Bitmap): Guess? = Species.read(look(image))

    /** Годится ли снимок для своей модели и какие на нём цвета. */
    suspend fun study(image: Bitmap): Sample.Reading = withContext(Dispatchers.Default) {
        runCatching {
            val side = 320
            val scale = minOf(1f, side.toFloat() / max(image.width, image.height))
            val width = max((image.width * scale).roundToInt(), 16)
            val height = max((image.height * scale).roundToInt(), 16)
            val small = image.scale(width, height).copy(Bitmap.Config.ARGB_8888, false)
            val pixels = IntArray(width * height)
            small.getPixels(pixels, 0, width, 0, 0, width, height)
            val rgba = ByteArray(width * height * 4)
            for (i in pixels.indices) {
                val c = pixels[i]
                rgba[i * 4] = (c shr 16 and 0xFF).toByte()
                rgba[i * 4 + 1] = (c shr 8 and 0xFF).toByte()
                rgba[i * 4 + 2] = (c and 0xFF).toByte()
                rgba[i * 4 + 3] = (c ushr 24).toByte()
            }
            Sample.read(rgba, null, width, height)
        }.getOrDefault(Sample.Reading(Sample.Verdict.EMPTY))
    }

    /** Ужать снимок и положить в папку снимков. */
    suspend fun keep(image: Bitmap): String? = withContext(Dispatchers.IO) {
        val side = 1024
        val scale = minOf(1f, side.toFloat() / max(image.width, image.height))
        val sized = if (scale < 1f) {
            image.scale((image.width * scale).roundToInt(), (image.height * scale).roundToInt())
        } else {
            image
        }
        val bytes = ByteArrayOutputStream().use {
            sized.compress(Bitmap.CompressFormat.JPEG, 85, it)
            it.toByteArray()
        }
        Shots.keep(bytes)
    }
}
