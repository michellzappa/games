package com.centaurlabs.est

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.snap
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.tween
import kotlinx.coroutines.delay
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.geometry.RoundRect
import androidx.compose.ui.graphics.*
import androidx.compose.ui.graphics.drawscope.*
import androidx.compose.ui.semantics.*
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.zIndex
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.layout.positionInRoot
import androidx.compose.ui.platform.LocalDensity
import kotlin.math.sqrt
import kotlin.math.sin
import kotlin.math.PI

// Appearance.Theme.color / highlight, copied as sRGB components without rounding to hex.
val Classic = listOf(Color(.87f,.32f,.28f), Color(.24f,.43f,.92f), Color(.94f,.66f,.20f))
val Orchard = listOf(Color(.55f,.33f,.83f), Color(.13f,.62f,.39f), Color(.93f,.47f,.15f))
val ClassicHighlights = listOf(Color(.96f,.47f,.41f), Color(.44f,.60f,.98f), Color(.99f,.79f,.38f))
val OrchardHighlights = listOf(Color(.68f,.48f,.93f), Color(.30f,.76f,.53f), Color(.98f,.62f,.31f))
val LocalPalette = staticCompositionLocalOf { Classic }
val LocalHighlights = staticCompositionLocalOf { ClassicHighlights }
val LocalPinstripes = staticCompositionLocalOf { true }
val LocalAssist = staticCompositionLocalOf { false }
val LocalReducedMotion = staticCompositionLocalOf { false }
val LocalHighContrast = staticCompositionLocalOf { false }
val LocalRotation = staticCompositionLocalOf { 0f }

@Composable
fun CardFace(card: EstCard, modifier: Modifier = Modifier, selected: Boolean = false, matched: Boolean = false, hint: Boolean = false, onClick: (() -> Unit)? = null) {
    val color = LocalPalette.current[card.tint]
    val highlight = LocalHighlights.current[card.tint]
    val stripe = LocalPinstripes.current
    val reduced = LocalReducedMotion.current
    val rotation by animateFloatAsState(LocalRotation.current, if (reduced) snap() else spring(), label = "Card rotation")
    val scale by animateFloatAsState(if (matched) 1.10f else if (selected) 1.06f else 1f, if (reduced) snap() else spring(dampingRatio = .55f), label = "Card selection")
    val border = if (selected) color else MaterialTheme.colorScheme.onSurface.copy(alpha = .12f)
    BoxWithConstraints(modifier.aspectRatio(1f).zIndex(if (matched || selected) 1f else 0f)) {
        val side = maxWidth
        val shape = RoundedCornerShape(side * .12f)
        Box(Modifier.fillMaxSize().graphicsLayer { scaleX = scale; scaleY = scale }
            .shadow(if (matched) 14.dp else side * if (selected) .06f else .03f, shape, ambientColor = if (matched) color.copy(alpha = .7f) else Color.Black.copy(alpha = if (selected) .35f else .15f), spotColor = if (matched) color else Color.Black.copy(alpha = .15f))
            .background(MaterialTheme.colorScheme.surface, shape)
            .border(if (selected) 3.dp else if (LocalHighContrast.current) 2.dp else 1.dp, border, shape)
            .then(if (onClick == null) Modifier else Modifier.clickable(role = Role.Button, onClick = onClick))
            .semantics(mergeDescendants = true) {
                contentDescription = card.description.replace("shaded", if (stripe) "striped" else "shaded")
                this.selected = selected
                stateDescription = when { matched -> "Matched"; hint -> "Hint"; selected -> "Selected"; else -> "Not selected" }
            }) {
            Canvas(Modifier.fillMaxSize()) {
                val geometry = CardGeometry.symbols(size.width / density, card.count)
                rotate(rotation) {
                    geometry.centers.forEach { center ->
                        val s = geometry.side * density
                        drawEstSymbol(card.symbol, card.fill, Offset(center.x * density, center.y * density), s, color, highlight, stripe)
                    }
                }
                if (hint) drawRoundRect(Color(0xFFFF9500), topLeft = Offset(1.5.dp.toPx(), 1.5.dp.toPx()), size = androidx.compose.ui.geometry.Size(size.width - 3.dp.toPx(), size.height - 3.dp.toPx()), cornerRadius = CornerRadius(12.dp.toPx()), style = Stroke(3.dp.toPx(), pathEffect = PathEffect.dashPathEffect(floatArrayOf(7.dp.toPx(), 5.dp.toPx()))))
            }
            if (LocalAssist.current) Text(listOf("R", "B", "Y")[card.tint], fontSize = maxOf(8f, side.value * .10f).sp, fontWeight = FontWeight.Bold,
                modifier = Modifier.align(Alignment.TopEnd).padding(side * .08f).background(MaterialTheme.colorScheme.background.copy(alpha = .88f), RoundedCornerShape(50)).border(1.dp, MaterialTheme.colorScheme.onSurface.copy(alpha = .25f), RoundedCornerShape(50)).padding(horizontal = 4.dp, vertical = 2.dp).clearAndSetSemantics {})
        }
    }
}

