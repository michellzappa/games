package com.centaurlabs.est

import org.junit.Assert.*
import org.junit.Test
import kotlin.random.Random
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json

class GameTest {
    @Test fun allCardIdsAndAll1080Sets() {
        var sets = 0
        for (a in 0..80) {
            val card = EstCard(a)
            assertEquals(a, (card.count - 1) * 27 + card.tint * 9 + card.symbol * 3 + card.fill)
            for (b in a + 1..80) {
                val third = EstCard.complete(card, EstCard(b))
                assertTrue(EstCard.valid(listOf(card, EstCard(b), third)))
                for (c in b + 1..80) {
                    val trio = listOf(card, EstCard(b), EstCard(c))
                    val expected = (0..3).all { i -> trio.map { it.traits[i] }.distinct().size != 2 }
                    assertEquals(expected, EstCard.valid(trio))
                    if (expected) sets++
                }
            }
        }
        assertEquals(1080, sets)
        assertFalse(EstCard.valid(List(3) { EstCard(0) }))
    }
    @Test fun thousandRoundsConserveCardsAndFinish() {
        for (mode in Mode.entries) repeat(500) { seed ->
            var time = 0L
            val game = Game({ time }, mode, Random(seed))
            var matches = 0
            while (!game.finished) {
                val all = game.deck + game.table + game.done
                assertEquals(mode.deck().sorted(), all.sorted())
                val trio = EstCard.find(game.table.map(::EstCard))!!
                time += 1000
                val lastTap = time
                trio.forEach { game.select(it.id) }
                assertEquals(3, game.pending.size)
                game.select(game.table.first())
                assertTrue(game.selected.isEmpty())
                time += 899; game.tick(); assertEquals(3, game.pending.size)
                time += 1; game.tick()
                if (game.finished) assertEquals(lastTap, game.elapsed)
                assertTrue(++matches <= mode.deck().size / 3)
            }
            assertNull(EstCard.find(game.table.map(::EstCard)))
            assertEquals(mode.deck().sorted(), (game.done + game.table).sorted())
            assertTrue(game.eligible)
        }
    }
    @Test fun pauseDoesNotChargeTimeAndHintsInvalidateRanking() {
        var now = 0L
        val game = Game({ now }, Mode.FULL, Random(1))
        now = 1234; game.pause(); now = 9000
        assertEquals(1234, game.elapsed)
        val original = game.table
        game.select(original.first()); assertTrue(game.selected.isEmpty())
        game.resume(); now += 1000
        assertEquals(2234, game.elapsed)
        assertTrue(game.wasPaused)
        game.hint(); assertTrue(game.hintUsed); assertEquals(1, game.hinted.size)
        assertFalse(game.eligible)
    }
    @Test fun snapshotRoundTripSettlesPendingMatchOnce() {
        var clock = 100L
        val game = Game({ clock }, Mode.QUICK, Random(7))
        val trio = EstCard.find(game.table.map(::EstCard))!!
        clock = 1000
        trio.forEach { game.select(it.id) }
        val snapshot = Json.decodeFromString<SavedGame>(Json.encodeToString(game.save(10000)))
        val restored = Game.restore(snapshot, 11000) { clock }!!
        assertEquals(3, restored.done.size)
        assertTrue(restored.pending.isEmpty())
        assertTrue(restored.wasPaused)
        assertTrue(restored.paused)
        restored.tick(); assertEquals(3, restored.done.size)
        assertEquals(game.elapsed, restored.elapsed)
    }
    @Test fun rejectExpiredFutureAndCorruptSaves() {
        val game = Game({ 0 }, Mode.FULL, Random(2))
        val save = game.save(100)
        assertNull(Game.restore(save, 100 + 3 * 86_400_000L + 1) { 0 })
        assertNull(Game.restore(save, 99) { 0 })
        assertNull(Game.restore(save.copy(deck = save.deck + save.deck.first()), 100) { 0 })
        assertNull(Game.restore(save.copy(table = save.table.map { 81 }), 100) { 0 })
        assertNull(Game.restore(save.copy(elapsedMs = -1), 100) { 0 })
        assertNull(Game.restore(save.copy(pending = listOf(0, 0, 0)), 100) { 0 })
        assertNull(Game.restore(save.copy(schema = 100), 100) { 0 })
        val stuckTable = listOf(0, 1, 3)
        assertNull(Game.restore(save.copy(table = stuckTable, deck = Mode.FULL.deck() - stuckTable.toSet()), 100) { 0 })
    }
    @Test fun finalMatchSurvivesPauseAndRestoreWithoutAnimationTime() {
        var clock = 0L
        val game = Game({ clock }, Mode.QUICK, Random(8))
        while (true) {
            val trio = EstCard.find(game.table.map(::EstCard))!!
            clock += 1000
            trio.forEach { game.select(it.id) }
            val saved = game.save(1000)
            val restored = Game.restore(saved, 1001) { clock }!!
            if (restored.finished) {
                assertEquals(game.elapsed, restored.elapsed)
                clock += 500; game.pause()
                assertTrue(game.finished)
                assertEquals(restored.elapsed, game.elapsed)
                break
            }
            clock += 900; game.tick()
        }
    }
    @Test fun baselineReplacementPreservesUnselectedSlots() {
        var now = 0L
        val game = Game({ now }, Mode.FULL, Random(0))
        val before = game.table
        val trio = EstCard.find(before.map(::EstCard))!!.map { it.id }
        trio.forEach { game.select(it) }
        now = 900; game.tick()
        if (before.size == Mode.FULL.baseline) before.forEachIndexed { index, id ->
            if (id !in trio) assertEquals(id, game.table[index])
        }
    }
}
