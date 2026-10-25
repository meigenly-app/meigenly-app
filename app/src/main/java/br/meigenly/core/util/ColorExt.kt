package br.meigenly.core.util

import androidx.compose.ui.graphics.Color

/** Parses a seed hex color like "#FF8A00"; null or malformed falls back to [default]. */
fun String?.toAccentColor(default: Color = Color(0xFFA35C00)): Color {
    val hex = this?.removePrefix("#")
    if (hex != null &&
        hex.length == 6 &&
        hex.all { it.isDigit() || it in 'a'..'f' || it in 'A'..'F' }
    ) {
        return Color(hex.toLong(16) or 0xFF000000)
    }
    return default
}

/** Initials for the text-only avatars (work/character cards). */
fun String.initials(maxLength: Int = 2): String =
    split(" ")
        .filter { it.isNotBlank() }
        .take(maxLength)
        .joinToString("") { word -> word.first().uppercase() }
