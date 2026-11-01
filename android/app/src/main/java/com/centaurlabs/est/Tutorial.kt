package com.centaurlabs.est

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

@Composable
fun Tutorial(model: GameModel) {
    var step by rememberSaveable { mutableIntStateOf(0) }
    var valid by rememberSaveable { mutableStateOf(EstCard.randomSet().map { it.id }) }
    var invalid by rememberSaveable { mutableStateOf(EstCard.nearMiss().map { it.id }) }
    val practice = rememberSaveable { EstCard.practiceBoard().map { it.id } }
    var selected by rememberSaveable { mutableStateOf(emptyList<Int>()) }
    var verdict by rememberSaveable { mutableStateOf(emptyList<Int>()) }
    var solved by rememberSaveable { mutableStateOf(false) }
    var hint by rememberSaveable { mutableStateOf(emptyList<Int>()) }
    Column(Modifier.fillMaxSize(), verticalArrangement = Arrangement.spacedBy(16.dp)) {
        Row(Modifier.fillMaxWidth().padding(horizontal = 8.dp), verticalAlignment = Alignment.CenterVertically) {
            repeat(6) { i -> Box(Modifier.padding(end = 6.dp).size(if (i == step) 18.dp else 6.dp, 6.dp).background(MaterialTheme.colorScheme.onSurface.copy(alpha = if (i == step) 1f else .18f), RoundedCornerShape(50))) }
            Spacer(Modifier.weight(1f)); TextButton(onClick = { model.learned() }) { Text("Skip") }
        }
        Column(Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(horizontal = 8.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(18.dp)) {
            when (step) {
                0 -> {
                    VaryingTitle(56)
                    TutorialHeading("Three cards. One rule.")
                    ExampleCards(valid)
                    Text("THESE THREE MAKE A SET", fontSize = 12.sp)
                    Text("Every card carries four traits. Three cards form a set when each trait is the same on all three cards or different on all three. There is no middle case.")
                    Text("That is the rule. The next few steps unpack it.")
                }
                1 -> {
                    TutorialHeading("Four traits")
                    Text("Each card has a count, a color, a shape, and a fill. Each trait has exactly three values.")
                    listOf(Triple("Count", "one, two, or three symbols", listOf(0,27,54)), Triple("Color", "red, blue, yellow", listOf(27,36,45)), Triple("Shape", "circle, square, triangle", listOf(36,39,42)), Triple("Fill", "solid, ${if (model.pinstripes) "striped" else "shaded"}, outline", listOf(45,47,46))).forEach { (title, detail, ids) ->
                        Text(title, fontWeight = FontWeight.Bold); Text(detail, fontSize = 13.sp); ExampleCards(ids)
                    }
                    Text("Each row above is already a valid set: one trait runs through all three values, and the other three traits hold still.")
                }
                2 -> {
                    TutorialHeading("A set passes all four checks")
                    Text("Check the traits one at a time. Each one must be all the same or all different.")
                    ExampleCards(valid); Audit(valid.map(::EstCard))
                    Text("All four pass, so these cards make a set. In a game, tap them to collect them.")
                    GameButton("Another example", compact = true) { valid = EstCard.randomSet().map { it.id } }
                }
                3 -> {
                    TutorialHeading("One failed trait is enough")
                    Text("These cards look close, but one trait fails. Check them the same way as before.")
                    ExampleCards(invalid); Audit(invalid.map(::EstCard))
                    Text("A trait can only fail one way: two cards agree and the third does not. Two and one is never a set.")
                    Text("The game shows this message whenever a pick fails, so you can see why.")
                    GameButton("Another example", compact = true) { invalid = EstCard.nearMiss().map { it.id } }
                }
                4 -> {
                    TutorialHeading("Your turn")
                    Text("Exactly one set hides in these six cards. Tap three cards to pick them.")
                    Board(practice, selected, emptyList(), hint, !solved, fixedSide = 92f) { id ->
                        selected = if (id in selected) selected - id else selected + id
                        if (selected.size == 3) { verdict = selected; solved = EstCard.valid(selected.map(::EstCard)); if (!solved) selected = emptyList() }
                    }
                    if (solved) Text("THAT IS A SET", fontWeight = FontWeight.Bold)
                    if (verdict.size == 3) Audit(verdict.map(::EstCard))
                    else Text("Pick a pair first. Any two cards have exactly one card that completes them, so you are always hunting for one specific card.")
                }
                else -> {
                    TutorialHeading("At the table")
                    Text("These are the board rules.")
                    listOf("Start with 12 cards" to "Tap three that make a set. Replacements take their place.", "No set on the table?" to "The game deals three more cards until a set appears.", "Solo 81" to "Clear the deck against the clock. Hints keep the run off the leaderboard.", "Quick 27" to "Play the 27 solid cards. The fill never changes, so you check three traits.").forEach { (title, detail) ->
                        Column(Modifier.fillMaxWidth()) { Text(title, fontWeight = FontWeight.Bold); Text(detail) }
                    }
                    Text("At the end, the remaining cards are simply the ones nobody claimed.")
                }
            }
        }
        if (step == 4 && !solved) Text("Find the set to continue, or use a hint.", fontSize = 12.sp, textAlign = TextAlign.Center)
        Row(Modifier.fillMaxWidth().padding(bottom = 24.dp), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            if (step > 0) GameButton("Back", Modifier.weight(1f), compact = true) { step-- }
            if (step == 4 && !solved) GameButton("Hint", Modifier.weight(1f), tint = 2, compact = true) { hint = EstCard.find(practice.map(::EstCard))!!.map { it.id } }
            if (step != 4 || solved) GameButton(if (step == 5) "Play" else "Next", Modifier.weight(1f), primary = true, compact = true) { if (step == 5) model.learned() else step++ }
        }
    }
}

@Composable private fun ExampleCards(ids: List<Int>) { Board(ids, emptyList(), emptyList(), emptyList(), false, fixedSide = 92f) {} }
@Composable private fun TutorialHeading(text: String) { Text(text, fontWeight = FontWeight.SemiBold, fontSize = 20.sp, textAlign = TextAlign.Center) }
