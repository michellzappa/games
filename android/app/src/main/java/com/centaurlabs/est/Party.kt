package com.centaurlabs.est

import kotlin.random.Random

/** PartySession + ClaimRace, with the same 5s claim and 4s escalating lockout. */
class Party(val playerCount: Int, private val clock: () -> Long, random: Random = Random.Default) {
    init { require(playerCount == 2 || playerCount == 4) }
    val engine = Game(clock, Mode.FULL, random)
    val scores = MutableList(playerCount) { 0 }
    val collected = List(playerCount) { mutableListOf<Int>() }
    val lockedUntil = MutableList(playerCount) { 0L }
    private val penalties = MutableList(playerCount) { 0 }
    var active: Int? = null; private set
    var deadline = 0L; private set
    var penaltyToken = 0; private set
    fun canBuzz(id: Int) = id in scores.indices && !engine.finished && active == null && clock() >= lockedUntil[id]
    fun buzz(id: Int): Boolean {
        if (!canBuzz(id)) return false
        active = id; deadline = clock() + 5000
        return true
    }
    fun remaining(id: Int) = (if (active == id) deadline else lockedUntil[id]) - clock()
    fun select(id: Int): Boolean {
        tick()
        val player = active ?: return false
        val before = engine.selected
        val matched = engine.select(id)
        if (matched) {
            scores[player]++; collected[player].addAll(engine.pending); active = null
        } else if (before.size == 2 && id !in before && engine.selected.isEmpty() && engine.pending.isEmpty()) {
            penalize(player); active = null
        }
        return matched
    }
    fun tick() {
        engine.tick()
        val player = active
        if (player != null && clock() >= deadline) {
            active = null; engine.clearSelection(); penalize(player)
        }
    }
    private fun penalize(id: Int) {
        scores[id] = (scores[id] - 1).coerceAtLeast(0)
        penalties[id]++
        lockedUntil[id] = clock() + 4000 + (penalties[id]-1)*1000
        penaltyToken++
    }
}
