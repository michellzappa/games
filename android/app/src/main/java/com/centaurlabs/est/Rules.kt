package com.centaurlabs.est
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

@Composable fun Rules(model: GameModel) {
    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(bottom = 28.dp), verticalArrangement = Arrangement.spacedBy(20.dp)) {
        Text("Learn the rule, then play it", fontSize = 22.sp, fontWeight = FontWeight.Bold)
        Text("A quick guide to the game, its modes, and the idea underneath all 81 cards.")
        InfoSection("Learn the rule") {
            Text("Start here if you are new to EST.", fontSize = 12.sp)
            GameButton("Walk me through it", Modifier.fillMaxWidth(), primary = true) { model.screen = "tutorial" }
            GameButton("The mathematics", Modifier.fillMaxWidth(), compact = true) { model.screen = "math" }
            Text("Cards are points. Sets are lines. Explore the four-trit structure.", fontSize = 12.sp)
        }
        InfoSection("Choose a mode") {
            Text("Pick a game and start playing.", fontSize = 12.sp)
            RuleRow("Solo 81", "Clear all 81 cards against the clock.")
            RuleRow("Quick 27", "Play the 27 solid cards for a shorter, faster round.")
            RuleRow("Duel", "Play pass-around on one phone.")
        }
        InfoSection("How the game works") {
            Text("The same rule applies in every mode.", fontSize = 12.sp)
            RuleRow("The deck", "81 cards cover every combination of count, color, shape, and fill. Each trait has three values.")
            RuleRow("A valid set", "Three cards work when every trait is either the same on all three or different on all three. Two and one never works.")
            RuleRow("The table", "Start with 12 cards. Tap three that form a set. If none exists, three more cards appear automatically.")
            RuleRow("In a duel", "Buzz first, then tap the three cards within 5 seconds. A miss costs a point and a short lockout.")
        }
        InfoSection("About EST") {
            Text("A free game built around the structure of its deck.", fontSize = 12.sp)
            Text("EST is a free, open-source game inspired by SET, the card game Marsha Falco created in 1974. It has its own name, artwork, and code, and is not affiliated with or endorsed by SET's makers. SET is a registered trademark of Cannei, LLC.")
        }
    }
}
@Composable private fun RuleRow(title: String, detail: String) { Column(verticalArrangement = Arrangement.spacedBy(3.dp)) { Text(title, fontWeight = FontWeight.SemiBold); Text(detail, fontSize = 13.sp) } }
