package br.meigenly.domain.model

/**
 * Read-side domain models consumed by ViewModels and screens.
 * Decoupled from Room entities so the storage shape can change without touching the UI.
 */
data class Work(
    val id: Long,
    val slug: String,
    val title: String,
    val titleOriginal: String?,
    val year: Int?,
    val description: String?,
    val accentColor: String?,
)

data class Character(
    val id: Long,
    val workId: Long,
    val slug: String,
    val name: String,
    val nameOriginal: String?,
    val arc: String?,
    val description: String?,
    /** Total quotes under this character (E2 list badge). */
    val quoteCount: Int,
)

data class Quote(
    val id: Long,
    val characterId: Long,
    val text: String,
    val textOriginal: String?,
    /** Japanese kanji source (seed v4); null in the legacy catalog. */
    val textJapanese: String?,
    val episode: String?,
    val context: String?,
)
