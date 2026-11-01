package com.centaurlabs.est

import android.media.AudioManager
import android.media.ToneGenerator
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.SystemBarStyle
import androidx.activity.compose.BackHandler
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.Fill
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.semantics.*
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.lifecycle.viewmodel.compose.viewModel
import kotlin.random.Random
import kotlinx.coroutines.delay
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.tween
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.WindowInsetsControllerCompat
import android.view.WindowManager

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            val model: GameModel = viewModel()
            val dark = when (model.colorScheme) { 1 -> false; 2 -> true; else -> isSystemInDarkTheme() }
            LaunchedEffect(model.keepAwake) {
                if (model.keepAwake) window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON) else window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
            }
            LaunchedEffect(model.screen, model.immersive) {
                val controller = WindowCompat.getInsetsController(window, window.decorView)
                controller.systemBarsBehavior = WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
                if ((model.screen == "game" || model.screen == "party") && model.immersive) controller.hide(WindowInsetsCompat.Type.statusBars()) else controller.show(WindowInsetsCompat.Type.statusBars())
            }
            LaunchedEffect(dark) {
                val transparent = android.graphics.Color.TRANSPARENT
                val bars = if (dark) SystemBarStyle.dark(transparent)
                    else SystemBarStyle.light(transparent, transparent)
                enableEdgeToEdge(statusBarStyle = bars, navigationBarStyle = bars)
            }
            EstApp(model, dark)
        }
    }
}

@Composable
fun EstApp(model: GameModel = viewModel(), dark: Boolean = isSystemInDarkTheme()) {
    val lifecycle = LocalLifecycleOwner.current.lifecycle
    DisposableEffect(lifecycle, model) {
        val observer = LifecycleEventObserver { _, event ->
            if (event == Lifecycle.Event.ON_STOP) model.pause()
            if (event == Lifecycle.Event.ON_START) model.resume()
        }
        lifecycle.addObserver(observer)
        onDispose { lifecycle.removeObserver(observer) }
    }
    val palette = if (model.orchard) Orchard else Classic
    val colors = if (dark) darkColorScheme(primary = palette[0], background = Color.Black, surface = Color(0xFF1C1C1E))
    else lightColorScheme(primary = palette[0], background = Color(0xFFF2F2F7), surface = Color.White, onSurface = Color.Black)
    CompositionLocalProvider(LocalPalette provides palette, LocalHighlights provides if (model.orchard) OrchardHighlights else ClassicHighlights, LocalPinstripes provides model.pinstripes, LocalAssist provides model.assist, LocalReducedMotion provides model.reduceMotion, LocalHighContrast provides model.highContrast) {
        MaterialTheme(colorScheme = colors) {
            Surface(Modifier.fillMaxSize(), color = colors.background) {
                Column(Modifier.safeDrawingPadding().fillMaxSize().padding(horizontal = 16.dp)) {
                    if (model.screen != "home" && model.screen != "game" && model.screen != "party" && model.screen != "tutorial") Row(Modifier.fillMaxWidth().padding(vertical = 8.dp), verticalAlignment = Alignment.CenterVertically) {
                        Text(when (model.screen) { "training" -> "Is this a set?"; "rules" -> "Rules"; "settings" -> "Settings"; "style" -> "Your play style"; "math" -> "The mathematics"; else -> "Personal bests" }, fontWeight = FontWeight.SemiBold, modifier = Modifier.weight(1f))
                        TextButton(onClick = { model.learned() }) { Text("Done") }
                    }
                    when (model.screen) {
                        "game" -> GameScreen(model)
                        "party" -> PartyScreen(model)
                        "rules" -> Rules(model)
                        "tutorial" -> Tutorial(model)
                        "training" -> Training(model)
                        "settings" -> Settings(model)
                        "records" -> Records(model)
                        "style" -> PlayStyle(model)
                        "math" -> Mathematics()
                        else -> Home(model)
                    }
                }
            }
        }
    }
    BackHandler(model.screen !in listOf("home", "game", "party")) { model.learned() }
}

