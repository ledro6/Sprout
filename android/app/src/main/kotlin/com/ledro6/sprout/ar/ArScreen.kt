package com.ledro6.sprout.ar

import android.animation.ValueAnimator
import android.opengl.Matrix
import android.view.MotionEvent
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.FilledTonalButton
import androidx.compose.material3.FilledTonalIconButton
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.key
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.layout.layout
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.IntSize
import androidx.compose.ui.unit.dp
import com.google.ar.core.Anchor
import com.google.ar.core.Config
import com.google.ar.core.Frame
import com.google.ar.core.HitResult
import com.google.ar.core.Session
import com.google.ar.core.TrackingFailureReason
import com.ledro6.sprout.R
import com.ledro6.sprout.app.LocalSprout
import com.ledro6.sprout.design.Palette
import com.ledro6.sprout.model.Greenhouse
import com.ledro6.sprout.model.Hint
import com.ledro6.sprout.model.Lang
import com.ledro6.sprout.model.Plant
import com.ledro6.sprout.model.Plot
import com.ledro6.sprout.model.Thirst
import com.ledro6.sprout.model.Walk
import com.ledro6.sprout.platform.ArSupport
import com.ledro6.sprout.platform.Chime
import com.ledro6.sprout.platform.Chimes
import com.ledro6.sprout.platform.Feel
import com.ledro6.sprout.ui.components.CoachLayer
import com.ledro6.sprout.ui.components.UndoToast
import com.ledro6.sprout.ui.components.WalkHost
import com.ledro6.sprout.ui.components.hintSpot
import io.github.sceneview.ar.ARCameraPermissionState
import io.github.sceneview.ar.ARCoreAvailability
import io.github.sceneview.ar.ARCoreAvailabilityState
import io.github.sceneview.ar.ARSceneView
import io.github.sceneview.ar.rememberARCameraStream
import io.github.sceneview.math.Position
import io.github.sceneview.math.Rotation
import io.github.sceneview.math.Scale
import io.github.sceneview.node.ModelNode
import io.github.sceneview.node.Node
import io.github.sceneview.rememberEngine
import io.github.sceneview.rememberMaterialLoader
import io.github.sceneview.rememberModelInstance
import io.github.sceneview.rememberModelLoader
import kotlinx.coroutines.delay
import kotlin.math.atan2
import kotlin.math.hypot
import kotlin.math.max
import kotlin.math.sin
import kotlin.random.Random
import com.google.ar.core.Pose as ArPose

/** Где AR: ищем пол, целимся, растения стоят, поливаем. */
enum class Phase { SEARCHING, AIMING, PLACED, WATERING }

/**
 * AR-сад: растения на полу или столе в натуральную величину. Табличка над
 * каждым — кличка и влажность; «Полить» поливает выбранное, «Полить сухих» —
 * по очереди всех, кому пора. Вращать — двумя пальцами, размер — щипком.
 */
