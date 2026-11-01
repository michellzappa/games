package com.centaurlabs.est

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.*
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

@Composable
fun PartyScreen(model: GameModel) {
    @Suppress("UNUSED_VARIABLE") val revision = model.revision
    val party = model.party ?: return
    var rotation by rememberSaveable { mutableFloatStateOf(0f) }
    var exit by remember { mutableStateOf(false) }
    BackHandler { exit = true }
    Column(Modifier.fillMaxSize().padding(vertical = 16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Row(Modifier.fillMaxWidth()) {
            GameButton("×", Modifier.width(46.dp), compact = true) { exit = true }
            Spacer(Modifier.weight(1f))
            GameButton("↻", Modifier.width(46.dp), compact = true) { rotation += 90 }
        }
        BoxWithConstraints(Modifier.weight(1f).fillMaxWidth()) {
            val tableWidth = maxWidth
            val tableHeight = maxHeight
            val board: @Composable (Modifier) -> Unit = { modifier ->
                val active = party.active
                val color = if (active == null) Color.Transparent else playerColor(active)
                CompositionLocalProvider(LocalRotation provides rotation) {
                    Board(party.engine.table, party.engine.selected, party.engine.pending, emptyList(), active != null && !party.engine.finished,
                        modifier.border(if (active == null) 0.dp else 3.dp, color.copy(alpha = .7f), RoundedCornerShape(16.dp)).padding(4.dp), mismatchIds = party.engine.mismatchIds, mismatchToken = party.engine.mismatchToken, animateDeals = true) { model.partySelect(it) }
                }
            }
            if (party.playerCount == 2) Column(Modifier.fillMaxSize(), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                PlayerSeat(model, 1, Modifier.fillMaxWidth().rotate(180f))
                board(Modifier.weight(1f).fillMaxWidth())
                PlayerSeat(model, 0, Modifier.fillMaxWidth())
            } else {
                // Same 58-point seats and 8-point edge gaps used by PartyGameView.
                val compact = minOf(tableWidth, tableHeight) < 800.dp
                val buttonWidth = if (compact) (tableWidth * .28f).coerceIn(180.dp, 210.dp) else (tableWidth * .24f).coerceIn(220.dp, 260.dp)
                val seatWidth = buttonWidth + 132.dp
                val cardSide = CardGeometry.boardSide(tableWidth.value - 132f, tableHeight.value - 132f, party.engine.table.size, Float.POSITIVE_INFINITY) * .8f
                val rows = (party.engine.table.size + 2) / 3
                Box(Modifier.fillMaxSize()) {
                    PlayerSeat(model, 2, Modifier.width(seatWidth).align(Alignment.TopCenter).rotate(180f))
                    PlayerSeat(model, 0, Modifier.width(seatWidth).align(Alignment.BottomCenter))
                    PlayerSeat(model, 1, Modifier.width(seatWidth).offset(x = (58.dp-seatWidth)/2, y = (tableHeight-58.dp)/2).rotate(90f))
                    PlayerSeat(model, 3, Modifier.width(seatWidth).offset(x = tableWidth-(58.dp+seatWidth)/2, y = (tableHeight-58.dp)/2).rotate(-90f))
                    board(Modifier.size((cardSide * 3 + 20).dp, (cardSide * rows + (rows-1)*10).dp).align(Alignment.Center))
                }
            }
        }
    }
    if (exit) AlertDialog(onDismissRequest = { exit = false }, title = { Text("End this game?") }, text = { Text("Your scores will be lost.") }, confirmButton = { TextButton(onClick = { model.leaveParty() }) { Text("End game") } }, dismissButton = { TextButton(onClick = { exit = false }) { Text("Keep playing") } })
    if (party.engine.finished) Confetti()
    if (party.engine.finished) AlertDialog(onDismissRequest = {}, title = { Text(if (party.scores.count { it == party.scores.max() } > 1) "Tie" else "P${party.scores.indexOf(party.scores.max())+1} wins") }, text = {
        Column { party.scores.forEachIndexed { i, score -> Text("P${i+1}: $score sets · ${party.collected[i].size} cards") } }
    }, confirmButton = { TextButton(onClick = { model.startParty(party.playerCount) }) { Text("Play again") } }, dismissButton = { TextButton(onClick = { model.leaveParty() }) { Text("Menu") } })
}

@Composable private fun playerColor(id: Int): Color = if (id < 3) LocalPalette.current[id] else Color(.61f,.34f,.78f)

@Composable private fun PlayerSeat(model: GameModel, id: Int, modifier: Modifier = Modifier) {
    val party = model.party ?: return
    val color = playerColor(id)
    val active = party.active == id
    val enabled = party.canBuzz(id)
    Row(modifier.height(58.dp), horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
        Text("P${id+1}", color = color, fontWeight = FontWeight.Bold, modifier = Modifier.width(34.dp))
        Box(Modifier.weight(1f).fillMaxHeight().background(color.copy(alpha = if (active) 1f else if (!enabled) .25f else .8f), RoundedCornerShape(14.dp))
            .clickable(enabled = enabled, role = Role.Button) { model.buzz(id) }.semantics { contentDescription = "P${id+1}'s SET" }, contentAlignment = Alignment.Center) {
            Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(2.dp)) {
                Text("SET", fontWeight = FontWeight.Bold, color = Color.White)
                if (active) Box(Modifier.fillMaxWidth(.8f).height(4.dp)) { Box(Modifier.fillMaxWidth((party.remaining(id)/5000f).coerceIn(0f,1f)).fillMaxHeight().background(Color.White)) }
                else if (party.remaining(id) > 0) Text("⌛", color = Color.White, fontSize = 12.sp)
            }
        }
        Column(Modifier.size(58.dp).border(1.dp, MaterialTheme.colorScheme.onSurface.copy(alpha = .22f), RoundedCornerShape(7.dp)), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.Center) {
            Text("${party.collected[id].size}", fontSize = 12.sp, fontWeight = FontWeight.Bold)
            Text("CARDS", fontSize = 7.sp)
        }
    }
}
