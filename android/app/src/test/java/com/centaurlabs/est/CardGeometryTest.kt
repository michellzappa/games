package com.centaurlabs.est

import org.junit.Assert.*
import org.junit.Test
import kotlin.math.hypot

class CardGeometryTest {
    @Test fun referenceSizeMatchesSwiftCardView() {
        val g = CardGeometry.symbols(100f, 3)
        assertEquals(23f, g.side, .00001f)
        assertEquals(10f, g.gap, .00001f)
        assertEquals(50f, g.centers[0].x, .00001f)
        assertEquals(35.71058f, g.centers[0].y, .0001f)
        assertEquals(33.5f, g.centers[1].x, .00001f)
        assertEquals(64.28942f, g.centers[1].y, .0001f)
        assertEquals(2.07f, CardGeometry.stroke(g.side), .0001f)
    }
    @Test fun triangleCentersStayEquilateralAndVisuallyCenteredAtEverySize() {
        for (side in listOf(34f, 52f, 84f, 92f, 96f, 100f, 150f, 176f, 240f)) {
            val g = CardGeometry.symbols(side, 3)
            val distances = (0..2).map { i -> val a = g.centers[i]; val b = g.centers[(i+1)%3]; hypot(a.x-b.x,a.y-b.y) }
            distances.forEach { assertEquals(g.side + g.gap, it, .0001f) }
            assertEquals(side, g.centers.minOf { it.y } + g.centers.maxOf { it.y }, .0001f)
            assertEquals(side, g.centers.minOf { it.x } + g.centers.maxOf { it.x }, .0001f)
        }
    }
    @Test fun boardFitsHeightAndNeverSwitchesToFourColumns() {
        assertEquals(100f, CardGeometry.boardSide(320f, 430f, 12, 150f), .0001f)
        assertEquals(92.5f, CardGeometry.boardSide(400f, 400f, 12, 150f), .0001f)
        assertEquals(240f, CardGeometry.boardSide(1200f, 1200f, 12, 240f), .0001f)
    }
    @Test fun teachingBoardsHaveExactlyOneSetAndNearMissesOneFailure() {
        repeat(300) {
            assertEquals(1, EstCard.countSets(EstCard.practiceBoard()))
            assertEquals(1, EstCard.audit(EstCard.nearMiss()).count { !it })
        }
    }
}
