package br.meigenly.ui.intro

import android.media.MediaPlayer
import android.net.Uri
import android.view.Gravity
import android.view.ViewGroup
import android.widget.FrameLayout
import android.widget.VideoView
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.viewinterop.AndroidView
import br.meigenly.R

/**
 * Full-screen intro video shown on app open (brand moment).
 * Plays once; any tap skips it. Fades out into the app when done.
 */
@Composable
fun IntroOverlay(onFinished: () -> Unit) {
    val context = LocalContext.current
    var releasing by remember { mutableStateOf(false) }
    val alpha by animateFloatAsState(
        targetValue = if (releasing) 0f else 1f,
        animationSpec = tween(durationMillis = 350),
        label = "introFade",
    )
    val videoUri = remember {
        Uri.parse("android.resource://${context.packageName}/${R.raw.intro}")
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(NavyScreen)
            .alpha(alpha)
            .clickable(
                interactionSource = remember { MutableInteractionSource() },
                indication = null,
            ) { releasing = true },
        contentAlignment = Alignment.Center,
    ) {
        AndroidView(
            modifier = Modifier.fillMaxSize(),
            factory = { ctx ->
                // Frame container keeps the video centered at its aspect ratio
                // (VideoView alone would stretch to the holder size).
                FrameLayout(ctx).apply {
                    val player = VideoView(ctx).apply {
                        setVideoURI(videoUri)
                        layoutParams = FrameLayout.LayoutParams(
                            ViewGroup.LayoutParams.WRAP_CONTENT,
                            ViewGroup.LayoutParams.WRAP_CONTENT,
                            Gravity.CENTER,
                        )
                        setOnPreparedListener { mp ->
                            // Fit inside the screen without stretching.
                            val vw = mp.videoWidth.toFloat()
                            val vh = mp.videoHeight.toFloat()
                            if (vw > 0 && vh > 0) {
                                val metrics = ctx.resources.displayMetrics
                                val scale = minOf(
                                    metrics.widthPixels / vw,
                                    metrics.heightPixels / vh,
                                )
                                layoutParams = FrameLayout.LayoutParams(
                                    (vw * scale).toInt(),
                                    (vh * scale).toInt(),
                                    Gravity.CENTER,
                                )
                            }
                            start()
                        }
                        setOnCompletionListener { releasing = true }
                    }
                    addView(player)
                }
            },
        )
    }

    if (releasing && alpha <= 0.01f) {
        LaunchedEffect(Unit) { onFinished() }
    }
}

private val NavyScreen = Color(0xFF111822)
