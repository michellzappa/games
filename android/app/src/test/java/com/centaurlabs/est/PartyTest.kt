package com.centaurlabs.est
import org.junit.Assert.*
import org.junit.Test
import kotlin.random.Random
class PartyTest {
    @Test fun buzzerHasExclusiveFiveSecondWindowAndEscalatingPenalty() {
        var now = 0L
        val party = Party(2, { now }, Random(2))
        party.select(party.engine.table.first()); assertTrue(party.engine.selected.isEmpty())
        assertTrue(party.buzz(0)); assertFalse(party.buzz(1))
        party.select(party.engine.table.first())
        now = 5000; party.tick()
        assertNull(party.active); assertTrue(party.engine.selected.isEmpty())
        assertEquals(9000L, party.lockedUntil[0]); assertFalse(party.buzz(0)); assertTrue(party.buzz(1))
        now = 10000; party.tick(); assertTrue(party.buzz(0))
        now = 15000; party.tick(); assertEquals(20000L, party.lockedUntil[0])
    }
    @Test fun correctClaimAwardsExactlyThreeCardsAndOnePoint() {
        var now = 0L
        val party = Party(4, { now }, Random(4))
        val set = EstCard.find(party.engine.table.map(::EstCard))!!
        party.buzz(2); set.forEach { party.select(it.id) }
        assertEquals(1, party.scores[2]); assertEquals(3, party.collected[2].size); assertNull(party.active)
        now = 900; party.tick(); assertEquals(3, party.engine.done.size)
        assertEquals(1, party.scores[2])
    }
    @Test fun playStyleRecordsOnlyAttemptedTraitsAndComplexity() {
        val stats = PlayerStats()
        stats.record(listOf(0,40,80).map(::EstCard), 3, 2.5)
        stats.record(listOf(0,39,79).map(::EstCard), 1, 5.0)
        assertEquals(2, stats.attempts); assertEquals(1, stats.correctSets)
        assertEquals(1, stats.correctByDifference[4]); assertEquals(2.5, stats.secondsByDifference[4], .0001)
        assertEquals(listOf(0,0,0,1), stats.mismatchesByTrait); assertEquals(1, stats.nearMisses)
    }
}
