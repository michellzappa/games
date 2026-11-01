package com.centaurlabs.est

import kotlinx.serialization.Serializable

/** PlayerStats.Snapshot and reducers, matching the iOS aggregate fields. */
@Serializable
data class PlayerStats(
    var rounds: Int = 0, var quickRounds: Int = 0, var fullRounds: Int = 0,
    var attempts: Int = 0, var correctSets: Int = 0,
    val correctByDifference: MutableList<Int> = MutableList(5) { 0 },
    val secondsByDifference: MutableList<Double> = MutableList(5) { 0.0 },
    val mismatchesByTrait: MutableList<Int> = MutableList(4) { 0 },
    val boardSetBuckets: MutableList<Int> = MutableList(4) { 0 },
    var nearMisses: Int = 0, var fastestSet: Double? = null, var longestStreak: Int = 0, var currentStreak: Int = 0
) {
    fun record(cards: List<EstCard>, available: Int, seconds: Double, hinted: Boolean = false) {
        require(cards.size == 3)
        attempts++
        boardSetBuckets[available.coerceIn(0,3)]++
        if (EstCard.valid(cards)) {
            correctSets++
            currentStreak++
            longestStreak = maxOf(longestStreak, currentStreak)
            if (!hinted && seconds > 0 && seconds < (fastestSet ?: Double.POSITIVE_INFINITY)) fastestSet = seconds
            val differences = (0..3).count { trait -> cards.map { it.traits[trait] }.distinct().size == 3 }
            correctByDifference[differences]++
            secondsByDifference[differences] += seconds.coerceAtLeast(0.0)
        } else {
            currentStreak = 0
            val failed = EstCard.audit(cards).mapIndexedNotNull { i, pass -> if (!pass) i else null }
            failed.forEach { mismatchesByTrait[it]++ }
            if (failed.size == 1) nearMisses++
        }
    }
}
