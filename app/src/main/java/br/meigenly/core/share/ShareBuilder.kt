package br.meigenly.core.share

import br.meigenly.data.db.entity.QuoteFull

/** Pure share-text builder; unit tested without Android runtime.
 *
 * Formats:
 *
 *    “Frase”
 *    — Personagem, Obra (Episódio)
 *
 *    kanji
 *    romaji
 *
 *    via Meigenly
 */
object ShareBuilder {

    fun buildShareText(item: QuoteFull): String {
        val attribution = buildString {
            append(item.characterName)
            if (item.workTitle.isNotBlank()) {
                append(", ${item.workTitle}")
            }
            if (!item.quote.episode.isNullOrBlank()) {
                append(" (${item.quote.episode})")
            }
        }
        return buildString {
            append("\u201C").append(item.quote.text).append("\u201D\n")
            append("\u2014 ").append(attribution)
            append("\n")
            item.quote.textJapanese
                ?.takeIf { it.isNotBlank() }
                ?.let { append(it).append("\n") }
            item.quote.textOriginal
                ?.takeIf { it.isNotBlank() }
                ?.let { append(it).append("\n") }
            append("\nvia Meigenly")
        }
    }
}
