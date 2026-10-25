package br.meigenly.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import br.meigenly.core.util.initials
import br.meigenly.core.util.toAccentColor

/**
 * Text-only avatar: accent circle with initials — no third-party imagery.
 */
@Composable
fun AccentAvatar(
    name: String,
    accent: String?,
    modifier: Modifier = Modifier,
    size: Dp = 48.dp,
) {
    val background = accent.toAccentColor().let { color ->
        // soften for a light theme
        color.copy(alpha = 0.9f)
    }
    Box(
        modifier = modifier.size(size).background(background, CircleShape),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = name.initials(),
            style = MaterialTheme.typography.titleMedium,
            color = Color.White,
        )
    }
}
