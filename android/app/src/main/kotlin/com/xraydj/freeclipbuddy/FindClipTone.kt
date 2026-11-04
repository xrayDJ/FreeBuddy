package com.xraydj.freeclipbuddy

import android.content.Context
import android.media.AudioManager
import android.media.ToneGenerator
import android.os.Handler
import android.os.Looper
import android.util.Log

/**
 * Loud repeating beep on the media stream, to find a lost clip.
 *
 * Media audio goes to the connected Bluetooth output, so the beep comes out of
 * whichever clip is still connected (put the other one in the closed case).
 * No MBB "ring" command is known for FreeClip 2, so this doesn't need one.
 *
 * Volume is raised to max while beeping and restored on [stop].
 */
class FindClipTone(context: Context) {
    companion object {
        const val TAG = "FindClipTone"
        private const val BEEP_MS = 1000
        private const val PERIOD_MS = 1500L
    }

    private val audio = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
    private val handler = Handler(Looper.getMainLooper())
    private var tone: ToneGenerator? = null
    private var savedVolume: Int? = null

    private val beep = object : Runnable {
        override fun run() {
            tone?.startTone(ToneGenerator.TONE_CDMA_ALERT_CALL_GUARD, BEEP_MS)
            handler.postDelayed(this, PERIOD_MS)
        }
    }

    /** Throws if the tone generator can't be created */
    fun start() {
        if (tone != null) return
        tone = ToneGenerator(AudioManager.STREAM_MUSIC, ToneGenerator.MAX_VOLUME)
        try {
            savedVolume = audio.getStreamVolume(AudioManager.STREAM_MUSIC)
            audio.setStreamVolume(
                AudioManager.STREAM_MUSIC,
                audio.getStreamMaxVolume(AudioManager.STREAM_MUSIC),
                0,
            )
        } catch (e: SecurityException) {
            // still beep, just at the current volume
            Log.w(TAG, "Can't change media volume", e)
            savedVolume = null
        }
        handler.post(beep)
    }

    fun stop() {
        handler.removeCallbacks(beep)
        tone?.let {
            it.stopTone()
            it.release()
        }
        tone = null
        savedVolume?.let {
            try {
                audio.setStreamVolume(AudioManager.STREAM_MUSIC, it, 0)
            } catch (e: SecurityException) {
                Log.w(TAG, "Can't restore media volume", e)
            }
        }
        savedVolume = null
    }
}
