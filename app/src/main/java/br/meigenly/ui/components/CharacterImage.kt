package br.meigenly.ui.components

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import androidx.compose.foundation.Image
import androidx.compose.foundation.shape.CircleShape
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
        if (workSlug.isNullOrBlank()) return@LaunchedEffect
        bitmap = withContext(Dispatchers.IO) {
            runCatching {
                context.assets
                    .open("characters/$workSlug/$slug.jpg")
                    .use { BitmapFactory.decodeStream(it) }
            }.getOrNull()
        }
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