private fun DrawScope.drawEstSymbol(symbol: Int, fill: Int, center: Offset, side: Float, color: Color, highlight: Color, pinstriped: Boolean) {
    val line = CardGeometry.stroke(side / density) * density
    val optical = CardGeometry.opticalScale(symbol)
    val width = side - line // Swift SymbolView.padding(lineWidth / 2).
    val left = center.x - width / 2
    val top = center.y - width / 2
    val path = Path().apply {
        when (symbol) {
            0 -> addOval(Rect(left, top, left + width, top + width))
            1 -> addRoundRect(RoundRect(Rect(left, top, left + width, top + width), CornerRadius(width * .1f)))
            else -> {
                val height = width * sqrt(3f) / 2
                moveTo(center.x, center.y - height / 2)
                lineTo(left + width, center.y + height / 2)
                lineTo(left, center.y + height / 2); close()
            }
        }
    }
    scale(optical, optical, center) {
        when (fill) {
            0 -> drawPath(path, Brush.linearGradient(listOf(highlight, color), Offset(left, top), Offset(left + width, top + width)))
            1 -> drawPath(path, color, style = Stroke(line))
            else -> {
                if (pinstriped) clipPath(path) {
                    val step = maxOf(4.dp.toPx(), width / 5.5f)
                    var d = -width + step / 2
                    while (d < width) {
                        drawLine(color, Offset(left + d, top + width), Offset(left + d + width, top), step * .42f, StrokeCap.Round)
                        d += step
                    }
                } else drawPath(path, color.copy(alpha = .24f))
                drawPath(path, color, style = Stroke(line))
            }
        }
    }
}