@Composable
fun ArScreen(ids: List<String>, close: () -> Unit) {
    val sprout = LocalSprout.current
    val garden = sprout.garden
    val context = LocalContext.current
    val limit = remember { ArSupport.plants(context) }
    val all = ids.mapNotNull { garden.plant(it) }
    val shown = all.take(limit)
    val left = all.size - shown.size
    val many = shown.size > 1
    // Растения удалили, пока смотрели, — смотреть не на что.
    LaunchedEffect(all.isEmpty()) { if (all.isEmpty()) close() }

    val engine = rememberEngine()
    val modelLoader = rememberModelLoader(engine)
    val materialLoader = rememberMaterialLoader(engine)
    val cameraStream = rememberARCameraStream(materialLoader)
    val sides = remember { HashMap<String, Sidecar?>() }
    val instances = HashMap<String, io.github.sceneview.model.ModelInstance?>()
    for (plant in shown) {
        key(plant.id) {
            val preset = plant.blueprint.preset.raw
            sides.getOrPut(plant.id) { Sidecar.load(context, preset) }
            instances[plant.id] = rememberModelInstance(modelLoader, "models/$preset.glb")
        }
    }
    val loaded = shown.count { instances[it.id] != null && sides[it.id] != null }
    val ready = shown.isNotEmpty() && loaded == shown.size

    var size by remember { mutableStateOf(IntSize.Zero) }
    var session by remember { mutableStateOf<Session?>(null) }
    var frame by remember { mutableStateOf<Frame?>(null) }
    var hit by remember { mutableStateOf<HitResult?>(null) }
    var anchor by remember { mutableStateOf<Anchor?>(null) }
    var phase by remember { mutableStateOf(Phase.SEARCHING) }
    var chosen by remember { mutableStateOf(if (shown.size == 1) shown.first().id else null) }
    var watering by remember { mutableStateOf<String?>(null) }
    var failure by remember { mutableStateOf<TrackingFailureReason?>(null) }
    var facing by remember { mutableStateOf(0f) }
    val queue = remember { mutableStateListOf<String>() }
    val offsets = remember { mutableStateMapOf<String, Pair<Float, Float>>() }
    val figures = remember { mutableStateMapOf<String, Figure>() }
    val roots = remember { HashMap<String, Node>() }
    val models = remember { HashMap<String, ModelNode>() }
    val tags = remember { mutableStateMapOf<String, Offset>() }
    var poured by remember { mutableIntStateOf(0) }
    val start = remember { System.nanoTime() }
    val clock = { (System.nanoTime() - start) / 1e9 }
    var last by remember { mutableStateOf(0.0) }
    val still = remember { !ValueAnimator.areAnimatorsEnabled() }
    val plants by rememberUpdatedState(shown)

    fun place() {
        val found = hit ?: return
        val current = frame ?: return
        val live = session ?: return
        if (!ready || anchor != null) return
        val aim = found.hitPose
        val camera = current.camera.pose
        var fx = aim.tx() - camera.tx()
        var fz = aim.tz() - camera.tz()
        val length = hypot(fx, fz)
        if (length > 0.01f) {
            fx /= length
            fz /= length
        } else {
            fx = 0f
            fz = -1f
        }
        facing = Math.toDegrees(atan2(-fx, -fz).toDouble()).toFloat()
        val order = plants.filter { sides[it.id] != null }
        val spots = Plot.layout(order.map { sides[it.id]!!.spread }, order.map { sides[it.id]!!.height })
        val depth = spots.maxOfOrNull { it.second } ?: 0f
        // Вправо — поперёк взгляда, вглубь — от камеры.
        val rightX = -fz
        val rightZ = fx
        offsets.clear()
        figures.clear()
        order.forEachIndexed { index, plant ->
            val (across, deep) = spots.getOrElse(index) { 0f to 0f }
            val ahead = deep - depth / 2
            offsets[plant.id] = (rightX * across + fx * ahead) to (rightZ * across + fz * ahead)
            figures[plant.id] = Figure(plant.id, sides[plant.id]!!, plant.moisture, clock() + index * 0.18)
        }
        anchor = runCatching { live.createAnchor(ArPose.makeTranslation(aim.tx(), aim.ty(), aim.tz())) }.getOrNull() ?: return
        phase = Phase.PLACED
        Feel.planted()
    }

    fun replace() {
        anchor?.let { runCatching { it.detach() } }
        anchor = null
        figures.clear()
        roots.clear()
        models.clear()
        tags.clear()
        queue.clear()
        watering = null
        if (many) chosen = null
        phase = if (hit != null) Phase.AIMING else Phase.SEARCHING
    }

    fun pour(id: String) {
        if (phase != Phase.PLACED || roots[id] == null) return
        chosen = id
        watering = id
        phase = Phase.WATERING
        Chimes.play(Chime.STREAM)
    }

    fun next() {
        val id = queue.removeFirstOrNull() ?: return
        pour(id)
    }

    // Полив длится, пока падает вода; сама запись — когда вода дошла до земли.
    LaunchedEffect(watering) {
        val id = watering ?: return@LaunchedEffect
        delay(1_400)
        if (sprout.bin.water(id)) Feel.water()
        poured += 1
        watering = null
        phase = Phase.PLACED
        if (queue.isNotEmpty()) {
            delay(350)
            next()
        }
    }

    fun update(current: Frame) {
        frame = current
        val now = clock()
        val dt = (now - last).coerceIn(0.0, 1.0 / 20)
        last = now
        if (anchor == null) {
            phase = when {
                hit != null -> Phase.AIMING
                else -> Phase.SEARCHING
            }
            return
        }
        for ((id, figure) in figures) {
            val plant = garden.plant(id) ?: continue
            figure.frame(now, dt, plant.moisture, plant.plan?.traits, still)
            models[id]?.scale = Scale(figure.grown(now))
        }
        if (size.width == 0) return
        val view = FloatArray(16)
        val projection = FloatArray(16)
        val both = FloatArray(16)
        current.camera.getViewMatrix(view, 0)
        current.camera.getProjectionMatrix(projection, 0, 0.05f, 50f)
        Matrix.multiplyMM(both, 0, projection, 0, view, 0)
        val point = FloatArray(4)
        val out = FloatArray(4)
        for ((id, figure) in figures) {
            val root = roots[id] ?: continue
            val world = root.worldPosition
            val scale = root.scale.x
            point[0] = world.x
            point[1] = world.y + (figure.height * figure.grown(now) + 0.03f) * scale
            point[2] = world.z
            point[3] = 1f
            Matrix.multiplyMV(out, 0, both, 0, point, 0)
            if (out[3] <= 0f) {
                tags.remove(id)
                continue
            }
            val x = (out[0] / out[3] + 1) / 2 * size.width
            val y = (1 - out[1] / out[3]) / 2 * size.height
            val old = tags[id]
            if (old == null || kotlin.math.abs(old.x - x) >= 0.5f || kotlin.math.abs(old.y - y) >= 0.5f) tags[id] = Offset(x, y)
        }
    }

    Box(Modifier.fillMaxSize()) {
        ARSceneView(
            modifier = Modifier.fillMaxSize().onSizeChanged { size = it },
            engine = engine,
            modelLoader = modelLoader,
            materialLoader = materialLoader,
            planeFindingMode = Config.PlaneFindingMode.HORIZONTAL,
            depthMode = Config.DepthMode.AUTOMATIC,
            planeRenderer = anchor == null,
            cameraStream = cameraStream,
            onSessionCreated = { created ->
                session = created
                cameraStream.isDepthOcclusionEnabled = created.isDepthModeSupported(Config.DepthMode.AUTOMATIC)
            },
            onSessionUpdated = { _, current -> update(current) },
            onTrackingFailureChanged = { failure = it },
            onTouchEvent = { event, _ ->
                if (event.actionMasked == MotionEvent.ACTION_UP && phase == Phase.AIMING && ready && hit != null) {
                    place()
                    true
                } else {
                    false
                }
            },
            cameraPermissionOverlay = { state -> CameraAsk(state) },
            arCoreAvailabilityOverlay = { state -> ArCoreAsk(state, close) },
        ) {
            if (anchor == null && size.width > 0) {
                PlacementReticle(xPx = size.width / 2f, yPx = size.height / 2f, onHitResultChanged = { hit = it })
            }
            anchor?.let { placed ->
                AnchorNode(anchor = placed) {
                    for (plant in shown) {
                        key(plant.id) {
                            val figure = figures[plant.id]
                            val instance = instances[plant.id]
                            val (x, z) = offsets[plant.id] ?: (0f to 0f)
                            if (figure != null && instance != null) {
                                Node(
                                    position = Position(x, 0f, z),
                                    rotation = Rotation(0f, facing, 0f),
                                    isEditable = true,
                                    apply = {
                                        isPositionEditable = false
                                        editableScaleRange = 0.35f..3f
                                        onSingleTapConfirmed = {
                                            if (many && phase == Phase.PLACED) {
                                                chosen = plant.id
                                                Feel.pick()
                                            }
                                            true
                                        }
                                        roots[plant.id] = this
                                    },
                                ) {
                                    ModelNode(
                                        modelInstance = instance,
                                        autoAnimate = false,
                                        scale = Scale(0.001f),
                                        apply = {
                                            isTouchable = false
                                            isShadowCaster = true
                                            figure.bind(engine, modelInstance)
                                            models[plant.id] = this
                                        },
                                    )
                                    if (watering == plant.id) Droplets(figure.height, poured)
                                }
                            }
                        }
                    }
                }
            }
        }

        Tags(shown, tags, chosen, many)
        Header(
            hint(phase, ready, many, loaded, shown.size, chosen, queue.isNotEmpty(), failure),
            left,
            shown.size,
            close,
        )
        Column(
            Modifier.align(Alignment.BottomCenter).fillMaxWidth().navigationBarsPadding(),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            UndoToast(sprout.bin)
            Controls(
                phase = phase,
                ready = ready && hit != null,
                many = many,
                chosen = chosen,
                thirsty = shown.count { it.moisture < Thirst.WARN_BELOW },
                place = ::place,
                replace = ::replace,
                water = { chosen?.let(::pour) },
                waterThirsty = {
                    queue.clear()
                    queue.addAll(shown.filter { it.moisture < Thirst.WARN_BELOW }.sortedBy { it.moisture }.map { it.id })
                    next()
                },
            )
        }
    }
    WalkHost(Walk.AR)
    CoachLayer()
}

