package com.ledro6.sprout.platform

import android.app.ActivityManager
import android.content.Context
import android.os.Build
import android.os.PowerManager
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.google.ar.core.ArCoreApk
import com.ledro6.sprout.model.Rig
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/**
 * Умеет ли телефон AR. Спрашивается у сервисов Google Play для AR (ARCore)
 * при запуске; пока ответа нет — кнопок AR не видно, чтобы не показать
 * неработающую. Телефон, которому ARCore нужно только поставить или
 * обновить, AR умеет: это предложит сам экран AR.
 */
object ArSupport {
    var available by mutableStateOf(false)
        internal set

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)

    fun check(context: Context) {
        val app = context.applicationContext
        scope.launch {
            repeat(20) {
                val answer = runCatching { ArCoreApk.getInstance().checkAvailability(app) }.getOrNull() ?: return@launch
                if (!answer.isTransient) {
                    available = answer.isSupported
                    return@launch
                }
                delay(250)
            }
        }
    }

    /** Сколько растений ставить в AR сразу: по памяти телефона и его нагреву. */
    fun plants(context: Context): Int {
        val manager = context.getSystemService(ActivityManager::class.java)
        val memory = ActivityManager.MemoryInfo()
        runCatching { manager?.getMemoryInfo(memory) }
        val hot = Build.VERSION.SDK_INT >= 29 &&
            (context.getSystemService(PowerManager::class.java)?.currentThermalStatus ?: 0) >= PowerManager.THERMAL_STATUS_MODERATE
        return Rig.plants(memory.totalMem, manager?.isLowRamDevice == true, hot)
    }
}
