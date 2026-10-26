package br.meigenly.ui.components

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import androidx.compose.foundation.Image
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

/**
 * Cover image for a work, loaded from bundled assets (covers/<slug>.jpg).
 * Falls back to the letter avatar while loading or when no cover is bundled.
 */
@Composable
fun WorkCover(
    slug: String,
    title: String,
    accent: String?,
    modifier: Modifier = Modifier,
    size: Dp = 64.dp,
) {
    val context = LocalContext.current
    var bitmap by remember(slug) { mutableStateOf<Bitmap?>(null) }
    LaunchedEffect(slug) {
        bitmap = withContext(Dispatchers.IO) {
            runCatching {
                context.assets.open("covers/$slug.jpg").use { BitmapFactory.decodeStream(it) }
            }.getOrNull()
        }
    }
    val bmp = bitmap
    if (bmp != null) {
        Image(
            bitmap = bmp.asImageBitmap(),
            contentDescription = title,
            modifier = modifier
                .size(size)
                .clip(RoundedCornerShape(12.dp)),
            contentScale = ContentScale.Crop,
        )
    } else {
        AccentAvatar(name = title, accent = accent, modifier = modifier, size = size)
    }
}