private fun hint(
    phase: Phase,
    ready: Boolean,
    many: Boolean,
    loaded: Int,
    total: Int,
    chosen: String?,
    queued: Boolean,
    failure: TrackingFailureReason?,
): String {
    if (phase == Phase.SEARCHING || phase == Phase.AIMING) {
        when (failure) {
            TrackingFailureReason.INSUFFICIENT_LIGHT -> return Lang.text("Слишком темно — включите свет")
            TrackingFailureReason.EXCESSIVE_MOTION -> return Lang.text("Ведите телефон медленнее")
            TrackingFailureReason.INSUFFICIENT_FEATURES -> return Lang.text("Наведите камеру на пол с узором или на мебель")
            TrackingFailureReason.CAMERA_UNAVAILABLE -> return Lang.text("Камера занята другим приложением")
            else -> Unit
        }
    }
    return when (phase) {
        Phase.SEARCHING -> Lang.text("Медленно ведите телефоном над полом или столом")
        Phase.AIMING -> when {
            !ready && many -> Lang.format("Готовлю модели растений: %1\$lld из %2\$lld", loaded, total)
            !ready -> Lang.text("Готовлю модель растения…")
            many -> Lang.text("Нажмите — и сад встанет вокруг прицела")
            else -> Lang.text("Нажмите — и растение встанет сюда")
        }
        Phase.PLACED -> if (many && chosen == null) Lang.text("Нажмите на растение, чтобы выбрать его")
        else Lang.text("Двумя пальцами — повернуть, щипком — размер")
        Phase.WATERING -> if (queued) Lang.text("Поливаем по очереди…") else Lang.text("Поливаем…")
    }
}