@Composable
fun VaryingTitle(size: Int = 72, onCycle: () -> Unit = {}) {
    var index by remember { mutableIntStateOf(0) }
    val latestCycle by rememberUpdatedState(onCycle)
    LaunchedEffect(Unit) { while (true) { delay(7200); index = (index + 1) % 5; latestCycle() } }
    Row(horizontalArrangement = Arrangement.spacedBy((size * .06f).dp), modifier = Modifier.semantics { contentDescription = "EST"; heading() }) {
        listOf("EST", "TSE", "STE", "ETS", "TES")[index].forEach { letter ->
            Text(letter.toString(), fontSize = size.sp, fontWeight = FontWeight.Black,
                color = LocalPalette.current[when (letter) { 'E' -> 0; 'S' -> 1; else -> 2 }], modifier = Modifier.clearAndSetSemantics {})
        }
    }
}

@Composable
fun GameButton(text: String, modifier: Modifier = Modifier, primary: Boolean = false, tint: Int = 1, compact: Boolean = false, enabled: Boolean = true, onClick: () -> Unit) {
    val color = LocalPalette.current[tint]
    val high = LocalHighlights.current[tint]
    val height = if (compact) 46.dp else 58.dp
    val shape = RoundedCornerShape(height * .32f)
    Box(modifier.heightIn(min = height).alpha(if (enabled) 1f else .35f).clip(shape)
        .background(if (primary) Brush.linearGradient(listOf(high, color)) else Brush.linearGradient(listOf(color.copy(alpha = .08f), color.copy(alpha = .08f))))
        .then(if (primary) Modifier else Modifier.border(1.5.dp, color.copy(alpha = if (compact) .16f else .40f), shape))
        .clickable(enabled = enabled, role = Role.Button, onClick = onClick).padding(horizontal = 14.dp, vertical = 8.dp), contentAlignment = Alignment.Center) {
        if (text in listOf("×", "↻", "⚙", "Hint")) GameGlyph(text, if (primary) Color.White else color)
        else Row(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
            val glyph = when {
                text == "Solo" -> "person"
                text == "Together" || text == "Duel" || text == "4 players" -> "people"
                text == "Solo 81" -> "timer"
                text == "Quick 27" -> "bolt"
                text.startsWith("Daily") -> "calendar"
                text.startsWith("Resume") -> "play"
                text == "Is this a set?" -> "graduation"
                text == "Same room" -> "wifi"
                text == "Online" -> "antenna"
                else -> null
            }
            if (glyph != null) GameGlyph(glyph, if (primary) Color.White else color)
            Text(text, color = if (primary) Color.White else color, fontWeight = FontWeight.Bold, fontSize = if (compact) 15.sp else 20.sp, textAlign = TextAlign.Center, modifier = Modifier.weight(1f, fill = false))
        }
    }
}

