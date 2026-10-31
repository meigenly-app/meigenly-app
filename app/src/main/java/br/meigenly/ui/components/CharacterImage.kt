package br.meigenly.ui.components

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

/** Reads characters/<workSlug>/<slug>.jpg from the bundled assets, or null. */
private suspend fun loadPortrait(
    context: Context,
    workSlug: String?,
    slug: String,
): Bitmap? {
    if (workSlug.isNullOrBlank() || slug.isBlank()) return null
    return withContext(Dispatchers.IO) {
        runCatching {
            context.assets
                .open("characters/$workSlug/$slug.jpg")
                .use { BitmapFactory.decodeStream(it) }
        }.getOrNull()
    }
}

/**
 * Character portrait loaded from bundled assets (characters/<workSlug>/<slug>.jpg);
 * falls back to the accent initial avatar while loading or when no image is bundled.
 */
@Composable
fun CharacterImage(
    workSlug: String?,
    slug: String,
    name: String,
    accent: String?,
    modifier: Modifier = Modifier,
    size: Dp = 48.dp,
) {
    val context = LocalContext.current
    var bitmap by remember(workSlug, slug) { mutableStateOf<Bitmap?>(null) }
    LaunchedEffect(workSlug, slug) {
        bitmap = loadPortrait(context, workSlug, slug)
    }
    val bmp = bitmap
    if (bmp != null) {
        Image(
            bitmap = bmp.asImageBitmap(),
            contentDescription = name,
            modifier = modifier.size(size).clip(CircleShape),
            contentScale = ContentScale.Crop,
        )
    } else {
        AccentAvatar(name = name, accent = accent, modifier = modifier, size = size)
    }
}

/**
 * Full-screen portrait viewer: dark backdrop, image fitted and centered,
 * any tap dismisses. Used by the character summary sheet.
 */
@Composable
fun CharacterPhotoDialog(
    workSlug: String?,
    slug: String?,
    name: String,
    onDismiss: () -> Unit,
) {
    val context = LocalContext.current
    var bitmap by remember(workSlug, slug) { mutableStateOf<Bitmap?>(null) }
    LaunchedEffect(workSlug, slug) {
        bitmap = loadPortrait(context, workSlug, slug ?: "")
    }
    Dialog(
        onDismissRequest = onDismiss,
        properties = DialogProperties(usePlatformDefaultWidth = false),
    ) {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(Color.Black.copy(alpha = 0.94f))
                .clickable(onClick = onDismiss),
            contentAlignment = Alignment.Center,
        ) {
            val bmp = bitmap
            if (bmp != null) {
                Image(
                    bitmap = bmp.asImageBitmap(),
                    contentDescription = name,
                    modifier = Modifier.fillMaxSize().padding(12.dp),
                    contentScale = ContentScale.Fit,
                )
            } else {
                Text(
                    text = name,
                    color = Color.White,
                    style = MaterialTheme.typography.titleLarge,
                    textAlign = TextAlign.Center,
                    modifier = Modifier.padding(32.dp),
                )
            }
        }
    }
}