/** Капли над горшком: падают по очереди, пока идёт полив. */
@Composable
private fun io.github.sceneview.NodeScope.Droplets(height: Float, round: Int) {
    val water = remember(materialLoader) {
        materialLoader.createColorInstance(
            androidx.compose.ui.graphics.Color(0.56f, 0.83f, 1f, 0.85f),
            metallic = 0f,
            roughness = 0.12f,
            reflectance = 0.9f,
        )
    }
    DisposableEffect(water) { onDispose { runCatching { materialLoader.destroyMaterialInstance(water) } } }
    val begun = remember(round) { System.nanoTime() }
    val random = remember(round) { Random(round) }
    val drops = remember(round) {
        List(18) {
            val angle = random.nextDouble(0.0, 2 * Math.PI)
            val reach = random.nextDouble(0.0, Greenhouse.POT_INNER * 0.75)
            Triple((kotlin.math.cos(angle) * reach).toFloat(), (sin(angle) * reach).toFloat(), it * 0.06)
        }
    }
    val top = max(height, 0.2f) + 0.12f
    for ((index, drop) in drops.withIndex()) {
        key(index) {
            SphereNode(
                radius = 0.0045f,
                materialInstance = water,
                position = Position(drop.first, top, drop.second),
                apply = {
                    onFrame = {
                        val t = (System.nanoTime() - begun) / 1e9 - drop.third
                        val fall = (t % 0.55) / 0.55
                        isVisible = t >= 0 && t < 1.3
                        position = Position(drop.first, top - (top - Greenhouse.SOIL) * (fall * fall).toFloat(), drop.second)
                    }
                },
            )
        }
    }
}