@Composable
fun Board(ids: List<Int>, selected: List<Int>, pending: List<Int>, hints: List<Int>, interactive: Boolean, modifier: Modifier = Modifier, fixedSide: Float? = null, mismatchIds: List<Int> = emptyList(), mismatchToken: Int = 0, animateDeals: Boolean = false, collectionTarget: Offset? = null, onCard: (Int) -> Unit) {
    var boardOrigin by remember { mutableStateOf(Offset.Zero) }
    var departures by remember { mutableStateOf(emptyList<Flight>()) }
    var flights by remember { mutableStateOf(emptyList<Flight>()) }
    BoxWithConstraints(modifier.fillMaxWidth().onGloballyPositioned { boardOrigin = it.positionInRoot() }, contentAlignment = Alignment.Center) {
        val density = LocalDensity.current.density
        val maximum = fixedSide ?: if (maxWidth >= 600.dp) 240f else 150f
        val availableHeight = if (constraints.hasBoundedHeight) maxHeight.value else Float.POSITIVE_INFINITY
        val layout = CardGeometry.boardLayout(maxWidth.value, availableHeight, ids.size, maximum)
        val side = layout.side.dp
        val columns = layout.columns
        val rows = layout.rows
        val gridX = (maxWidth.value - (side.value*columns+(columns-1)*10))/2
        val gridY = if (constraints.hasBoundedHeight) (maxHeight.value - (side.value*rows+(rows-1)*10))/2 else 0f
        LaunchedEffect(pending) {
            if (pending.isNotEmpty()) departures = pending.mapNotNull { id ->
                val i = ids.indexOf(id)
                if (i < 0) null else Flight(id, Offset((gridX+i%columns*(side.value+10)+side.value/2)*density, (gridY+i/columns*(side.value+10)+side.value/2)*density), side.value)
            }
        }
        LaunchedEffect(ids) {
            val leaving = departures.filter { it.id !in ids }
            if (leaving.isNotEmpty() && collectionTarget != null) {
                flights = flights + leaving
                departures = emptyList()
                delay(1100)
                flights = flights.filterNot { it in leaving }
            }
        }
        Column(verticalArrangement = Arrangement.spacedBy(10.dp), horizontalAlignment = Alignment.CenterHorizontally) {
            ids.chunked(columns).forEach { row ->
                Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    row.forEach { id -> key(id) {
                        val reduced = LocalReducedMotion.current
                        val arrival = remember { Animatable(if (animateDeals && !reduced) 0f else 1f) }
                        val shake = remember { Animatable(0f) }
                        LaunchedEffect(id) { if (animateDeals && !reduced) { delay(ids.indexOf(id)*60L); arrival.animateTo(1f, tween(620)) } }
                        LaunchedEffect(mismatchToken) { if (id in mismatchIds && !reduced) { shake.snapTo(0f); shake.animateTo(1f, tween(400)) } }
                        CardFace(EstCard(id), Modifier.size(side).graphicsLayer {
                            alpha = arrival.value
                            scaleX = .88f + .12f*arrival.value; scaleY = scaleX
                            rotationZ = ((id*29)%13-6) * (1-arrival.value)
                            translationX = (((id*17)%9-4)*(1-arrival.value) + 7f*sin(shake.value*PI.toFloat()*6))*density
                            translationY = ((id*31)%11-5)*(1-arrival.value)*density
                        }, id in selected, id in pending, id in hints,
                            if (interactive && pending.isEmpty()) ({ onCard(id) }) else null)
                    } }
                    repeat(columns - row.size) { Spacer(Modifier.size(side)) }
                }
            }
        }
        collectionTarget?.let { target ->
            flights.forEachIndexed { i, flight -> key(flight.id) {
                FlightCard(flight, target - boardOrigin, i * 60L, Modifier.align(Alignment.TopStart))
            } }
        }
    }
}

private data class Flight(val id: Int, val from: Offset, val side: Float)
@Composable private fun FlightCard(flight: Flight, target: Offset, delayMs: Long, modifier: Modifier) {
    val progress = remember { Animatable(0f) }
    val density = LocalDensity.current.density
    LaunchedEffect(flight.id) { delay(delayMs); progress.animateTo(1f, tween(450)) }
    CardFace(EstCard(flight.id), modifier.size(flight.side.dp).graphicsLayer {
        val p = progress.value
        translationX = flight.from.x + (target.x-flight.from.x)*p - flight.side*density/2
        translationY = flight.from.y + (target.y-flight.from.y)*p - flight.side*density/2
        scaleX = 1+(52f/flight.side-1)*p; scaleY = scaleX; alpha = 1-.4f*p
    }.zIndex(2f))
}

