package com.ledro6.sprout.platform

import android.content.Context
import androidx.biometric.BiometricManager
import androidx.biometric.BiometricManager.Authenticators.BIOMETRIC_WEAK
import androidx.biometric.BiometricManager.Authenticators.DEVICE_CREDENTIAL
import androidx.biometric.BiometricPrompt
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.core.content.ContextCompat
import androidx.fragment.app.FragmentActivity
import com.ledro6.sprout.model.Lang
import com.ledro6.sprout.model.Settings

/**
 * Замок на сад: отпечаток, лицо или код разблокировки телефона — системным
 * окном `BiometricPrompt`. Запирается, когда приложение уходит с экрана.
 */
object Lock {
    private var settings: Settings? = null

    /** Открыт ли сад сейчас. Выключенный замок — всегда открыт. */
    var open by mutableStateOf(true)
        private set

    /** Идёт проверка — повторно не спрашиваем и не запираем. */
    var asking by mutableStateOf(false)
        private set

    fun attach(settings: Settings) {
        if (this.settings === settings) return
        this.settings = settings
        open = !settings.lock
    }

    val on: Boolean get() = settings?.lock == true

    val locked: Boolean get() = on && !open

    fun turn(on: Boolean) {
        settings?.lock = on
        if (!on) open = true
    }

    /** Есть ли чем проверять: без блокировки экрана замок не включить. */
    fun ready(context: Context): Boolean = runCatching {
        BiometricManager.from(context).canAuthenticate(BIOMETRIC_WEAK or DEVICE_CREDENTIAL) == BiometricManager.BIOMETRIC_SUCCESS
    }.getOrDefault(false)

    fun close() {
        if (!on || asking) return
        open = false
    }

    fun unlock(activity: FragmentActivity) {
        if (open || asking) return
        if (!ready(activity)) {
            // Блокировку экрана сняли — запертым сад остаться не может.
            turn(false)
            return
        }
        asking = true
        val prompt = BiometricPrompt(
            activity,
            ContextCompat.getMainExecutor(activity),
            object : BiometricPrompt.AuthenticationCallback() {
                override fun onAuthenticationSucceeded(result: BiometricPrompt.AuthenticationResult) {
                    asking = false
                    open = true
                }

                override fun onAuthenticationError(errorCode: Int, errString: CharSequence) {
                    asking = false
                }
            },
        )
        val info = BiometricPrompt.PromptInfo.Builder()
            .setTitle("Sprout")
            .setSubtitle(Lang.text("Чтобы открыть сад"))
            .setAllowedAuthenticators(BIOMETRIC_WEAK or DEVICE_CREDENTIAL)
            .build()
        runCatching { prompt.authenticate(info) }.onFailure { asking = false }
    }
}
