package com.centaurlabs.est

import android.app.Application
import android.os.SystemClock
import androidx.core.content.edit
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json

class GameModel(app: Application) : AndroidViewModel(app) {
    private val prefs = app.getSharedPreferences("est", 0)
    val audio = GameAudio(app)
    override fun onCleared() { audio.release() }
    private fun play(name: String) { if (sound) audio.play(name) }
    private val json = Json { ignoreUnknownKeys = true }
    var stats = runCatching { json.decodeFromString<PlayerStats>(prefs.getString("stats", "{}")!!) }.getOrElse { PlayerStats() }; private set
    private var lastMatchElapsed = 0L
    private fun saveStats() { prefs.edit { putString("stats", json.encodeToString(stats)) } }
    fun resetStats(includeBests: Boolean) {
        stats = PlayerStats(); saveStats()
        if (includeBests) prefs.edit { remove("best_FULL"); remove("best_QUICK") }
        revision++
    }
    var party: Party? = null; private set
    fun startParty(count: Int) { party = Party(count, SystemClock::elapsedRealtime); screen = "party"; revision++; play("deal") }
    fun leaveParty() { party = null; screen = "home"; revision++ }
    fun buzz(id: Int) { if (party?.buzz(id) == true) play("buzz"); revision++ }
    fun partySelect(id: Int) {
        val current = party ?: return
        val penalties = current.penaltyToken
        if (current.select(id)) play("match") else if (current.penaltyToken > penalties) play("penalty")
        revision++
    }
    var quickTrait by mutableIntStateOf(prefs.getInt("quickTrait", 3)); private set
    fun chooseQuickTrait(trait: Int) { quickTrait = trait; prefs.edit { putInt("quickTrait", trait) } }
    var isDaily = false; private set
    private var dailyDay = java.time.LocalDate.now(java.time.ZoneOffset.UTC).toEpochDay()
    var insight = RunInsight(); private set
    fun dailyBest(day: Long = java.time.LocalDate.now(java.time.ZoneOffset.UTC).toEpochDay()): Long? =
        prefs.getLong("dailyBestTime", -1).takeIf { it > 0 && prefs.getLong("dailyBestDay", -1) == day }
    fun dailyStreak(): Int {
        val today = java.time.LocalDate.now(java.time.ZoneOffset.UTC).toEpochDay()
        return if (prefs.getLong("dailyLastDay", -2) in (today-1)..today) prefs.getInt("dailyStreak", 0) else 0
    }
    fun dailyTitle(): String = if (dailyBest() != null) {
        if (dailyStreak() > 1) "Daily done, ${dailyStreak()} days" else "Daily done"
    } else if (dailyStreak() > 0) "Daily, ${dailyStreak()} day streak" else "Daily deal"
    fun resumeTitle(): String = load()?.let { "Resume, ${it.done.size/3} of ${it.mode.deck().size/3}" } ?: "Resume"
    var dialogOpen = false
    var game: Game? = null; private set
    var revision by mutableIntStateOf(0); private set
    var screen by mutableStateOf(if (prefs.getBoolean("learned", false)) "home" else "tutorial")
    var dark by mutableStateOf(prefs.getBoolean("dark", false)); private set
    var orchard by mutableStateOf(prefs.getBoolean("orchard", false)); private set
    var sound by mutableStateOf(prefs.getBoolean("sound", true)); private set
    var haptics by mutableStateOf(prefs.getBoolean("haptics", true)); private set
    var pinstripes by mutableStateOf(prefs.getBoolean("pinstripes", true)); private set
    var reduceMotion by mutableStateOf(prefs.getBoolean("reduceMotion", false)); private set
    var highContrast by mutableStateOf(prefs.getBoolean("highContrast", false)); private set
    var assist by mutableStateOf(prefs.getBoolean("assist", false)); private set
    var showTimer by mutableStateOf(prefs.getBoolean("showTimer", true)); private set
    var keepAwake by mutableStateOf(prefs.getBoolean("keepAwake", false)); private set
    var immersive by mutableStateOf(prefs.getBoolean("immersive", true)); private set
    var colorScheme by mutableIntStateOf(prefs.getInt("colorScheme", 0)); private set
    fun chooseColorScheme(value: Int) { colorScheme = value; prefs.edit { putInt("colorScheme", value) } }
    var hasSave by mutableStateOf(load() != null); private set
    var trainingBest by mutableIntStateOf(prefs.getInt("trainingBest", 0)); private set
    private var recorded = false
    private var ticks = 0
    init {
        viewModelScope.launch {
            while (true) {
                delay(100)
                party?.let {
                    val penalty = it.penaltyToken
                    val finished = it.engine.finished
                    it.tick()
                    if (it.penaltyToken > penalty) play("penalty")
                    if (it.engine.finished && !finished) play("completion")
                    revision++
                }
                game?.let {
                    if (!it.paused && !it.finished) { val deck = it.deck.size; it.tick(); if (it.deck.size < deck) play("deal"); revision++; if (++ticks % 10 == 0) persist() }
                    recordFinish()
                }
            }
        }
    }
    private fun load(): SavedGame? = runCatching {
        prefs.getString("run", null)?.let { json.decodeFromString<SavedGame>(it) }
            ?.takeIf { it.valid(System.currentTimeMillis()) }
    }.getOrNull()
    fun start(mode: Mode, daily: Boolean = false) {
        isDaily = daily
        dailyDay = java.time.LocalDate.now(java.time.ZoneOffset.UTC).toEpochDay()
        insight = RunInsight()
        game = Game(SystemClock::elapsedRealtime, mode, quickTrait = quickTrait, orderedDeck = if (daily) DailyDeck.cards(java.time.LocalDate.ofEpochDay(dailyDay)) else null); recorded = false; lastMatchElapsed = 0
        screen = "game"; revision++; persist(); play("deal")
    }
    fun restore() {
        isDaily = false; insight = RunInsight(); lastMatchElapsed = 0
        game = load()?.let { Game.restore(it, System.currentTimeMillis(), SystemClock::elapsedRealtime) }
        recorded = false
        if (game != null) { game?.resume(); screen = "game"; recordFinish() }
        else { hasSave = false; prefs.edit { remove("run") } }
        revision++
    }
    fun select(id: Int): Boolean {
        val active = game ?: return false
        val deselecting = id in active.selected
        val count = active.selected.size
        val chosen = if (!deselecting && count == 2) (active.selected + id).map(::EstCard) else emptyList()
        val available = EstCard.countSets(active.table.map(::EstCard))
        val wasHinted = chosen.any { it.id in active.hinted }
        val matched = active.select(id)
        if (chosen.size == 3 && !active.paused && (matched || active.pending.isEmpty()) && !active.finished) {
            stats.record(chosen, available, (active.elapsed - lastMatchElapsed) / 1000.0, wasHinted)
            insight.record(chosen, (active.elapsed - lastMatchElapsed) / 1000.0)
            if (matched) lastMatchElapsed = active.elapsed
            saveStats()
        }
        if (matched) play("match")
        else if (deselecting) play("deselected")
        else if (count == 2 && active.selected.isEmpty()) play("mismatch")
        else play("selected_${active.selected.size.coerceIn(1,3)}")
        revision++; persist(); return matched
    }
    fun hint() { game?.hint(); revision++; persist(); play("hint") }
    fun pause() { game?.pause(); revision++; recordFinish(); persist() }
    fun resume() { game?.resume(); revision++ }
    fun leave(discard: Boolean) {
        pause()
        dialogOpen = false
        if (discard && !isDaily) { prefs.edit { remove("run") }; hasSave = false }
        game = null; screen = "home"; revision++
    }
    private fun persist() {
        val active = game ?: return
        if (active.finished || isDaily) return
        prefs.edit { putString("run", json.encodeToString(active.save(System.currentTimeMillis()))) }
        hasSave = true
    }
    private fun recordFinish() {
        val active = game ?: return
        if (!active.finished || recorded) return
        recorded = true
        play("completion")
        stats.rounds++; if (active.mode == Mode.FULL) stats.fullRounds++ else stats.quickRounds++
        saveStats()
        if (isDaily) {
            val last = prefs.getLong("dailyLastDay", Long.MIN_VALUE)
            prefs.edit {
                if (active.elapsed < (dailyBest(dailyDay) ?: Long.MAX_VALUE)) {
                    putLong("dailyBestDay", dailyDay); putLong("dailyBestTime", active.elapsed)
                }
                if (dailyDay > last) {
                    putLong("dailyLastDay", dailyDay)
                    putInt("dailyStreak", if (last == dailyDay - 1) prefs.getInt("dailyStreak", 0) + 1 else 1)
                }
            }
            revision++; return
        }
        val key = "best_${active.mode.name}"
        val best = prefs.getLong(key, Long.MAX_VALUE)
        prefs.edit {
            putLong(key, minOf(best, active.elapsed))
            putInt("rounds", prefs.getInt("rounds", 0) + 1)
            remove("run")
        }
        hasSave = false; revision++
    }
    fun best(mode: Mode) = prefs.getLong("best_${mode.name}", -1).takeIf { it >= 0 }
    fun rounds() = prefs.getInt("rounds", 0)
    fun learned() { prefs.edit { putBoolean("learned", true) }; screen = "home" }
    fun training(streak: Int) {
        if (streak > trainingBest) { trainingBest = streak; prefs.edit { putInt("trainingBest", streak) } }
    }
    fun toggle(key: String) {
        val next = when (key) {
            "dark" -> (!dark).also { dark = it }
            "orchard" -> (!orchard).also { orchard = it }
            "reduceMotion" -> (!reduceMotion).also { reduceMotion = it }
            "highContrast" -> (!highContrast).also { highContrast = it }
            "pinstripes" -> (!pinstripes).also { pinstripes = it }
            "assist" -> (!assist).also { assist = it }
            "showTimer" -> (!showTimer).also { showTimer = it }
            "keepAwake" -> (!keepAwake).also { keepAwake = it }
            "immersive" -> (!immersive).also { immersive = it }
            "sound" -> (!sound).also { sound = it }
            else -> (!haptics).also { haptics = it }
        }
        prefs.edit { putBoolean(key, next) }
    }
}

fun formatTime(ms: Long): String = "%02d:%02d".format(ms.coerceAtLeast(0) / 60_000, ms.coerceAtLeast(0) / 1_000 % 60)
