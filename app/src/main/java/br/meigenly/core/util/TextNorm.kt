package br.meigenly.core.util

import java.text.Normalizer

/**
 * Case + diacritic folding used consistently when (a) building search tokens
 * and (b) persisting the normalized quote text at seed install time.
 */
object TextNorm {
    fun normalize(text: String): String =
        Normalizer.normalize(text, Normalizer.Form.NFD)
            .replace(COMBINING_MARKS, "")
            .lowercase()

    private val COMBINING_MARKS = "\\p{Mn}+".toRegex()
}