@Composable
private fun Home(model: GameModel) {
    var menu by rememberSaveable { mutableStateOf("Play") }
    var demo by remember { mutableStateOf(EstCard.randomSet().map { it.id }) }
    BackHandler(menu != "Play") { menu = "Play" }
    BoxWithConstraints(Modifier.fillMaxSize()) {
        val wide = maxWidth > maxHeight
        val fourPlayers = maxWidth >= 600.dp || (minOf(maxWidth, maxHeight) >= 600.dp)
        val accessibility = androidx.compose.ui.platform.LocalDensity.current.fontScale >= 1.5f
        val hero: @Composable () -> Unit = {
            Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(16.dp)) {
                VaryingTitle { demo = EstCard.randomSet().map { it.id } }
                Text("A game of patterns", fontSize = 15.sp, fontWeight = FontWeight.SemiBold, color = MaterialTheme.colorScheme.onSurface.copy(alpha = .6f))
                Row(Modifier.padding(top = 8.dp), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    demo.forEachIndexed { index, id -> key(index) { DemoCard(id) } }
                }
            }
        }
        val panel: @Composable () -> Unit = {
            Column(Modifier.widthIn(max = 460.dp).fillMaxWidth()
                .background(MaterialTheme.colorScheme.surface.copy(alpha = .82f), RoundedCornerShape(38.56.dp))
                .border(1.dp, MaterialTheme.colorScheme.onSurface.copy(alpha = .06f), RoundedCornerShape(38.56.dp))
                .padding(20.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
                Row(Modifier.heightIn(min = 46.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    if (menu != "Play") GameButton("‹", Modifier.width(46.dp).semantics { contentDescription = "Back" }, compact = true) { menu = "Play" }
                    Text(menu, fontWeight = FontWeight.SemiBold, fontSize = 17.sp)
                }
                Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    when (menu) {
                        "Play" -> {
                            if (model.hasSave) GameButton(model.resumeTitle(), Modifier.fillMaxWidth(), primary = true, tint = 0) { model.restore() }
                            GameButton("Solo", Modifier.fillMaxWidth(), primary = !model.hasSave) { menu = "Solo" }
                            GameButton("Together", Modifier.fillMaxWidth(), tint = 0) { menu = "Together" }
                        }
                        "Solo" -> {
                            HomePair(accessibility,
                                { m -> GameButton("Solo 81", m, primary = true) { model.start(Mode.FULL) } },
                                { m -> GameButton("Quick 27", m) { model.start(Mode.QUICK) } })
                            Column(verticalArrangement = Arrangement.spacedBy(6.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                                Text("QUICK 27 HOLDS ONE TRAIT", fontSize = 13.sp, fontWeight = FontWeight.SemiBold, color = MaterialTheme.colorScheme.onSurface.copy(alpha = .6f))
                                Row(Modifier.fillMaxWidth().background(MaterialTheme.colorScheme.onSurface.copy(alpha = .07f), RoundedCornerShape(8.dp)).padding(2.dp)) {
                                    EstCard.traitNames.forEachIndexed { i, name ->
                                        Box(Modifier.weight(1f).clip(RoundedCornerShape(6.dp)).background(if (model.quickTrait == i) MaterialTheme.colorScheme.surface else Color.Transparent)
                                            .clickable(role = Role.RadioButton) { model.chooseQuickTrait(i) }.semantics { selected = model.quickTrait == i }.padding(vertical = 7.dp), contentAlignment = Alignment.Center) {
                                            Text(name, fontSize = 13.sp, fontWeight = FontWeight.Medium)
                                        }
                                    }
                                }
                            }
                            GameButton(model.dailyTitle(), Modifier.fillMaxWidth(), tint = 2) { model.start(Mode.FULL, daily = true) }
                            GameButton("Is this a set?", Modifier.fillMaxWidth()) { model.screen = "training" }
                        }
                        else -> {
                            Text("THIS DEVICE", Modifier.align(Alignment.CenterHorizontally), fontSize = 13.sp, fontWeight = FontWeight.SemiBold)
                            HomePair(accessibility,
                                { m -> GameButton("Duel", m, tint = 0) { model.startParty(2) } },
                                if (fourPlayers) ({ m -> GameButton("4 players", m, tint = 0) { model.startParty(4) } }) else null)
                            Text("SEPARATE DEVICES", Modifier.align(Alignment.CenterHorizontally), fontSize = 13.sp, fontWeight = FontWeight.SemiBold)
                            HomePair(accessibility,
                                { m -> GameButton("Same room", m, tint = 0, enabled = false) {} },
                                { m -> GameButton("Online", m, tint = 0, enabled = false) {} })
                        }
                    }
                }
            }
        }
        Column(Modifier.fillMaxSize()) {
            Row(Modifier.fillMaxWidth().height(48.dp), horizontalArrangement = Arrangement.End, verticalAlignment = Alignment.CenterVertically) {
                HomeTool("Leaderboards", "trophy", enabled = false) {}
                HomeTool("Rules", "question") { model.screen = "rules" }
                HomeTool("Stats", "chart") { model.screen = "style" }
                HomeTool("Settings", "⚙") { model.screen = "settings" }
            }
            if (wide && !accessibility) Row(Modifier.weight(1f).padding(16.dp), horizontalArrangement = Arrangement.spacedBy(32.dp), verticalAlignment = Alignment.CenterVertically) {
                Box(Modifier.weight(1f), contentAlignment = Alignment.Center) { hero() }
                Box(Modifier.weight(1f).verticalScroll(rememberScrollState())) { panel() }
            } else Column(Modifier.weight(1f).padding(horizontal = 4.dp).padding(bottom = 12.dp)
                .then(if (accessibility) Modifier.verticalScroll(rememberScrollState()) else Modifier), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(24.dp)) {
                if (!accessibility) Spacer(Modifier.weight(1f))
                hero()
                if (!accessibility) Spacer(Modifier.weight(1f))
                panel()
            }
        }
    }
}

@Composable private fun HomePair(stacked: Boolean, first: @Composable (Modifier) -> Unit, second: (@Composable (Modifier) -> Unit)?) {
    if (stacked) Column(verticalArrangement = Arrangement.spacedBy(12.dp)) { first(Modifier.fillMaxWidth()); second?.invoke(Modifier.fillMaxWidth()) }
    else Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) { first(Modifier.weight(1f)); second?.invoke(Modifier.weight(1f)) }
}

