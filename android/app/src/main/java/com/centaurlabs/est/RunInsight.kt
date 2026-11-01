package com.centaurlabs.est

class RunInsight {
    private val counts = IntArray(5)
    private val seconds = DoubleArray(5)
    private val misses = IntArray(4)
    private var fastest: Double? = null
    private var slowest: Double? = null
    fun record(cards: List<EstCard>, elapsed: Double) {
        if (EstCard.valid(cards)) {
            val time = elapsed.coerceAtLeast(0.0)
            val differences = (0..3).count { trait -> cards.map { it.traits[trait] }.distinct().size == 3 }
            counts[differences]++; seconds[differences] += time
            fastest = minOf(fastest ?: time, time); slowest = maxOf(slowest ?: time, time)
        } else EstCard.audit(cards).forEachIndexed { i, valid -> if (!valid) misses[i]++ }
    }
    fun lines(): List<String> = buildList {
        if (counts.sum() > 1) add("Fastest set ${shortSeconds(fastest!!)}, slowest ${shortSeconds(slowest!!)}")
        val kinds = (1..4).filter { counts[it] > 0 }
        if (kinds.size > 1) {
            val kind = kinds.maxBy { seconds[it]/counts[it] }
            add("Slowest when ${if (kind == 1) "1 trait differs" else "$kind traits differ"}: ${shortSeconds(seconds[kind]/counts[kind])} on average")
        }
        val trait = misses.indices.maxBy { misses[it] }
        if (misses[trait] > 0) add("${misses.sum()} ${if (misses.sum() == 1) "miss" else "misses"}, most often on ${EstCard.traitNames[trait].lowercase()}")
        else if (counts.sum() > 0) add("No misses")
    }
}
fun shortSeconds(seconds: Double): String = "%.1fs".format(java.util.Locale.US, seconds.coerceAtLeast(0.0))