@Composable
private fun BoxScope.Tags(plants: List<Plant>, tags: Map<String, Offset>, chosen: String?, many: Boolean) {
    for (plant in plants) {
        val spot = tags[plant.id] ?: continue
        val big = !many || chosen == plant.id
        val level = Greenhouse.ringColor(plant.moisture)
        Surface(
            shape = RoundedCornerShape(18.dp),
            color = if (big && many) MaterialTheme.colorScheme.primaryContainer.copy(alpha = 0.92f)
            else MaterialTheme.colorScheme.surfaceContainerHigh.copy(alpha = 0.9f),
            modifier = Modifier.layout { measurable, constraints ->
                val placeable = measurable.measure(constraints.copy(minWidth = 0, minHeight = 0))
                layout(0, 0) {
                    placeable.place(
                        (spot.x - placeable.width / 2f).toInt(),
                        (spot.y - placeable.height - 36.dp.toPx()).toInt(),
                    )
                }
            },
        ) {
            Column(
                Modifier.padding(horizontal = if (big) 14.dp else 10.dp, vertical = if (big) 10.dp else 6.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                Text(plant.name, style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.SemiBold)
                Text(
                    Lang.format("Влажность %@", plant.moistureLabel),
                    style = MaterialTheme.typography.bodySmall,
                    color = Palette.channels(level),
                )
                if (big) {
                    Text(plant.wateringLabel, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            }
        }
    }
}

@Composable
private fun Header(hint: String, left: Int, total: Int, close: () -> Unit) {
    Row(
        Modifier.fillMaxWidth().statusBarsPadding().padding(horizontal = 16.dp, vertical = 8.dp),
        verticalAlignment = Alignment.Top,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        FilledTonalIconButton(onClick = close) {
            Icon(painterResource(R.drawable.ic_close), contentDescription = Lang.text("Закрыть"))
        }
        Box(Modifier.weight(1f), contentAlignment = Alignment.TopCenter) {
            Surface(
                shape = RoundedCornerShape(18.dp),
                color = MaterialTheme.colorScheme.surfaceContainerHigh.copy(alpha = 0.9f),
                modifier = Modifier.widthIn(max = 320.dp).hintSpot(Hint.Target.AR_HINT).semantics { liveRegion = LiveRegionMode.Polite },
            ) {
                AnimatedContent(hint, transitionSpec = { fadeIn() togetherWith fadeOut() }, label = "подсказка AR") { line ->
                    Column(Modifier.padding(horizontal = 14.dp, vertical = 9.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                        Text(line, style = MaterialTheme.typography.bodyMedium, textAlign = TextAlign.Center)
                        if (left > 0) {
                            Text(
                                Lang.format("Показаны %1\$lld из %2\$lld: больше телефону тяжело", total, total + left),
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                                textAlign = TextAlign.Center,
                            )
                        }
                    }
                }
            }
        }
        // Противовес крестику — подсказка встаёт ровно посередине.
        Spacer(Modifier.size(48.dp))
    }
}

@Composable
private fun Controls(
    phase: Phase,
    ready: Boolean,
    many: Boolean,
    chosen: String?,
    thirsty: Int,
    place: () -> Unit,
    replace: () -> Unit,
    water: () -> Unit,
    waterThirsty: () -> Unit,
) {
    val busy = phase == Phase.WATERING
    Row(
        Modifier.padding(horizontal = 16.dp, vertical = 12.dp).hintSpot(Hint.Target.AR_CONTROLS),
        horizontalArrangement = Arrangement.spacedBy(10.dp, Alignment.CenterHorizontally),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        when (phase) {
            Phase.SEARCHING -> Unit
            Phase.AIMING -> Button(onClick = place, enabled = ready) {
                Icon(painterResource(R.drawable.ic_view_in_ar), null, Modifier.size(18.dp))
                Text(if (many) Lang.text("Поставить сад") else Lang.text("Поставить"), Modifier.padding(start = 8.dp))
            }
            Phase.PLACED, Phase.WATERING -> {
                OutlinedButton(onClick = replace, enabled = !busy) {
                    Icon(painterResource(R.drawable.ic_open_with), null, Modifier.size(18.dp))
                    Text(Lang.text("Переставить"), Modifier.padding(start = 8.dp))
                }
                AnimatedVisibility(many && thirsty > 0) {
                    FilledTonalButton(onClick = waterThirsty, enabled = !busy) {
                        Icon(painterResource(R.drawable.ic_water_drop), null, Modifier.size(18.dp))
                        Text(Lang.text("Полить сухих"), Modifier.padding(start = 8.dp))
                    }
                }
                Button(onClick = water, enabled = !busy && !(many && chosen == null)) {
                    Icon(painterResource(R.drawable.ic_water_drop_fill), null, Modifier.size(18.dp))
                    Text(Lang.text("Полить"), Modifier.padding(start = 8.dp))
                }
            }
        }
    }
}

/** Камера не разрешена: спросить снова или отправить в настройки. */
@Composable
private fun BoxScope.CameraAsk(state: ARCameraPermissionState) {
    Ask(
        title = Lang.text("Нужна камера"),
        text = if (state.permanentlyDenied) Lang.text("Камера запрещена в настройках телефона. Разрешите её там и вернитесь.")
        else Lang.text("AR рисует растение поверх того, что видит камера. Кадры никуда не уходят."),
        action = if (state.permanentlyDenied) Lang.text("Открыть настройки") else Lang.text("Разрешить камеру"),
        onAction = if (state.permanentlyDenied) state.openSettings else state.request,
    )
}

/** ARCore нет, он старый или не запустился. */
@Composable
private fun BoxScope.ArCoreAsk(state: ARCoreAvailabilityState, close: () -> Unit) {
    when (state.availability) {
        ARCoreAvailability.Unsupported -> Ask(
            Lang.text("Этот телефон не умеет AR"),
            Lang.text("Сервисы Google Play для AR на нём не работают. Всё остальное в Sprout работает как обычно."),
            Lang.text("Закрыть"), close,
        )
        ARCoreAvailability.NotInstalled -> Ask(
            Lang.text("Нужны сервисы Google Play для AR"),
            Lang.text("Их ставят из Google Play, бесплатно. Потом AR откроется сразу."),
            Lang.text("Установить"), state.retry,
        )
        ARCoreAvailability.NeedsUpdate -> Ask(
            Lang.text("Обновите сервисы Google Play для AR"),
            Lang.text("Эта версия слишком старая для Sprout."),
            Lang.text("Обновить"), state.retry,
        )
        else -> Ask(
            Lang.text("AR не запустился"),
            Lang.text("Такое бывает, если камеру заняло другое приложение. Попробуйте ещё раз."),
            Lang.text("Ещё раз"), state.retry,
        )
    }
}

@Composable
private fun BoxScope.Ask(title: String, text: String, action: String, onAction: () -> Unit) {
    Surface(
        shape = RoundedCornerShape(24.dp),
        color = MaterialTheme.colorScheme.surfaceContainerHigh,
        modifier = Modifier.align(Alignment.Center).padding(24.dp).widthIn(max = 340.dp),
    ) {
        Column(Modifier.padding(20.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Icon(painterResource(R.drawable.ic_view_in_ar), null, tint = MaterialTheme.colorScheme.primary, modifier = Modifier.size(32.dp))
            Text(title, style = MaterialTheme.typography.titleMedium, textAlign = TextAlign.Center)
            Text(text, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant, textAlign = TextAlign.Center)
            Button(onClick = onAction) { Text(action) }
        }
    }
}
