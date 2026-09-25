package com.ledro6.sprout.platform

import android.annotation.SuppressLint
import android.content.Context
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.SoundPool
import android.os.Build
import android.os.VibrationAttributes
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import com.ledro6.sprout.R
import com.ledro6.sprout.design.Motion
import com.ledro6.sprout.model.Frolic
import com.ledro6.sprout.model.Knock
import com.ledro6.sprout.model.Pulse
import com.ledro6.sprout.model.Rain
import com.ledro6.sprout.model.Settings
import com.ledro6.sprout.model.Tap
import kotlin.math.max
import kotlin.math.min
import kotlin.math.pow
import kotlin.math.roundToInt
import kotlin.random.Random

/**
 * Отклик в руке и звук — вместе, но со своими настройками. Рисунки те же,
 * что на iPhone (`Pulse`, `Rain`, `Knock`); играет их вибромотор телефона:
 * на Android 11+ — примитивами «щелчок» и «тик», которые сами подстраиваются
 * под мотор, на старых — ступенчатой волной силы. Отклик — украшение: любой
 * сбой мотора молча пропускается.
 */
object Feel {
    private var vibrator: Vibrator? = null
    private var settings: Settings? = null

    fun open(context: Context, settings: Settings) {
        this.settings = settings
        vibrator = runCatching {
            if (Build.VERSION.SDK_INT >= 31) {
                (context.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager).defaultVibrator
            } else {
                @Suppress("DEPRECATION")
                context.getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
            }
        }.getOrNull()?.takeIf { it.hasVibrator() }
        Chimes.open(context, settings)
    }

    private val strength: Double get() = settings?.hapticStrength ?: 0.0

    fun water() {
        play(Rain.drops(Motion.CHEER_SECONDS, Random.nextLong()))
        Chimes.play(Chime.POUR)
    }

    fun planted() {
        play(Pulse.bloom, 0.55)
        Chimes.play(Chime.PLANT)
    }

    fun sprout() = play(Pulse.sprout, Motion.BLOOM_SECONDS)

    fun frenzy() {
        play(Pulse.frenzy, Frolic.SECONDS)
        Chimes.play(Chime.FROLIC)
    }

    fun toss() {
        play(Knock.toss)
        Chimes.play(Chime.TOSS)
    }

    fun back() {
        play(Knock.back)
        Chimes.play(Chime.UNDO)
    }

    fun pick() = play(Knock.pick)

    fun done() {
        play(Knock.done)
        Chimes.play(Chime.SAVE)
    }

    fun wrong() {
        play(Knock.wrong)
        Chimes.play(Chime.WRONG)
    }

    /** Показать силу с ползунка — без звука. */
    fun sample() = play(Knock.done)

    /** Глухой толчок листания — как барабан. */
    fun turn(weight: Double = 0.7) = play(listOf(Tap(0.0, weight, 0.1)))

    private var pulled = 0.0

    /** Гул оттяжки к «Новой комнате»: растёт вместе с ней. */
    @SuppressLint("MissingPermission")
    fun pull(share: Double) {
        val motor = vibrator ?: return
        val level = Pulse.scaled(min(max(share, 0.0), 1.0).pow(1.4), strength)
        if (level <= 0.02) {
            if (pulled > 0) runCatching { motor.cancel() }
            pulled = 0.0
            return
        }
        if (kotlin.math.abs(level - pulled) < 0.08) return
        pulled = level
        if (!motor.hasAmplitudeControl()) return
        runCatching {
            motor.vibrate(VibrationEffect.createOneShot(400, (level * 120).roundToInt().coerceIn(1, 255)))
        }
    }

    fun play(pulse: Pulse, seconds: Double) {
        val taps = pulse.taps(seconds).toMutableList()
        if (pulse.strike > 0) taps.add(0, Tap(0.0, pulse.strike, pulse.strikeEdge))
        if (pulse.finish > 0) taps.add(Tap(seconds, pulse.finish, pulse.finishEdge))
        play(taps)
    }

