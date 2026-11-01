package com.centaurlabs.est

import java.math.BigInteger
import java.time.LocalDate

/** Swift's SplitMix64, Seed.daily and forward shuffle, including UInt64 rejection sampling. */
object DailyDeck {
    private val mask = BigInteger.ONE.shiftLeft(64).subtract(BigInteger.ONE)
    private class Generator(var state: ULong) {
        fun next(): ULong {
            state += 0x9E3779B97F4A7C15uL
            var z = state
            z = (z xor (z shr 30)) * 0xBF58476D1CE4E5B9uL
            z = (z xor (z shr 27)) * 0x94D049BB133111EBuL
            return z xor (z shr 31)
        }
        fun bounded(bound: Int): Int {
            val upper = BigInteger.valueOf(bound.toLong())
            val threshold = BigInteger.ONE.shiftLeft(64).mod(upper)
            while (true) {
                val product = BigInteger(next().toString()).multiply(upper)
                if (product.and(mask) >= threshold) return product.shiftRight(64).toInt()
            }
        }
    }
    fun cards(date: LocalDate): List<Int> {
        var hash = 0xCBF29CE484222325uL
        for (byte in "est".toByteArray()) hash = (hash xor byte.toUByte().toULong()) * 0x100000001B3uL
        val day = (date.year * 10000 + date.monthValue * 100 + date.dayOfMonth).toULong()
        val seed = Generator(day xor (hash * 0x9E3779B97F4A7C15uL)).next()
        val generator = Generator(seed)
        val cards = (0..80).toMutableList()
        for (index in 0 until cards.lastIndex) {
            val other = index + generator.bounded(cards.size - index)
            val old = cards[index]; cards[index] = cards[other]; cards[other] = old
        }
        return cards
    }
}
