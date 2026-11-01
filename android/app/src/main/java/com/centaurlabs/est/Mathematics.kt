package com.centaurlabs.est

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

private fun chooseLine(previous: List<Int>, id: Int): List<Int> {
    if (previous.size != 1) return listOf(id)
    if (previous[0] == id) return previous
    return previous + id + EstCard.complete(EstCard(previous[0]), EstCard(id)).id
}

@Composable
fun Mathematics() {
    var trits by rememberSaveable { mutableStateOf(listOf(0,0,0,0)) }
    var pair by rememberSaveable { mutableStateOf(EstCard.randomSet().take(2).map { it.id }) }
    var selection by rememberSaveable { mutableStateOf(emptyList<Int>()) }
    var slice by rememberSaveable { mutableIntStateOf(0) }
    var sliceSelection by rememberSaveable { mutableStateOf(emptyList<Int>()) }
    val card = EstCard(trits[0]*27 + trits[1]*9 + trits[2]*3 + trits[3])
    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(bottom = 28.dp), verticalArrangement = Arrangement.spacedBy(18.dp)) {
        Text("Cards are points. Sets are lines.", fontSize = 22.sp, fontWeight = FontWeight.Bold)
        Text("EST is the affine space AG(4,3): four coordinates, three values each, and 81 points in all.")
        InfoSection("A card is four digits") {
            Text("01 / four coordinates", color = LocalPalette.current[1], fontSize = 12.sp)
            Text("Tap a trait to change it. The card's base-3 ID changes with it.")
            CardFace(card, Modifier.align(Alignment.CenterHorizontally).size(176.dp), selected = true)
            Text("Base-3 ID ${card.id} / 0 to 80", Modifier.align(Alignment.CenterHorizontally), fontSize = 12.sp)
            (0..3).chunked(2).forEach { row ->
                Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    row.forEach { trait ->
                        val value = trits[trait]
                        val name = when (trait) { 0 -> "${value+1}"; 1 -> EstCard.colors[value]; 2 -> EstCard.shapes[value]; else -> if (value == 2 && LocalPinstripes.current) "striped" else EstCard.fills[value] }
                        GameButton("${EstCard.traitNames[trait]}: $name", Modifier.weight(1f), compact = true, tint = if (trait == 1) value else 1) { trits = trits.mapIndexed { i, t -> if (i == trait) (t+1)%3 else t } }
                    }
                }
            }
        }
        InfoSection("Two cards determine the third") {
            Text("02 / the set rule", color = LocalPalette.current[1], fontSize = 12.sp)
            Text("Each trait sums to zero modulo three, leaving one possible third card.")
            val third = EstCard.complete(EstCard(pair[0]), EstCard(pair[1]))
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                CardFace(EstCard(pair[0]), Modifier.weight(1f)); Text("+")
                CardFace(EstCard(pair[1]), Modifier.weight(1f)); Text("=")
                CardFace(third, Modifier.weight(1f), selected = true)
            }
            Audit((pair + third.id).map(::EstCard))
            Text("sum mod 3 = 0 for every trait", fontSize = 12.sp)
            GameButton("Shuffle the pair", Modifier.fillMaxWidth(), compact = true) { pair = EstCard.randomSet().take(2).map { it.id } }
        }
        InfoSection("All 81 cards") {
            Text("03 / the whole space", color = LocalPalette.current[1], fontSize = 12.sp)
            Text("Two trits on each axis create a 9 × 9 map of the deck. Tap two cells to reveal the card they determine.")
            MathGrid((0..80).toList(), 9, 3f, selection) { selection = chooseLine(selection, it) }
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                GameButton("Show a set", Modifier.weight(1f), primary = true, compact = true) { selection = EstCard.randomSet().map { it.id } }
                GameButton("×", Modifier.width(46.dp), compact = true) { selection = emptyList() }
            }
            Text(when (selection.size) { 0 -> "Tap any two cells. The third card is unique."; 1 -> "One selected. Tap a second cell."; else -> "The third card is ${selection[2]}. The line stays inside this map." }, fontSize = 12.sp)
            HorizontalDivider()
            Text("The 4D space, in slices", fontWeight = FontWeight.Bold)
            Text("Hold count and color still. The other two form a 3 × 3 plane. Choose from all nine planes below.", fontSize = 12.sp)
            Text("Choose a slice: count ↓ × color →", fontSize = 12.sp)
            repeat(3) { count ->
                Row(horizontalArrangement = Arrangement.spacedBy(5.dp)) {
                    repeat(3) { color ->
                        val index = count*3 + color
                        GameButton("${count+1} · ${EstCard.colors[color]}", Modifier.weight(1f), compact = true, primary = slice == index, tint = color) { slice = index; sliceSelection = emptyList() }
                    }
                }
            }
            Text("This slice: ${slice/3+1} symbols · ${EstCard.colors[slice%3]}", fontSize = 12.sp)
            Text("Plane ${slice+1} of 9. Each plane contains nine shape × fill combinations.", fontSize = 12.sp)
            Row { Text("Shape ↓", Modifier.weight(1f)); Text("Fill →") }
            MathGrid((slice*9 until slice*9+9).toList(), 3, 10f, sliceSelection) { sliceSelection = chooseLine(sliceSelection, it) }
            Text(if (sliceSelection.size == 3) "Card ${sliceSelection[2]} is forced. Nine slices of nine cards make 81." else "Tap two cards. The straight line shows where the third lands in this plane.", fontSize = 12.sp)
        }
        InfoSection("A 20-card cap") {
            Text("04 / cap set", color = LocalPalette.current[1], fontSize = 12.sp)
            Text("These 20 cards contain no set. Add any 21st card and a set must appear.")
            val cap = listOf(1,3,10,13,18,21,32,34,41,44,49,52,54,57,59,62,64,71,72,79)
            MathGrid(cap, 5, 7f, emptyList(), null)
            Text("20-card cap                         ${EstCard.countSets(cap.map(::EstCard))} sets")
            Text("Pellegrino proved that 20 is the largest cap in AG(4,3).", fontSize = 12.sp)
        }
    }
}

@Composable private fun MathGrid(ids: List<Int>, columns: Int, gap: Float, selection: List<Int>, onTap: ((Int) -> Unit)?) {
    val line = LocalPalette.current[1]
    BoxWithConstraints(Modifier.fillMaxWidth()) {
        val side = (maxWidth - (gap * (columns-1)).dp) / columns
        Column(verticalArrangement = Arrangement.spacedBy(gap.dp)) {
            ids.chunked(columns).forEach { row -> Row(horizontalArrangement = Arrangement.spacedBy(gap.dp)) {
                row.forEach { id -> CardFace(EstCard(id), Modifier.size(side).alpha(if (selection.size == 3 && id !in selection) .35f else 1f), selected = id in selection, onClick = onTap?.let { { it(id) } }) }
            } }
        }
        if (selection.size > 1) Canvas(Modifier.matchParentSize()) {
            val points = selection.map { id -> val i = ids.indexOf(id); Offset((i%columns)*(side.toPx()+gap.dp.toPx()) + side.toPx()/2, (i/columns)*(side.toPx()+gap.dp.toPx()) + side.toPx()/2) }
            // Same row/column coordinates as the iOS grid; the line is a visual aid.
            val path = Path().apply { moveTo(points[0].x,points[0].y); points.drop(1).forEach { lineTo(it.x,it.y) } }
            drawPath(path, line.copy(alpha = .82f), style = Stroke(maxOf(2.dp.toPx(), size.width * .012f)))
        }
    }
}