@Composable private fun HomeTool(label: String, glyph: String, enabled: Boolean = true, onClick: () -> Unit) {
    Box(Modifier.size(44.dp).alpha(if (enabled) 1f else .35f).semantics { contentDescription = label }
        .clickable(enabled = enabled, role = Role.Button, onClick = onClick), contentAlignment = Alignment.Center) {
        GameGlyph(glyph, LocalPalette.current[1])
    }
}

@Composable
private fun GameScreen(model: GameModel) {
    @Suppress("UNUSED_VARIABLE") val revision = model.revision
    val game = model.game ?: return
    var collectionTarget by remember { mutableStateOf<Offset?>(null) }
    var rotation by rememberSaveable { mutableFloatStateOf(0f) }
    var exit by remember { mutableStateOf(false) }
    var hintWarning by remember { mutableStateOf(false) }
    val haptic = LocalHapticFeedback.current
    BackHandler { if (game.finished) model.leave(true) else { model.dialogOpen = true; exit = true } }
    val board: @Composable (Modifier) -> Unit = { modifier ->
            Box(modifier, contentAlignment = Alignment.Center) {
                CompositionLocalProvider(LocalRotation provides rotation) {
                    Board(game.table, game.selected, game.pending, game.hinted, !game.paused && !game.finished, Modifier.fillMaxSize(), mismatchIds = game.mismatchIds, mismatchToken = game.mismatchToken, animateDeals = true, collectionTarget = collectionTarget) { id ->
                        val matched = model.select(id)
                        if (model.haptics) haptic.performHapticFeedback(if (matched) HapticFeedbackType.LongPress else HapticFeedbackType.TextHandleMove)
                    }
                }
                if (game.message.startsWith("Not a set")) Text(game.message, Modifier.align(Alignment.BottomCenter).background(MaterialTheme.colorScheme.surface, RoundedCornerShape(14.dp)).padding(12.dp).semantics { liveRegion = LiveRegionMode.Polite }, fontSize = 12.sp)
                if (game.paused && !exit && !hintWarning) GameButton("Paused · Resume", compact = true) { model.resume() }
            }
    }
    BoxWithConstraints(Modifier.fillMaxSize().padding(vertical = 16.dp)) {
        val wide = maxWidth > maxHeight
        Column(Modifier.fillMaxSize(), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Box(Modifier.fillMaxWidth().height(46.dp), contentAlignment = Alignment.Center) {
                if (model.showTimer) Text(formatTime(game.elapsed), fontSize = 28.sp, fontWeight = FontWeight.Bold, fontFamily = FontFamily.Monospace)
                Row(Modifier.fillMaxSize(), verticalAlignment = Alignment.CenterVertically) {
                    GameButton("×", Modifier.width(46.dp), compact = true) { model.dialogOpen = true; exit = true }
                    Spacer(Modifier.weight(1f))
                    GameButton("↻", Modifier.width(46.dp).semantics { contentDescription = "Rotate cards" }, compact = true) { rotation += 90 }
                    if (game.mode == Mode.FULL) {
                        Spacer(Modifier.width(8.dp))
                        GameButton("Hint", Modifier.width(46.dp).semantics { contentDescription = "Hint" }, compact = true, tint = 2, enabled = !game.finished && game.hinted.size < 2) {
                            if (game.hintUsed || model.isDaily) model.hint() else { model.dialogOpen = true; hintWarning = true }
                        }
                    }
                }
            }
            if (wide) {
                PileProgress(game, Modifier.widthIn(max = 360.dp).fillMaxWidth().align(Alignment.CenterHorizontally))
                Row(Modifier.weight(1f).fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(24.dp), verticalAlignment = Alignment.CenterVertically) {
                    Pile("DECK", game.deck.size, null)
                    board(Modifier.weight(1f).fillMaxHeight())
                    Pile("PLAYED", game.done.size, game.done.lastOrNull()?.let(::EstCard)) { collectionTarget = it }
                }
            } else {
                board(Modifier.weight(1f).fillMaxWidth())
                Piles(game) { collectionTarget = it }
            }
        }
        if (game.finished) Confetti()
        if (game.finished) Surface(Modifier.align(Alignment.Center).fillMaxWidth(), shape = RoundedCornerShape(28.dp), shadowElevation = 12.dp) {
            Column(Modifier.heightIn(max = 650.dp).verticalScroll(rememberScrollState()).padding(32.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(20.dp)) {
                VaryingTitle(40)
                Text(if (model.isDaily) "DAILY COMPLETE" else "COMPLETE", fontSize = 12.sp, fontWeight = FontWeight.SemiBold)
                Text(formatTime(game.elapsed), fontSize = 52.sp, fontWeight = FontWeight.Black)
                Text("${game.done.size / 3} sets, about ${(game.elapsed / 1000.0 / maxOf(1, game.done.size / 3)).toInt()} seconds each", textAlign = TextAlign.Center)
                Text(if (game.table.isEmpty()) "Perfect clear: all ${game.mode.deck().size} cards played." else "The last ${game.table.size} cards contain no set. This is a ${game.table.size}-card cap.", fontSize = 13.sp, textAlign = TextAlign.Center)
                model.insight.lines().forEach { Text(it, fontSize = 13.sp, textAlign = TextAlign.Center) }
                val best = if (model.isDaily) model.dailyBest() else model.best(game.mode)
                if (best != null) Text(if (game.elapsed <= best) { if (model.isDaily) "Today's best" else "New personal best" } else "${if (model.isDaily) "Today's best" else "Best"}: ${formatTime(best)}", fontWeight = FontWeight.Bold, color = LocalPalette.current[2])
                if (model.isDaily) {
                    Text("${model.dailyStreak()} day streak", color = LocalPalette.current[0])
                    Text("Same deal for everyone today. Dailies stay off the leaderboard.", fontSize = 13.sp, textAlign = TextAlign.Center)
                }
                GameButton("Play again", Modifier.fillMaxWidth(), primary = true) { model.start(game.mode, daily = model.isDaily) }
                GameButton("Menu", Modifier.fillMaxWidth(), compact = true) { model.leave(true) }
            }
        }
    }
    if (exit) AlertDialog(onDismissRequest = { exit = false; model.dialogOpen = false; model.resume() }, title = { Text("End this game?") }, text = { Text("The run and its time are lost.") }, confirmButton = { TextButton(onClick = { model.leave(true) }) { Text("End game") } }, dismissButton = { TextButton(onClick = { exit = false; model.dialogOpen = false; model.resume() }) { Text("Keep playing") } })
    if (hintWarning) AlertDialog(onDismissRequest = { hintWarning = false; model.dialogOpen = false; model.resume() }, title = { Text("Use a hint?") }, text = { Text("If you use a hint, this run will not appear on the leaderboard. Your time can still become a personal best.") }, confirmButton = { TextButton(onClick = { hintWarning = false; model.dialogOpen = false; model.resume(); model.hint() }) { Text("Use hint") } }, dismissButton = { TextButton(onClick = { hintWarning = false; model.dialogOpen = false; model.resume() }) { Text("Keep playing") } })
}

@Composable
fun Audit(cards: List<EstCard>) {
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        EstCard.audit(cards).forEachIndexed { i, valid ->
            val distinct = cards.map { it.traits[i] }.distinct().size
            Text("${if (valid) "✓" else "×"} ${EstCard.traitNames[i]} — ${when (distinct) { 1 -> "all the same"; 3 -> "all different"; else -> "two the same, one different" }}")
        }
    }
}

private fun trainingCards(model: GameModel): List<Int> = EstCard.trainingTrio(model.stats.mismatchesByTrait).map { it.id }

@Composable
private fun Training(model: GameModel) {
    var cards by rememberSaveable { mutableStateOf(trainingCards(model)) }
    var answer by rememberSaveable { mutableStateOf<Boolean?>(null) }
    var streak by rememberSaveable { mutableIntStateOf(0) }
    val valid = EstCard.valid(cards.map(::EstCard))
    Column(Modifier.fillMaxWidth().verticalScroll(rememberScrollState()), verticalArrangement = Arrangement.spacedBy(24.dp)) {

        Text("Streak $streak · Best ${model.trainingBest}")
        if (model.stats.mismatchesByTrait.sum() >= 3) {
            val trait = model.stats.mismatchesByTrait.indices.maxBy { model.stats.mismatchesByTrait[it] }
            Text("Extra practice on ${EstCard.traitNames[trait].lowercase()}, the trait you miss most in play.", fontSize = 13.sp)
        }
        Text("Is this a set?", style = MaterialTheme.typography.titleLarge)
        Board(cards, emptyList(), emptyList(), emptyList(), false, fixedSide = 96f) {}
        if (answer == null) {
            Row(horizontalArrangement = Arrangement.spacedBy(16.dp)) {
                listOf(true, false).forEach { choice ->
                    GameButton(if (choice) "Set" else "Not a set", Modifier.weight(1f), tint = if (choice) 1 else 0) { answer = choice; streak = if (choice == valid) streak + 1 else 0; model.training(streak) }
                }
            }
        } else {
            Text(if (answer == valid) "Right" else "Not quite", style = MaterialTheme.typography.titleLarge)
            Text(if (valid) "These three make a set." else "These three are not a set.")
            Audit(cards.map(::EstCard))
            GameButton("Next", Modifier.fillMaxWidth(), primary = true, tint = 0) { cards = trainingCards(model); answer = null }
        }
    }
}

@Composable
private fun Settings(model: GameModel) {
    var reset by remember { mutableStateOf(false) }
    Column(Modifier.fillMaxWidth().verticalScroll(rememberScrollState()), verticalArrangement = Arrangement.spacedBy(16.dp)) {
        InfoSection("Appearance") {
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                listOf("System", "Light", "Dark").forEachIndexed { i, name -> GameButton(name, Modifier.weight(1f), compact = true, primary = model.colorScheme == i) { model.chooseColorScheme(i) } }
            }
            Text("System follows the device. Light and Dark override it for EST only.", fontSize = 12.sp)
            SettingSwitch("Orchard palette", model.orchard) { model.toggle("orchard") }
        }
        InfoSection("Fill") {
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                GameButton("Shaded", Modifier.weight(1f), compact = true, primary = !model.pinstripes) { if (model.pinstripes) model.toggle("pinstripes") }
                GameButton("Pinstriped", Modifier.weight(1f), compact = true, primary = model.pinstripes) { if (!model.pinstripes) model.toggle("pinstripes") }
            }
            Row(Modifier.align(Alignment.CenterHorizontally), horizontalArrangement = Arrangement.spacedBy(12.dp)) { listOf(2,41,80).forEach { CardFace(EstCard(it), Modifier.size(72.dp)) } }
        }
        InfoSection("Sound & haptics") {
            SettingSwitch("Sound effects", model.sound) { model.toggle("sound") }
            SettingSwitch("Haptics", model.haptics) { model.toggle("haptics") }
        }
        InfoSection("Accessibility") {
            SettingSwitch("Reduce motion", model.reduceMotion) { model.toggle("reduceMotion") }
            SettingSwitch("High contrast", model.highContrast) { model.toggle("highContrast") }
            SettingSwitch("Color-blind assist", model.assist) { model.toggle("assist") }
        }
        InfoSection("Game") {
            SettingSwitch("Immersive game mode", model.immersive) { model.toggle("immersive") }
            SettingSwitch("Show solo timer", model.showTimer) { model.toggle("showTimer") }
            Text("Hides the live clock in Solo 81 and Quick 27 when turned off. Your time is still recorded.", fontSize = 12.sp)
            SettingSwitch("Keep screen awake", model.keepAwake) { model.toggle("keepAwake") }
        }
        InfoSection("Data") {
            GameButton("Your play style", Modifier.fillMaxWidth(), compact = true) { model.screen = "style" }
            GameButton("Reset local stats", Modifier.fillMaxWidth(), tint = 0, compact = true) { reset = true }
        }
        InfoSection("About") {
            Text("EST · ${BuildConfig.VERSION_NAME} (${BuildConfig.VERSION_CODE})")
            Text("A free, open-source game by Michell Zappa at Centaur Labs, inspired by SET.")
            GameButton("The mathematics", Modifier.fillMaxWidth(), compact = true) { model.screen = "math" }
        }
        Spacer(Modifier.height(16.dp))
    }
    if (reset) AlertDialog(onDismissRequest = { reset = false }, title = { Text("Reset local stats?") }, text = { Text("This removes personal bests and private learning stats from this device.") }, confirmButton = { TextButton(onClick = { model.resetStats(true); reset = false }) { Text("Reset stats") } }, dismissButton = { TextButton(onClick = { reset = false }) { Text("Cancel") } })
}

