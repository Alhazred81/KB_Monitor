package com.example.app

import android.content.Context
import android.media.AudioManager
import android.media.ToneGenerator
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "hive_monitor/alarm"
    private val mainHandler = Handler(Looper.getMainLooper())
    private var isSirenRunning = false
    private var toneGenerator: ToneGenerator? = null
    private var savedAlarmVolume: Int? = null

    private val sirenRunnable = object : Runnable {
        override fun run() {
            if (!isSirenRunning) return
            try {
                if (toneGenerator == null) {
                    toneGenerator = ToneGenerator(AudioManager.STREAM_ALARM, 100)
                }
                toneGenerator?.startTone(ToneGenerator.TONE_CDMA_EMERGENCY_RINGBACK, 430)
                pulseVibration(380)
            } catch (_: Exception) {
            }
            if (isSirenRunning) {
                mainHandler.postDelayed(this, 650)
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startAlarm" -> {
                        startAlarmStreamOverrideMute()
                        result.success(true)
                    }
                    "stopAlarm" -> {
                        stopAlarmStream()
                        result.success(true)
                    }
                    "playOnce" -> {
                        playSingleAlertTone()
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun startAlarmStreamOverrideMute() {
        try {
            val audioManager = getSystemService(Context.AUDIO_SERVICE) as? AudioManager
            if (audioManager != null) {
                val currentVol = audioManager.getStreamVolume(AudioManager.STREAM_ALARM)
                val maxVol = audioManager.getStreamMaxVolume(AudioManager.STREAM_ALARM)
                if (savedAlarmVolume == null) {
                    savedAlarmVolume = currentVol
                }
                // STREAM_ALARM a néma/rezgő módot automatikusan felülírja Androidon;
                // ha az ébresztő-hangerő le volt halkítva, maximumra emeljük a nyugtázásig!
                if (maxVol > 0 && currentVol < maxVol) {
                    audioManager.setStreamVolume(AudioManager.STREAM_ALARM, maxVol, 0)
                }
            }
        } catch (_: Exception) {
        }

        if (!isSirenRunning) {
            isSirenRunning = true
            mainHandler.removeCallbacks(sirenRunnable)
            mainHandler.post(sirenRunnable)
        }
    }

    private fun stopAlarmStream() {
        isSirenRunning = false
        mainHandler.removeCallbacks(sirenRunnable)
        try {
            toneGenerator?.stopTone()
            toneGenerator?.release()
        } catch (_: Exception) {
        }
        toneGenerator = null

        try {
            getVibratorInstance()?.cancel()
        } catch (_: Exception) {
        }

        val prevVol = savedAlarmVolume
        savedAlarmVolume = null
        if (prevVol != null) {
            try {
                val audioManager = getSystemService(Context.AUDIO_SERVICE) as? AudioManager
                audioManager?.setStreamVolume(AudioManager.STREAM_ALARM, prevVol, 0)
            } catch (_: Exception) {
            }
        }
    }

    private fun playSingleAlertTone() {
        try {
            val singleTone = ToneGenerator(AudioManager.STREAM_ALARM, 90)
            singleTone.startTone(ToneGenerator.TONE_PROP_ACK, 260)
            pulseVibration(180)
            mainHandler.postDelayed({
                try {
                    singleTone.release()
                } catch (_: Exception) {
                }
            }, 400)
        } catch (_: Exception) {
        }
    }

    private fun getVibratorInstance(): Vibrator? {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val vm = getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as? VibratorManager
            vm?.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
        }
    }

    private fun pulseVibration(durationMs: Long) {
        try {
            val vibrator = getVibratorInstance() ?: return
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                vibrator.vibrate(
                    VibrationEffect.createOneShot(durationMs, VibrationEffect.DEFAULT_AMPLITUDE)
                )
            } else {
                @Suppress("DEPRECATION")
                vibrator.vibrate(durationMs)
            }
        } catch (_: Exception) {
        }
    }

    override fun onDestroy() {
        stopAlarmStream()
        super.onDestroy()
    }
}
