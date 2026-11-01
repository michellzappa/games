package com.centaurlabs.est

import kotlinx.serialization.Serializable
import kotlin.random.Random

/** The wire identity is identical to EST/Models/Card.swift. */
data class EstCard(val id: Int) {
    init { require(id in 0..80) }
    val count get() = id / 27 + 1
    val tint get() = id % 27 / 9
    val symbol get() = id % 9 / 3
    val fill get() = id % 3
    val traits get() = listOf(count - 1, tint, symbol, fill)
    val description get() = "$count ${colors[tint]} ${fills[fill]} ${shapes[symbol]}${if (count > 1) "s" else ""}"
    companion object {
        val colors = listOf("red", "blue", "yellow")
        val shapes = listOf("circle", "square", "triangle")
        val fills = listOf("solid", "outline", "shaded")
        val traitNames = listOf("Number", "Color", "Shape", "Fill")
        fun complete(a: EstCard, b: EstCard): EstCard {
            val t = a.traits.zip(b.traits).map { (x, y) -> 2 * (x + y) % 3 }
            return EstCard(t[0] * 27 + t[1] * 9 + t[2] * 3 + t[3])
        }
        fun audit(cards: List<EstCard>): List<Boolean> {
            require(cards.size == 3)
            return (0..3).map { trait -> cards.map { it.traits[trait] }.distinct().size != 2 }
        }
        fun valid(cards: List<EstCard>) = cards.size == 3 && cards.distinct().size == 3 && audit(cards).all { it }
        fun countSets(cards: List<EstCard>): Int {
            val present = cards.toSet()
            var pairs = 0
            for (i in cards.indices) for (j in i + 1 until cards.size) if (complete(cards[i], cards[j]) in present) pairs++
            return pairs / 3
        }
        fun randomSet(): List<EstCard> {
            val pair = (0..80).shuffled().take(2).map(::EstCard)
            return (pair + complete(pair[0], pair[1])).shuffled()
        }
        fun nearMiss(): List<EstCard> {
            val set = randomSet()
            val trait = (0..3).firstOrNull { set[0].traits[it] == set[1].traits[it] } ?: 1
            val t = set[2].traits.toMutableList()
            t[trait] = (t[trait] + 1) % 3
            return listOf(set[0], set[1], EstCard(t[0]*27 + t[1]*9 + t[2]*3 + t[3])).shuffled()
        }
        fun nearMiss(trait: Int): List<EstCard> {
            val a = EstCard(Random.nextInt(81))
            val b = (0..80).map(::EstCard).filter { it != a && it.traits[trait] == a.traits[trait] }.random()
            val t = complete(a, b).traits.toMutableList()
            t[trait] = (t[trait] + 1) % 3
            return listOf(a, b, EstCard(t[0]*27+t[1]*9+t[2]*3+t[3])).shuffled()
        }
        fun trainingTrio(misses: List<Int> = emptyList()): List<EstCard> {
            if (Random.nextBoolean()) return randomSet()
            if (Random.nextInt(4) > 0) {
                if (misses.size != 4 || misses.none { it > 0 }) return nearMiss()
                val weights = misses.map { it.coerceAtLeast(0) + 1 }
                var pick = Random.nextInt(weights.sum())
                for (trait in 0..3) { pick -= weights[trait]; if (pick < 0) return nearMiss(trait) }
            }
            while (true) {
                val trio = (0..80).shuffled().take(3).map(::EstCard)
                if (!valid(trio)) return trio
            }
        }
        fun practiceBoard(): List<EstCard> {
            repeat(40) {
                var cards = randomSet()
                for (id in (0..80).shuffled()) {
                    val card = EstCard(id)
                    if (cards.size < 6 && card !in cards && countSets(cards + card) == 1) cards = cards + card
                }
                if (cards.size == 6) return cards.shuffled()
            }
            return randomSet()
        }
        fun find(cards: List<EstCard>): List<EstCard>? {
            val present = cards.toSet()
            for (i in cards.indices) for (j in i + 1 until cards.size) {
                val third = complete(cards[i], cards[j])
                if (third != cards[i] && third != cards[j] && third in present) return listOf(cards[i], cards[j], third)
            }
            return null
        }
    }
}

@Serializable
enum class Mode(val title: String, val baseline: Int, val minimumMs: Long) {
    FULL("Solo 81", 12, 18_000), QUICK("Quick 27", 9, 4_500);
    fun deck(quickTrait: Int = 3) = (0..80).filter { this == FULL || EstCard(it).traits[quickTrait] == 0 }
}

@Serializable
data class SavedGame(
    val mode: Mode, val deck: List<Int>, val table: List<Int>, val done: List<Int>,
    val elapsedMs: Long, val hintUsed: Boolean, val savedAt: Long,
    val pending: List<Int> = emptyList(), val matchElapsedMs: Long = 0,
    val schema: Int = 1, val quickTrait: Int = 3
) {
    fun valid(now: Long): Boolean {
        val all = deck + table + done
        return schema == 1 && quickTrait in 0..3 && now >= savedAt && now - savedAt <= 3 * 86_400_000L &&
            elapsedMs >= 0 && matchElapsedMs in 0..elapsedMs &&
            all.size == mode.deck(quickTrait).size && all.toSet() == mode.deck(quickTrait).toSet() &&
            table.size >= 3 && done.size % 3 == 0 && deck.size % 3 == 0 && table.size % 3 == 0 &&
            done.chunked(3).all { EstCard.valid(it.map(::EstCard)) } &&
            EstCard.find(table.map(::EstCard)) != null &&
            (pending.isEmpty() || (pending.all { it in table } && EstCard.valid(pending.map(::EstCard))))
    }
}