@Composable private fun SettingSwitch(title: String, value: Boolean, onChange: () -> Unit) {
    Row(Modifier.fillMaxWidth().heightIn(min = 48.dp), verticalAlignment = Alignment.CenterVertically) {
        Text(title, Modifier.weight(1f)); Switch(value, onCheckedChange = { onChange() }, modifier = Modifier.semantics { contentDescription = title })
    }
}

@Composable
private fun Records(model: GameModel) {
    Column(Modifier.fillMaxWidth().verticalScroll(rememberScrollState()), verticalArrangement = Arrangement.spacedBy(24.dp)) {
        Text("Personal bests", fontSize = 28.sp, fontWeight = FontWeight.Bold)
        Mode.entries.forEach { mode ->
            Text(mode.title, style = MaterialTheme.typography.titleLarge)
            Text(model.best(mode)?.let(::formatTime) ?: "—", style = MaterialTheme.typography.headlineSmall)
            HorizontalDivider()
        }
        Text("${model.rounds()} completed rounds · Practice best: ${model.trainingBest}")
        Text("Personal bests include hinted and paused games. These records stay on this device.")
    }
}

@Composable private fun DemoCard(id: Int) {
    var displayed by remember { mutableIntStateOf(id) }
    val angle = remember { Animatable(0f) }
    val reduced = LocalReducedMotion.current
    LaunchedEffect(id) {
        if (displayed != id) {
            if (!reduced) { angle.animateTo(90f, tween(320)); delay(17) }
            displayed = id
            if (!reduced) { angle.snapTo(-90f); angle.animateTo(0f, tween(320)) }
        }
    }
    CardFace(EstCard(displayed), Modifier.size(84.dp).graphicsLayer { rotationY = angle.value; cameraDistance = 10 * density })
}

