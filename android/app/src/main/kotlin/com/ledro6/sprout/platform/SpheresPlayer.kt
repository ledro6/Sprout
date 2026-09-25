package com.ledro6.sprout.platform

import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioTimestamp
import android.media.AudioTrack
import com.ledro6.sprout.model.Spheres
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

/**
 * Музыка сфер: месяц собирается в звук на телефоне и играет потоком через
 * `AudioTrack`. Как музыка — громкостью медиа. Когда первая нота дошла до
 * динамика, узнаём по отметке времени самого звука: картинка трогается ровно
 * тогда, и нота звучит, когда планета на луче.
 */
class SpheresPlayer {
    private var track: AudioTrack? = null
    private var samples: ShortArray? = null
    private var feeding: Job? = null
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    suspend fun prepare(notes: List<Spheres.Note>) {
        stop()
        samples = withContext(Dispatchers.Default) { Spheres.pcm(Spheres.render(notes)) }
    }

    /** Миг (по `System.nanoTime`), когда зазвучал первый отсчёт; пусто — звука не будет. */
    suspend fun start(): Long? {
        val pcm = samples ?: return null
        val made = runCatching {
            val least = AudioTrack.getMinBufferSize(Spheres.RATE, AudioFormat.CHANNEL_OUT_STEREO, AudioFormat.ENCODING_PCM_16BIT)
            AudioTrack.Builder()
                .setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_MEDIA)
                        .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                        .build(),
                )
                .setAudioFormat(
                    AudioFormat.Builder()
                        .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                        .setSampleRate(Spheres.RATE)
                        .setChannelMask(AudioFormat.CHANNEL_OUT_STEREO)
                        .build(),
                )
                .setTransferMode(AudioTrack.MODE_STREAM)
                .setBufferSizeInBytes(maxOf(least, 0) * 4 + Spheres.RATE)
                .build()
        }.getOrNull() ?: return null
        track = made
        if (runCatching { made.play() }.isFailure) {
            stop()
            return null
        }
        // Пишем без блокировки: остановка не должна ждать заполненного буфера.
        feeding = scope.launch {
            var at = 0
            while (isActive && at < pcm.size) {
                val wrote = runCatching { made.write(pcm, at, pcm.size - at, AudioTrack.WRITE_NON_BLOCKING) }.getOrDefault(-1)
                if (wrote < 0) break
                at += wrote
                if (wrote == 0) delay(20)
            }
        }
        val stamp = AudioTimestamp()
        repeat(40) {
            val known = runCatching { made.getTimestamp(stamp) }.getOrDefault(false)
            if (known && stamp.framePosition > 0) {
                return stamp.nanoTime - stamp.framePosition * 1_000_000_000L / Spheres.RATE
            }
            delay(25)
        }
        return System.nanoTime()
    }

    fun stop() {
        val playing = track ?: return
        track = null
        runCatching { playing.pause() }
        runCatching { playing.flush() }
        val job = feeding
        feeding = null
        if (job == null) {
            runCatching { playing.release() }
        } else {
            job.cancel()
            job.invokeOnCompletion { runCatching { playing.release() } }
        }
    }
}