@Composable
fun Piles(game: Game, onPlayedCenter: (Offset) -> Unit = {}) {
    val palette = LocalPalette.current
    val foreground = MaterialTheme.colorScheme.onSurface
    Row(Modifier.fillMaxWidth().padding(horizontal = 6.dp), horizontalArrangement = Arrangement.spacedBy(14.dp)) {
        Pile("DECK", game.deck.size, null)
        PileProgress(game, Modifier.weight(1f).padding(top = 25.dp))
        Pile("PLAYED", game.done.size, game.done.lastOrNull()?.let(::EstCard), onPlayedCenter)
    }
}

@Composable
fun PileProgress(game: Game, modifier: Modifier = Modifier) {
    val palette = LocalPalette.current
    val foreground = MaterialTheme.colorScheme.onSurface
    Column(modifier, horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(6.dp)) {
        Canvas(Modifier.fillMaxWidth().height(10.dp)) {
            drawRoundRect(foreground.copy(alpha = .08f), cornerRadius = CornerRadius(size.height / 2))
            drawRoundRect(foreground.copy(alpha = .15f), size = androidx.compose.ui.geometry.Size(size.width * (game.mode.deck().size - game.deck.size) / game.mode.deck().size, size.height), cornerRadius = CornerRadius(size.height / 2))
            if (game.done.isNotEmpty()) drawRoundRect(Brush.horizontalGradient(palette), size = androidx.compose.ui.geometry.Size(maxOf(10.dp.toPx(), size.width * game.done.size / game.mode.deck().size), size.height), cornerRadius = CornerRadius(size.height / 2))
        }
        Text("${game.done.size / 3} of ${game.mode.deck().size / 3}", fontSize = 17.sp, fontWeight = FontWeight.SemiBold)
        Text("${EstCard.countSets(game.table.map(::EstCard))} sets visible", fontSize = 11.sp, color = foreground.copy(alpha = .6f))
    }
}

@Composable
fun Pile(label: String, count: Int, top: EstCard?, onCenter: (Offset) -> Unit = {}) {
    val surface = MaterialTheme.colorScheme.surface
    val foreground = MaterialTheme.colorScheme.onSurface
    val palette = LocalPalette.current
    val highlights = LocalHighlights.current
    Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(4.dp)) {
        Box(Modifier.size(60.dp).onGloballyPositioned { onCenter(it.positionInRoot() + Offset(it.size.width/2f,it.size.height/2f)) }, contentAlignment = Alignment.Center) {
            if (count == 0) Canvas(Modifier.size(52.dp)) {
                drawRoundRect(foreground.copy(alpha = .22f), cornerRadius = CornerRadius(size.width * .12f), style = Stroke(1.5.dp.toPx(), pathEffect = PathEffect.dashPathEffect(floatArrayOf(4.dp.toPx(), 3.dp.toPx()))))
            }
            repeat(minOf(count, 5)) { layer ->
                val modifier = Modifier.size(52.dp).offset((-1.5f * layer).dp, (-1.5f * layer).dp)
                if (layer == minOf(count, 5) - 1 && top != null) CardFace(top, modifier)
                else Canvas(modifier) {
                    drawRoundRect(surface, cornerRadius = CornerRadius(size.width * .12f))
                    if (layer == minOf(count, 5) - 1) {
                        drawRoundRect(Brush.linearGradient(listOf(foreground.copy(alpha = .14f), foreground.copy(alpha = .03f))), cornerRadius = CornerRadius(size.width * .12f))
                        val symbol = size.width * (.62f - .12f) / 3
                        repeat(3) { i -> drawEstSymbol(i, 1, Offset(size.width / 2 + (i - 1) * (symbol + size.width * .06f), size.height / 2), symbol, palette[i], highlights[i], false) }
                    }
                    drawRoundRect(foreground.copy(alpha = .12f), cornerRadius = CornerRadius(size.width * .12f), style = Stroke(1.dp.toPx()))
                }
            }
        }
        Text("$count", fontWeight = FontWeight.SemiBold, fontSize = 17.sp)
        Text(label, fontSize = 11.sp, color = foreground.copy(alpha = .6f))
    }
}
