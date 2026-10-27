package br.meigenly.data.db.seed

import kotlinx.serialization.Serializable

/**
 * DTOs mirroring assets/seed/app_data.json (the frozen contract from the planning phase).
 * The authoring-only "review" flag is intentionally absent: unknown fields are skipped,
 * so authoring metadata never leaks into the database.
 */
@Serializable
data class SeedFile(
    val schemaVersion: Int = 1,
    val works: List<SeedWork> = emptyList(),
)

@Serializable
data class SeedWork(
    val slug: String,
    val title: String,
    val titleOriginal: String? = null,
    val year: Int? = null,
    val description: String? = null,
    val accentColor: String? = null,
    val characters: List<SeedCharacter> = emptyList(),
)

@Serializable
data class SeedCharacter(
    val slug: String,
    val name: String,
    val nameOriginal: String? = null,
    val arc: String? = null,
    val description: String? = null,
    val quotes: List<SeedQuote> = emptyList(),
)

@Serializable
data class SeedQuote(
    val text: String,
    val textOriginal: String? = null,
    val textJapanese: String? = null,
    val episode: String? = null,
    val context: String? = null,
)
