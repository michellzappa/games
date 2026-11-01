package com.centaurlabs.est

import android.content.Context
import android.media.AudioAttributes
import android.media.SoundPool

/** Original iOS sound palette rendered by scripts/generate_audio.py. */
class GameAudio(context: Context) {
    private val pool = SoundPool.Builder().setMaxStreams(6).setAudioAttributes(
        AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_GAME).setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION).build()
    ).build()
    private val sounds = mapOf("selected_1" to R.raw.selected_1, "selected_2" to R.raw.selected_2, "selected_3" to R.raw.selected_3,
        "deselected" to R.raw.card_deselected, "deal" to R.raw.deal, "match" to R.raw.valid_set, "mismatch" to R.raw.mismatch,
        "hint" to R.raw.hint, "buzz" to R.raw.buzz, "penalty" to R.raw.penalty, "completion" to R.raw.completion).mapValues { pool.load(context, it.value, 1) }
    fun play(name: String) { sounds[name]?.let { pool.play(it, 1f, 1f, 1, 0, 1f) } }
    fun release() { pool.release() }
}
