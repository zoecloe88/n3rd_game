package com.example.n3rd_game

import io.flutter.embedding.android.FlutterActivity
import android.media.AudioManager
import android.content.Context

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Configure audio to allow background music
        // User's music (Spotify, YouTube Music, etc.) will continue playing
        val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        // Request transient audio focus that allows ducking
        // This allows other apps' audio to continue while app plays sounds
        audioManager.requestAudioFocus(
            null,
            AudioManager.STREAM_MUSIC,
            AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK
        )
    }
}
