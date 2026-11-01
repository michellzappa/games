package com.centaurlabs.est

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.rotate
import androidx.compose.ui.graphics.drawscope.translate
import kotlin.math.PI
import kotlin.math.sin
import kotlin.math.sqrt
import kotlin.random.Random

private data class Particle(val x: Float, val side: Float, val speed: Float, val phase: Float, val wobble: Float, val spin: Float, val tint: Int, val shape: Int, val opacity: Float)

/** The same 40-particle ranges and motion equations as GameShell/ConfettiView. */
@Composable fun Confetti() {
    val colors = LocalPalette.current
    val particles = remember { List(40) { Particle(Random.nextFloat(), 10+Random.nextFloat()*16, .08f+Random.nextFloat()*.10f, Random.nextFloat(), 1.2f+Random.nextFloat()*1.4f, -2+Random.nextFloat()*4, Random.nextInt(3), Random.nextInt(3), .5f+Random.nextFloat()*.45f) } }
    var seconds by remember { mutableFloatStateOf(0f) }
    val reduced = LocalReducedMotion.current
    LaunchedEffect(reduced) {
        if (!reduced) {
            val start = withFrameNanos { it }
            while (true) withFrameNanos { seconds = (it-start)/1_000_000_000f }
        }
    }
    Canvas(Modifier.fillMaxSize()) {
        for (p in particles) {
            val progress = (seconds*p.speed+p.phase)%1
            val side = p.side*density
            val y = progress*(size.height+2*side)-side
            val x = p.x*size.width + sin(seconds*p.wobble+p.phase*10)*18*density
            translate(x,y) {
                rotate((seconds*p.spin+p.phase*PI.toFloat()*2)*180/PI.toFloat(), Offset.Zero) {
                    val color = colors[p.tint].copy(alpha=p.opacity)
                    when (p.shape) {
                        0 -> drawCircle(color,side/2,Offset.Zero)
                        1 -> drawRoundRect(color,Offset(-side/2,-side/2),Size(side,side),CornerRadius(side*.1f))
                        else -> { val height=side*sqrt(3f)/2; val path=Path().apply { moveTo(0f,-height/2); lineTo(side/2,height/2); lineTo(-side/2,height/2); close() }; drawPath(path,color) }
                    }
                }
            }
        }
    }
}