@Composable private fun GameGlyph(name: String, color: Color) {
    Canvas(Modifier.size(22.dp).clearAndSetSemantics {}) {
        val w = size.width; val h = size.height; val stroke = 1.8.dp.toPx()
        when(name) {
            "×" -> { drawLine(color, Offset(w*.25f,h*.25f), Offset(w*.75f,h*.75f), stroke); drawLine(color, Offset(w*.75f,h*.25f), Offset(w*.25f,h*.75f), stroke) }
            "↻" -> { drawArc(color, -60f, 285f, false, Offset(w*.15f,h*.15f), Size(w*.7f,h*.7f), style = Stroke(stroke)); drawLine(color, Offset(w*.75f,0f), Offset(w*.77f,h*.3f),stroke); drawLine(color,Offset(w*.77f,h*.3f),Offset(w*.5f,h*.25f),stroke) }
            "⚙" -> { drawCircle(color,w*.32f,style=Stroke(stroke)); drawCircle(color,w*.12f,style=Stroke(stroke)); repeat(8) { i -> val a = i*Math.PI/4; drawLine(color,Offset(w/2+kotlin.math.cos(a).toFloat()*w*.32f,h/2+kotlin.math.sin(a).toFloat()*h*.32f),Offset(w/2+kotlin.math.cos(a).toFloat()*w*.46f,h/2+kotlin.math.sin(a).toFloat()*h*.46f),stroke) } }
            "person", "people" -> {
                val people = if (name == "person") 1 else 2
                repeat(people) { i ->
                    val x = if (people == 1) w*.5f else w*(.3f+i*.4f)
                    drawCircle(color,w*.15f,Offset(x,h*.25f))
                    drawRoundRect(color,Offset(x-w*.22f,h*.47f),Size(w*.44f,h*.39f),cornerRadius=androidx.compose.ui.geometry.CornerRadius(w*.15f))
                }
            }
            "timer" -> {
                drawCircle(color,w*.36f,Offset(w*.5f,h*.58f),style=Stroke(stroke)); drawLine(color,Offset(w*.4f,h*.06f),Offset(w*.6f,h*.06f),stroke)
                drawLine(color,Offset(w*.5f,h*.3f),Offset(w*.5f,h*.58f),stroke)
            }
            "bolt", "play" -> {
                val path = Path().apply {
                    if (name == "play") { moveTo(w*.25f,h*.1f); lineTo(w*.85f,h*.5f); lineTo(w*.25f,h*.9f) }
                    else { moveTo(w*.63f,0f); lineTo(w*.15f,h*.58f); lineTo(w*.48f,h*.58f); lineTo(w*.37f,h); lineTo(w*.87f,h*.4f); lineTo(w*.54f,h*.4f) }; close()
                }; drawPath(path,color)
            }
            "calendar" -> {
                drawRoundRect(color,Offset(w*.1f,h*.17f),Size(w*.8f,h*.72f),cornerRadius=androidx.compose.ui.geometry.CornerRadius(w*.08f),style=Stroke(stroke))
                drawLine(color,Offset(w*.1f,h*.38f),Offset(w*.9f,h*.38f),stroke)
                for (x in listOf(.3f,.7f)) drawLine(color,Offset(w*x,h*.05f),Offset(w*x,h*.25f),stroke)
            }
            "graduation" -> {
                val path = Path().apply { moveTo(0f,h*.35f); lineTo(w*.5f,h*.1f); lineTo(w,h*.35f); lineTo(w*.5f,h*.6f); close() }
                drawPath(path,color); drawLine(color,Offset(w*.2f,h*.55f),Offset(w*.5f,h*.8f),stroke); drawLine(color,Offset(w*.5f,h*.8f),Offset(w*.8f,h*.55f),stroke)
            }
            "wifi", "antenna" -> {
                for (radius in listOf(.25f,.5f,.75f)) drawArc(color,225f,90f,false,Offset(w*.5f-w*radius,h*.9f-h*radius),Size(w*radius*2,h*radius*2),style=Stroke(stroke))
                drawCircle(color,stroke,Offset(w*.5f,h*.88f))
            }
            "question" -> {
                drawCircle(color,w*.43f,style=Stroke(stroke))
                val path = Path().apply { moveTo(w*.35f,h*.35f); cubicTo(w*.35f,h*.15f,w*.75f,h*.2f,w*.6f,h*.43f); lineTo(w*.5f,h*.55f); lineTo(w*.5f,h*.62f) }
                drawPath(path,color,style=Stroke(stroke)); drawCircle(color,stroke*.65f,Offset(w*.5f,h*.76f))
            }
            "chart" -> {
                drawLine(color,Offset(w*.08f,h*.92f),Offset(w*.95f,h*.92f),stroke)
                repeat(3) { i -> val top = listOf(.55f,.15f,.35f)[i]; drawRoundRect(color,Offset(w*(.15f+i*.28f),h*top),Size(w*.15f,h*(.8f-top)),cornerRadius=androidx.compose.ui.geometry.CornerRadius(2.dp.toPx())) }
            }
            "trophy" -> {
                val cup = Path().apply { moveTo(w*.25f,h*.12f); lineTo(w*.75f,h*.12f); lineTo(w*.69f,h*.49f); quadraticTo(w*.5f,h*.75f,w*.31f,h*.49f); close() }
                drawPath(cup,color,style=Stroke(stroke)); drawLine(color,Offset(w*.5f,h*.63f),Offset(w*.5f,h*.85f),stroke); drawLine(color,Offset(w*.3f,h*.9f),Offset(w*.7f,h*.9f),stroke)
                drawArc(color,0f,180f,false,Offset(w*.02f,h*.17f),Size(w*.3f,h*.3f),style=Stroke(stroke)); drawArc(color,0f,180f,false,Offset(w*.68f,h*.17f),Size(w*.3f,h*.3f),style=Stroke(stroke))
            }
            else -> {
                val bulb = Path().apply { moveTo(w*.35f,h*.73f); lineTo(w*.35f,h*.6f); cubicTo(-w*.05f,h*.15f,w*.28f,0f,w*.5f,0f); cubicTo(w*.72f,0f,w*1.05f,h*.15f,w*.65f,h*.6f); lineTo(w*.65f,h*.73f); close() }
                drawPath(bulb,color,style=Stroke(stroke)); drawLine(color,Offset(w*.35f,h*.85f),Offset(w*.65f,h*.85f),stroke); drawLine(color,Offset(w*.42f,h*.97f),Offset(w*.58f,h*.97f),stroke)
            }
        }
    }
}