    @SuppressLint("MissingPermission")
    fun play(taps: List<Tap>) {
        val motor = vibrator ?: return
        if (strength <= 0 || taps.isEmpty()) return
        val effect = runCatching { effect(motor, taps) }.getOrNull() ?: return
        runCatching {
            if (Build.VERSION.SDK_INT >= 33) {
                motor.vibrate(effect, VibrationAttributes.createForUsage(VibrationAttributes.USAGE_TOUCH))
            } else {
                @Suppress("DEPRECATION")
                motor.vibrate(effect, AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_ASSISTANCE_SONIFICATION).build())
            }
        }
    }

    /** Рисунок в эффект мотора — самым богатым способом, который мотор умеет. */
    fun effect(motor: Vibrator, taps: List<Tap>): VibrationEffect? {
        val sorted = taps.sortedBy { it.at }
        if (Build.VERSION.SDK_INT >= 30 &&
            motor.areAllPrimitivesSupported(VibrationEffect.Composition.PRIMITIVE_CLICK, VibrationEffect.Composition.PRIMITIVE_TICK)
        ) {
            val low = Build.VERSION.SDK_INT >= 31 &&
                motor.areAllPrimitivesSupported(VibrationEffect.Composition.PRIMITIVE_LOW_TICK)
            val composition = VibrationEffect.startComposition()
            var last = 0.0
            var added = 0
            for (tap in sorted) {
                val scale = Pulse.scaled(tap.strength, strength).toFloat()
                if (scale <= 0f) continue
                val primitive = when {
                    tap.edge >= 0.55 -> VibrationEffect.Composition.PRIMITIVE_CLICK
                    tap.edge < 0.25 && low -> VibrationEffect.Composition.PRIMITIVE_LOW_TICK
                    else -> VibrationEffect.Composition.PRIMITIVE_TICK
                }
                val delay = ((tap.at - last) * 1000).roundToInt().coerceAtLeast(0)
                composition.addPrimitive(primitive, scale.coerceIn(0f, 1f), delay)
                last = tap.at
                added += 1
            }
            return if (added == 0) null else composition.compose()
        }
        return waveform(sorted, motor.hasAmplitudeControl())
    }

    /** Ступенчатая волна: тычок — короткий всплеск силы, между ними тишина. */
    fun waveform(taps: List<Tap>, amplitudes: Boolean): VibrationEffect? {
        val timings = mutableListOf<Long>()
        val levels = mutableListOf<Int>()
        var clock = 0L
        for (tap in taps) {
            val force = Pulse.scaled(tap.strength, strength)
            if (force <= 0) continue
            val start = (tap.at * 1000).toLong()
            // Резкий — короче: так он читается щелчком, а не гулом.
            val length = (26 - 14 * tap.edge).roundToInt().toLong()
            if (start > clock) {
                timings.add(start - clock)
                levels.add(0)
                clock = start
            }
            timings.add(length)
            levels.add((force * 255).roundToInt().coerceIn(1, 255))
            clock += length
        }
        if (timings.isEmpty()) return null
        return if (amplitudes) {
            VibrationEffect.createWaveform(timings.toLongArray(), levels.toIntArray(), -1)
        } else {
            // Мотор без силы: только «вкл/выкл», слабые тычки пропускаем.
            val on = timings.indices.map { if (levels[it] > 60) timings[it] else 0L }
            val pattern = mutableListOf(0L)
            for ((i, time) in timings.withIndex()) {
                if (levels[i] == 0 || on[i] == 0L) pattern[pattern.lastIndex] += time
                else {
                    pattern.add(time)
                    pattern.add(0L)
                }
            }
            if (pattern.size < 2) null else VibrationEffect.createWaveform(pattern.toLongArray(), -1)
        }
    }
}

/** Звуки приложения — те же файлы, что на iPhone. */
enum class Chime(val res: Int) {
    POUR(R.raw.chime_pour), PLANT(R.raw.chime_plant), TOSS(R.raw.chime_toss), UNDO(R.raw.chime_undo),
    SAVE(R.raw.chime_save), WRONG(R.raw.chime_wrong), FROLIC(R.raw.chime_frolic), STREAM(R.raw.chime_stream),
}

/**
 * Звуки — через `SoundPool`: короткие, без задержки на разбор файла. Как на
 * iPhone, беззвучный режим телефона их глушит: в режиме «без звука» и
 * «вибрация» приложение молчит.
 */
object Chimes {
    private var pool: SoundPool? = null
    private val ids = HashMap<Chime, Int>()
    private val ready = HashSet<Int>()
    private var audio: AudioManager? = null
    private var settings: Settings? = null

    fun open(context: Context, settings: Settings) {
        this.settings = settings
        if (pool != null) return
        audio = context.getSystemService(Context.AUDIO_SERVICE) as? AudioManager
        val made = runCatching {
            SoundPool.Builder()
                .setMaxStreams(4)
                .setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_ASSISTANCE_SONIFICATION)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build(),
                )
                .build()
        }.getOrNull() ?: return
        made.setOnLoadCompleteListener { _, id, status -> if (status == 0) ready.add(id) }
        pool = made
        for (chime in Chime.entries) {
            runCatching { made.load(context, chime.res, 1) }.getOrNull()?.let { ids[chime] = it }
        }
    }

    fun play(chime: Chime) {
        if (settings?.sounds != true) return
        if (audio?.ringerMode != AudioManager.RINGER_MODE_NORMAL) return
        val id = ids[chime] ?: return
        if (id !in ready) return
        runCatching { pool?.play(id, 0.8f, 0.8f, 1, 0, 1f) }
    }
}
