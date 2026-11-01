package com.centaurlabs.est

import kotlin.math.pow
import kotlin.math.sqrt

/** Direct translation of CardView.symbols and SymbolView from the iOS source.
 * Coordinates are logical points (Android dp), never device pixels. */
object CardGeometry {
    data class Point(val x: Float, val y: Float)
    data class Symbols(val side: Float, val gap: Float, val centers: List<Point>)
    fun symbols(cardSide: Float, count: Int): Symbols {
        val scale = (cardSide.coerceAtLeast(1f) / 100.0).pow(2.0 / 3.0).toFloat()
        val s = 23f * scale
        val gap = 10f * scale
        val center = cardSide / 2
        val dx = (s + gap) / 2
        val r = (s + gap) / sqrt(3f)
        val points = when (count) {
            1 -> listOf(Point(center, center))
            2 -> listOf(Point(center - dx, center), Point(center + dx, center))
            else -> listOf(Point(center, center - r * 0.75f), Point(center - dx, center + r * 0.75f), Point(center + dx, center + r * 0.75f))
        }
        return Symbols(s, gap, points)
    }
    fun stroke(symbolSide: Float) = maxOf(1.5f, symbolSide * 0.09f)
    fun opticalScale(symbol: Int) = when (symbol) { 1 -> .95f; 2 -> 1.06f; else -> 1f }
    data class Layout(val columns: Int, val rows: Int, val side: Float)
    fun boardLayout(width: Float, height: Float, cards: Int, maximum: Float): Layout {
        val across = ((cards + 2) / 3).coerceAtLeast(1)
        fun fit(columns: Int, rows: Int) = Layout(columns, rows, maxOf(1f, minOf((width - (columns-1)*10) / columns, (height - (rows-1)*10) / rows, maximum)))
        val upright = fit(3, across)
        val sideways = fit(across, 3)
        return if (sideways.side > upright.side) sideways else upright
    }
    fun boardSide(width: Float, height: Float, cards: Int, maximum: Float) = boardLayout(width, height, cards, maximum).side
}
