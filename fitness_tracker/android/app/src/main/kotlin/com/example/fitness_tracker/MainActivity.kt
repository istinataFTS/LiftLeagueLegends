package com.example.fitness_tracker

import android.content.Intent
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.KeyEvent
import android.support.v4.media.session.MediaSessionCompat
import android.support.v4.media.session.PlaybackStateCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val methodChannelName = "app/voice_media_button"
    private val eventChannelName = "app/voice_media_button_events"

    private var mediaSession: MediaSessionCompat? = null
    private var eventSink: EventChannel.EventSink? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    // Debounce: collapse the rapid down/up pair (and accidental double taps)
    // into a single wake within this window.
    private var lastPressAt = 0L
    private val debounceMs = 600L

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, eventChannelName)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(args: Any?, sink: EventChannel.EventSink?) {
                    eventSink = sink
                }
                override fun onCancel(args: Any?) {
                    eventSink = null
                }
            })

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, methodChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "start" -> { startSession(); result.success(null) }
                    "stop" -> { stopSession(); result.success(null) }
                    else -> result.notImplemented()
                }
            }
    }

    private fun startSession() {
        if (mediaSession != null) return
        val session = MediaSessionCompat(this, "LiftLeagueVoice")
        session.setFlags(MediaSessionCompat.FLAG_HANDLES_MEDIA_BUTTONS)
        session.setCallback(object : MediaSessionCompat.Callback() {
            override fun onMediaButtonEvent(intent: Intent): Boolean {
                val key = intent.getParcelableExtra<KeyEvent>(Intent.EXTRA_KEY_EVENT)
                if (key != null && key.action == KeyEvent.ACTION_DOWN) {
                    when (key.keyCode) {
                        KeyEvent.KEYCODE_HEADSETHOOK,
                        KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE,
                        KeyEvent.KEYCODE_MEDIA_PLAY,
                        KeyEvent.KEYCODE_MEDIA_PAUSE -> { emitPress(); return true }
                    }
                }
                return super.onMediaButtonEvent(intent)
            }
            override fun onPlay() { emitPress() }
            override fun onPause() { emitPress() }
        })
        // Required for the session to be eligible to receive media buttons.
        session.setPlaybackState(
            PlaybackStateCompat.Builder()
                .setActions(
                    PlaybackStateCompat.ACTION_PLAY_PAUSE or
                        PlaybackStateCompat.ACTION_PLAY or
                        PlaybackStateCompat.ACTION_PAUSE
                )
                .setState(PlaybackStateCompat.STATE_PAUSED, 0L, 0f)
                .build()
        )
        session.isActive = true
        mediaSession = session
    }

    private fun stopSession() {
        mediaSession?.isActive = false
        mediaSession?.release()
        mediaSession = null
    }

    private fun emitPress() {
        val now = System.currentTimeMillis()
        if (now - lastPressAt < debounceMs) return
        lastPressAt = now
        mainHandler.post { eventSink?.success(null) }
    }

    override fun onDestroy() {
        stopSession()
        super.onDestroy()
    }
}
