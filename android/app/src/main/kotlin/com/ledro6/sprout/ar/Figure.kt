package com.ledro6.sprout.ar

import android.content.Context
import com.google.android.filament.Engine
import com.google.android.filament.MaterialInstance
import com.google.android.filament.gltfio.FilamentInstance
import com.ledro6.sprout.model.Channels
import com.ledro6.sprout.model.Greenhouse
import com.ledro6.sprout.model.Paint
import com.ledro6.sprout.model.Pose
import com.ledro6.sprout.model.Rig
import com.ledro6.sprout.model.Role
import com.ledro6.sprout.model.Traits
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import kotlin.math.exp
import kotlin.math.max
import kotlin.math.sqrt

/** Описание модели рядом с GLB: то, чего нет в glTF (см. tool/kit_to_glb.py). */
@Serializable
data class Sidecar(
    val height: Float,
    val spread: Float,
    val looks: List<LookInfo>,
    val pieces: List<PieceInfo>,
) {
    companion object {
        private val json = Json { ignoreUnknownKeys = true }

        fun load(context: Context, preset: String): Sidecar? = runCatching {
            context.assets.open("models/$preset.json").use { json.decodeFromString(serializer(), it.readBytes().decodeToString()) }
        }.getOrNull()
    }
}

@Serializable
data class LookInfo(
    val role: String,
    val mean: List<Double>,
    val tint: List<Double>,
    val opacity: Float,
    val wilts: Boolean,
    val wets: Boolean,
) {
    val kind: Role get() = Role.of(role)
    val colour: Channels get() = Channels(mean[0], mean[1], mean[2])
}

@Serializable
data class PieceInfo(
    val look: Int,
    val base: List<Float>,
    val yaw: Float,
    val rise: Float,
    val roll: Float,
    val size: Float,
    val sag: Float,
    val sway: Float,
    val delay: Float,
    val phase: Float,
) {
    val lives: Boolean get() = sag > 0 || sway > 0
}

/**
 * Растение в AR: модель из GLB и то, как она живёт, — как `Bed` на
 * iPhone. Детали распускаются по очереди, качаются и провисают от сухости;
 * лист желтеет, земля темнеет от воды; своя модель «по фото» берёт цвета
 * листьев, цветов и горшка, густоту и рост со снимка.
 */
class Figure(val id: String, private val side: Sidecar, moisture: Double, private val planted: Double) {
    private var engine: Engine? = null
    private val entities = IntArray(side.pieces.size)
    private val materials = arrayOfNulls<MaterialInstance>(side.looks.size)
    private val matrix = FloatArray(16)
    private val base = FloatArray(3)
    private var first = true
    private var painted = Double.NaN
    private var paintedTraits: Traits? = null

    /** Влажность, которую видно: догоняет настоящую плавно, как на iPhone. */
    var shown = moisture
        private set

    val height: Float get() = side.height
    val spread: Float get() = side.spread

    /** Нашли в загруженной модели детали по именам и их материалы. */
    fun bind(engine: Engine, instance: FilamentInstance) {
        this.engine = engine
        val asset = instance.asset
        val renderables = engine.renderableManager
        for (entity in instance.entities) {
            val name = asset.getName(entity) ?: continue
            if (!name.startsWith(PIECE)) continue
            val index = name.removePrefix(PIECE).toIntOrNull() ?: continue
            if (index !in entities.indices) continue
            entities[index] = entity
            val look = side.pieces[index].look
            if (materials.getOrNull(look) == null && renderables.hasComponent(entity)) {
                val renderable = renderables.getInstance(entity)
                if (renderables.getPrimitiveCount(renderable) > 0) {
                    materials[look] = renderables.getMaterialInstanceAt(renderable, 0)
                }
            }
        }
        first = true
        painted = Double.NaN
    }

    /** Кадр: `clock` — секунды сцены, `dt` — с прошлого кадра. */
    fun frame(clock: Double, dt: Double, moisture: Double, traits: Traits?, still: Boolean) {
        val engine = engine ?: return
        shown += (moisture - shown) * (1 - exp(-dt * 2.2))
        val sag = Greenhouse.sag(shown)
        val growing = clock - planted < 2.2
        val transforms = engine.transformManager
        val stretch = (traits?.stretch ?: 1.0).toFloat().coerceIn(0.7f, 1.4f)
        val thicker = sqrt((traits?.density ?: 1.0).coerceIn(1.0, 1.4)).toFloat()
        for ((index, piece) in side.pieces.withIndex()) {
            val entity = entities[index]
            if (entity == 0) continue
            if (!growing && !first && !piece.lives) continue
            val role = side.looks.getOrNull(piece.look)?.kind ?: Role.OTHER
            val plant = role != Role.POT && role != Role.SOIL
            val open = Greenhouse.unfurl((clock - planted - piece.delay * 0.5) / 0.7)
            val hidden = traits != null && role == Role.LEAF && Rig.thinned(index, traits.density)
            val size = if (hidden) 0.0001f else piece.size * max(open.toFloat(), 0.001f) * (if (role == Role.LEAF) thicker else 1f)
            val sway = if (still) 0f else (piece.sway * Rig.wave(clock, piece.phase) * (1 - 0.5 * sag)).toFloat()
            val q = Pose.orientation(piece.yaw, piece.rise, piece.roll, lean = piece.sag * sag - sway)
            base[0] = piece.base[0]
            base[1] = if (plant && piece.base[1] > Greenhouse.SOIL) Greenhouse.SOIL + (piece.base[1] - Greenhouse.SOIL) * stretch else piece.base[1]
            base[2] = piece.base[2]
            runCatching { transforms.setTransform(transforms.getInstance(entity), Pose.matrix(base, q, size, matrix)) }
        }
        first = false
        paint(traits)
    }

    /** Краска — только когда видимая влажность заметно сдвинулась: материал не меняют каждый кадр. */
    private fun paint(traits: Traits?) {
        if (!painted.isNaN() && kotlin.math.abs(shown - painted) < 0.01 && traits == paintedTraits) return
        painted = shown
        paintedTraits = traits
        for ((index, look) in side.looks.withIndex()) {
            val material = materials[index] ?: continue
            val shift = Paint.factor(look.kind, look.colour, traits, look.wilts, look.wets, shown)
            val r = Greenhouse.linear(look.tint[0]).toFloat() * shift[0]
            val g = Greenhouse.linear(look.tint[1]).toFloat() * shift[1]
            val b = Greenhouse.linear(look.tint[2]).toFloat() * shift[2]
            runCatching { material.setParameter("baseColorFactor", r, g, b, look.opacity) }
        }
    }

    /** Весь горшок распускается вместе с растением. */
    fun grown(clock: Double): Float = max(Greenhouse.unfurl((clock - planted) / 0.9).toFloat(), 0.001f)

    companion object {
        const val PIECE = "piece-"
    }
}
