package com.centaurlabs.est

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlin.math.roundToInt

@Composable
fun PlayStyle(model: GameModel) {
    @Suppress("UNUSED_VARIABLE") val revision = model.revision
    val stats = model.stats
    var reset by remember { mutableStateOf(false) }
    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()), verticalArrangement = Arrangement.spacedBy(16.dp)) {
        InfoSection("A private practice mirror") { Text("These aggregate stats stay on this device and are never included in anonymous diagnostics.") }
        if (stats.attempts == 0) InfoSection("Play a few solo rounds") { Text("EST will show which kinds of sets feel natural to you and where a little practice could help.") }
        else {
            InfoSection("At a glance") {
                Text("Sets  ${stats.correctSets}     Accuracy  ${(100.0 * stats.correctSets / stats.attempts).roundToInt()}%     Rounds  ${stats.rounds}", fontWeight = FontWeight.Bold)
                Text("Fastest set  ${stats.fastestSet?.let(::shortSeconds) ?: "—"}     Best streak  ${stats.longestStreak}")
                Text("Best 81  ${model.best(Mode.FULL)?.let(::formatTime) ?: "—"}     Best 27  ${model.best(Mode.QUICK)?.let(::formatTime) ?: "—"}")
            }
            InfoSection("Set complexity") {
                Text("A set has 1–4 differing traits. This is a pattern profile, not a score: a four-difference set is not always harder.", fontSize = 13.sp)
                (1..4).forEach { i ->
                    StatBar("$i", stats.correctByDifference[i], stats.correctByDifference.drop(1).maxOrNull() ?: 1, LocalPalette.current[(i-1)%3])
                    if (stats.correctByDifference[i] > 0) Text("Average ${(stats.secondsByDifference[i] / stats.correctByDifference[i]).toInt()} seconds", fontSize = 12.sp)
                }
            }
            InfoSection("Traits to watch") {
                if (stats.attempts == stats.correctSets) Text("No mismatches yet.")
                else {
                    EstCard.traitNames.forEachIndexed { i, name -> Text("$name: ${stats.mismatchesByTrait[i]}") }
                    if (stats.nearMisses > 0) Text("${stats.nearMisses} of your misses were one-trait near misses—use those as your best practice clues.", fontSize = 13.sp)
                }
            }
            InfoSection("Your search conditions") {
                val most = stats.boardSetBuckets.indices.maxByOrNull { stats.boardSetBuckets[it] } ?: 0
                Text("Most of your attempts happen when the board has ${listOf("no set", "1 set", "2 sets", "3+ sets")[most]} available.")
                Text("Boards with many sets offer choice; sparse boards reward the two-card completion habit.", fontSize = 13.sp)
            }
            InfoSection("A useful next habit") {
                val trait = stats.mismatchesByTrait.indices.maxByOrNull { stats.mismatchesByTrait[it] } ?: 0
                Text(when {
                    stats.correctSets < 5 -> "Say the four traits out loud for a few sets. The pattern becomes easier to see when you inspect one trait at a time."
                    stats.mismatchesByTrait[trait] > 0 -> "Your most common check is ${EstCard.traitNames[trait].lowercase()}. Before tapping, ask: are these three values all the same or all different?"
                    else -> "Choose any two cards, mentally calculate the only card that can complete them, then look for that card on the board."
                })
            }
        }
        GameButton("Reset learning stats", Modifier.fillMaxWidth(), tint = 0, compact = true) { reset = true }
        Spacer(Modifier.height(16.dp))
    }
    if (reset) AlertDialog(onDismissRequest = { reset = false }, title = { Text("Reset learning stats?") }, text = { Text("This only removes the private stats stored on this device.") }, confirmButton = { TextButton(onClick = { model.resetStats(false); reset = false }) { Text("Reset stats") } }, dismissButton = { TextButton(onClick = { reset = false }) { Text("Cancel") } })
}

@Composable
fun InfoSection(title: String, content: @Composable ColumnScope.() -> Unit) {
    Column(Modifier.fillMaxWidth().background(MaterialTheme.colorScheme.surface.copy(alpha = .8f), RoundedCornerShape(18.dp)).padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Text(title, fontSize = 18.sp, fontWeight = FontWeight.Bold)
        content()
    }
}

@Composable private fun StatBar(label: String, value: Int, maximum: Int, color: Color) {
    Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
        Text(label)
        Box(Modifier.weight(1f).height(12.dp).background(color.copy(alpha = .1f), RoundedCornerShape(50))) {
            Box(Modifier.fillMaxWidth(value.toFloat() / maximum.coerceAtLeast(1)).fillMaxHeight().background(color, RoundedCornerShape(50)))
        }
        Text("$value")
    }
}
