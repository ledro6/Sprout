package com.ledro6.sprout.ui.components

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.getValue
import androidx.compose.ui.platform.LocalContext
import androidx.core.content.ContextCompat
import androidx.core.content.FileProvider
import java.io.File

/** Откуда взять снимок: галерея (Photo Picker) и камера телефона. */
class PhotoSource(val gallery: () -> Unit, val camera: () -> Unit, val hasCamera: Boolean)

/**
 * Галерея — системный выбор фото Android: разрешений на все снимки не
 * нужно, приложение видит только выбранный. Камера — системное приложение
 * камеры; разрешение на камеру спрашивается перед съёмкой (оно же нужно AR).
 */
@Composable
fun rememberPhotoSource(picked: (Uri) -> Unit): PhotoSource {
    val context = LocalContext.current
    val onPicked by rememberUpdatedState(picked)
    val shot = remember { shotUri(context) }
    val gallery = rememberLauncherForActivityResult(ActivityResultContracts.PickVisualMedia()) { uri ->
        if (uri != null) onPicked(uri)
    }
    val camera = rememberLauncherForActivityResult(ActivityResultContracts.TakePicture()) { ok ->
        if (ok && shot != null) onPicked(shot)
    }
    val ask = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
        if (granted && shot != null) runCatching { camera.launch(shot) }
    }
    val hasCamera = context.packageManager.hasSystemFeature(PackageManager.FEATURE_CAMERA_ANY) && shot != null
    return remember(hasCamera) {
        PhotoSource(
            gallery = {
                runCatching {
                    gallery.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly))
                }
            },
            camera = {
                if (shot != null) {
                    if (ContextCompat.checkSelfPermission(context, Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED) {
                        runCatching { camera.launch(shot) }
                    } else {
                        runCatching { ask.launch(Manifest.permission.CAMERA) }
                    }
                }
            },
            hasCamera = hasCamera,
        )
    }
}

/** Куда камера кладёт снимок: временный файл в кэше, отданный через FileProvider. */
private fun shotUri(context: Context): Uri? = runCatching {
    val folder = File(context.cacheDir, "camera").apply { mkdirs() }
    FileProvider.getUriForFile(context, "${context.packageName}.files", File(folder, "shot.jpg"))
}.getOrNull()
