package com.ledro6.sprout.ui.plant

import android.graphics.BitmapFactory
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.FilledTonalButton
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.unit.dp
import com.ledro6.sprout.R
import com.ledro6.sprout.app.LocalSprout
import com.ledro6.sprout.design.LocalPalette
import com.ledro6.sprout.model.Lang
import com.ledro6.sprout.model.Plant
import com.ledro6.sprout.model.Preset
import com.ledro6.sprout.platform.Eye
import com.ledro6.sprout.platform.Feel
import com.ledro6.sprout.platform.Shots
import com.ledro6.sprout.ui.Go
import com.ledro6.sprout.ui.components.SproutDivider
import com.ledro6.sprout.ui.components.SproutGroup
import com.ledro6.sprout.ui.components.SubScreen
import com.ledro6.sprout.ui.components.rememberPhotoSource
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

/**
 * Модель для AR: готовая модель вида лежит в приложении; свою можно
 * придумать по фото — цвета листьев, цветов и горшка, густота и рост берутся
 * со снимка. Скана, как на iPhone с LiDAR, у Android нет.
 */
@Composable
fun ModelScreen(id: String, go: Go) {
    val sprout = LocalSprout.current
    val garden = sprout.garden
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val plant = garden.plant(id)
    var thinking by remember { mutableStateOf(false) }
    var trouble by remember { mutableStateOf<String?>(null) }

    fun study(load: suspend () -> android.graphics.Bitmap?) {
        scope.launch {
            thinking = true
            trouble = null
            val image = withContext(Dispatchers.IO) { load() }
            if (image == null) {
                thinking = false
                Feel.wrong()
                return@launch
            }
            val reading = Eye.study(image)
            val seen = Eye.guess(image)
            thinking = false
            val traits = reading.traits
            if (traits == null) {
                trouble = reading.verdict.line
                Feel.wrong()
                return@launch
            }
            garden.imagine(id, traits, seen?.let { Preset.known(it.species) })
            Feel.done()
        }
    }
    val photos = rememberPhotoSource { uri -> study { Eye.load(context, uri, 1024) } }

    SubScreen(Lang.text("Модель для AR"), onBack = go::back, actions = { TextButton(onClick = go::back) { Text(Lang.text("Готово")) } }) { inner ->
        if (plant == null) return@SubScreen
        Column(
            Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(inner)
                .padding(horizontal = 16.dp)
                .padding(top = 4.dp, bottom = 40.dp),
            verticalArrangement = Arrangement.spacedBy(26.dp),
        ) {
            SproutGroup(Lang.text("Сейчас")) {
                Preview(plant)
                Row(horizontalArrangement = Arrangement.spacedBy(12.dp), verticalAlignment = Alignment.Top) {
                    Icon(
                        painterResource(if (plant.plan != null) R.drawable.ic_auto_fix_high else R.drawable.ic_deployed_code),
                        null,
                        tint = MaterialTheme.colorScheme.primary,
                    )
                    Column(verticalArrangement = Arrangement.spacedBy(3.dp)) {
                        Text(plant.blueprint.source, style = MaterialTheme.typography.bodyLarge)
                        Text(
                            if (plant.plan != null) Lang.text("Цвета, густота и рост — со снимка.")
                            else Lang.text("Лежит в приложении — AR открывается сразу."),
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                }
                if (plant.plan != null) {
                    SproutDivider()
                    TextButton(onClick = {
                        garden.unmodel(id)
                        Feel.pick()
                    }) {
                        Icon(painterResource(R.drawable.ic_undo), null, Modifier.size(18.dp))
                        Text(Lang.text("Вернуть готовую модель"), Modifier.padding(start = 8.dp))
                    }
                }
            }
            SproutGroup(Lang.text("Придумать по фото")) {
                Text(
                    Lang.text(
                        "Телефон узнает растение на снимке и придумает его модель: возьмёт цвета листьев, " +
                            "цветов и горшка, густоту и рост. Всё считается на телефоне, без сети, — за пару секунд.",
                    ),
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    plant.shot?.let { name ->
                        Button(onClick = {
                            study { Shots.file(name)?.let { BitmapFactory.decodeFile(it.path) } }
                        }, enabled = !thinking, modifier = Modifier.fillMaxWidth()) {
                            Icon(painterResource(R.drawable.ic_eco), null, Modifier.size(18.dp))
                            Text(Lang.text("По фото растения"), Modifier.padding(start = 8.dp))
                        }
                    }
                    Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                        FilledTonalButton(onClick = photos.gallery, enabled = !thinking, modifier = Modifier.weight(1f)) {
                            Icon(painterResource(R.drawable.ic_photo_library), null, Modifier.size(18.dp))
                            Text(Lang.text("Из галереи"), Modifier.padding(start = 8.dp))
                        }
                        if (photos.hasCamera) {
                            FilledTonalButton(onClick = photos.camera, enabled = !thinking, modifier = Modifier.weight(1f)) {
                                Icon(painterResource(R.drawable.ic_photo_camera), null, Modifier.size(18.dp))
                                Text(Lang.text("Снять"), Modifier.padding(start = 8.dp))
                            }
                        }
                    }
                }
                AnimatedVisibility(thinking) {
                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        CircularProgressIndicator(Modifier.size(20.dp), strokeWidth = 2.dp)
                        Text(Lang.text("Смотрю на снимок…"), style = MaterialTheme.typography.bodySmall)
                    }
                }
                trouble?.let {
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
                        Icon(painterResource(R.drawable.ic_warning), null, tint = LocalPalette.current.warn)
                        Text(it, style = MaterialTheme.typography.bodySmall, color = LocalPalette.current.warn)
                    }
                }
            }
        }
    }
}

/** Картинка готовой модели вида — снята заранее с той же модели, что встанет в AR. */
@Composable
private fun Preview(plant: Plant) {
    val context = LocalContext.current
    val name = plant.blueprint.preset.raw
    val image = remember(name) {
        runCatching {
            context.assets.open("previews/$name.png").use { BitmapFactory.decodeStream(it) }?.asImageBitmap()
        }.getOrNull()
    }
    if (image != null) {
        Box(Modifier.fillMaxWidth().aspectRatio(1.3f), contentAlignment = Alignment.Center) {
            Image(image, contentDescription = plant.blueprint.source, contentScale = ContentScale.Fit, modifier = Modifier.fillMaxSize())
        }
    }
}