/** Pure Kotlin state machine. The caller supplies a monotonic millisecond clock. */
class Game(private val clock: () -> Long, val mode: Mode, random: Random = Random.Default, val quickTrait: Int = 3, orderedDeck: List<Int>? = null) {
    var deck = orderedDeck ?: mode.deck(quickTrait).shuffled(random); private set
    var table = emptyList<Int>(); private set
    var done = emptyList<Int>(); private set
    var selected = emptyList<Int>(); private set
    var pending = emptyList<Int>(); private set
    var message = "Find three cards that belong together."; private set
    var mismatchIds = emptyList<Int>(); private set
    var mismatchToken = 0; private set
    private var mismatchAt = 0L
    var finished = false; private set
    var paused = false; private set
    var wasPaused = false; private set
    var hintUsed = false; private set
    var hinted = emptyList<Int>(); private set
    private var accumulated = 0L
    private var started = clock()
    private var matchAt = 0L
    private var matchElapsed = 0L
    val elapsed: Long get() = accumulated + if (paused || finished) 0 else (clock() - started).coerceAtLeast(0)
    val eligible get() = finished && !hintUsed && !wasPaused && elapsed >= mode.minimumMs
    init { draw(mode.baseline); ensureSet() }
    private fun draw(n: Int) { table = table + deck.take(n); deck = deck.drop(n) }
    private fun ensureSet() { while (EstCard.find(table.map(::EstCard)) == null && deck.isNotEmpty()) draw(3) }
    fun select(id: Int): Boolean {
        if (paused || finished || pending.isNotEmpty() || id !in table) return false
        selected = if (id in selected) selected - id else selected + id
        if (selected.size != 3) return false
        val cards = selected.map(::EstCard)
        if (EstCard.valid(cards)) {
            pending = selected; matchAt = clock(); matchElapsed = elapsed
            message = "That's an EST!"
        } else {
            val broken = EstCard.audit(cards).mapIndexedNotNull { i, ok -> if (ok) null else EstCard.traitNames[i].lowercase() }
            mismatchIds = selected; mismatchToken++; mismatchAt = clock()
            message = "Not a set\n" + (0..3).filter { !EstCard.audit(cards)[it] }.joinToString("\n") { trait ->
                val values = cards.map { card -> when (trait) { 0 -> card.count.toString(); 1 -> EstCard.colors[card.tint]; 2 -> EstCard.shapes[card.symbol]; else -> EstCard.fills[card.fill] } }
                val pair = values.first { v -> values.count { it == v } == 2 }
                val odd = values.first { it != pair }
                "${EstCard.traitNames[trait].lowercase()}: $pair, $pair vs $odd"
            }
        }
        selected = emptyList()
        return pending.isNotEmpty()
    }
    fun clearSelection() { selected = emptyList() }
    fun hint() {
        if (paused || finished || pending.isNotEmpty()) return
        hintUsed = true
        hinted = EstCard.find(table.map(::EstCard))?.take((hinted.size + 1).coerceAtMost(2))?.map { it.id }.orEmpty()
        message = "A card from a set is outlined. This run counts toward your personal best."
    }
    fun tick() {
        if (pending.isNotEmpty() && clock() - matchAt >= 900) resolve()
        if (message.startsWith("Not a set") && clock() - mismatchAt >= 5000) message = ""
    }
    private fun resolve() {
        if (pending.isEmpty()) return
        done = done + pending
        if (table.size <= mode.baseline && deck.size >= 3) {
            val replacements = deck.take(3).iterator()
            table = table.map { if (it in pending) replacements.next() else it }
            deck = deck.drop(3)
        } else table = table.filterNot { it in pending }
        pending = emptyList(); hinted = emptyList()
        ensureSet()
        finished = deck.isEmpty() && EstCard.find(table.map(::EstCard)) == null
        if (finished) { accumulated = matchElapsed; message = if (table.isEmpty()) "A perfect clear." else "No more trios. Nicely done." }
        else message = "Find your next trio."
    }
    fun pause() {
        if (finished || paused) return
        // Settle a matched trio before persisting, without charging its final animation.
        resolve()
        if (finished) return
        accumulated = elapsed; paused = true; wasPaused = true; selected = emptyList()
    }
    fun resume() { if (paused && !finished) { started = clock(); paused = false } }
    fun save(now: Long) = SavedGame(mode, deck, table, done, elapsed, hintUsed, now, pending, matchElapsed.coerceAtMost(elapsed), quickTrait = quickTrait)
    companion object {
        fun restore(saved: SavedGame, now: Long, clock: () -> Long): Game? {
            if (!saved.valid(now)) return null
            return Game(clock, saved.mode, quickTrait = saved.quickTrait).apply {
                deck = saved.deck; table = saved.table; done = saved.done
                accumulated = saved.elapsedMs; started = clock(); hintUsed = saved.hintUsed
                pending = saved.pending; matchElapsed = saved.matchElapsedMs
                wasPaused = true; paused = true
                resolve()
                finished = deck.isEmpty() && EstCard.find(table.map(::EstCard)) == null
            }
        }
    }
}
