package br.meigenly.data.db.entity

import androidx.room.Embedded
import androidx.room.Relation

/**
 * DB row-level relations; ViewModels consume mapped domain models instead of these directly.
 */
data class WorkWithCharacters(
    @Embedded val work: WorkEntity,
    @Relation(parentColumn = "id", entityColumn = "work_id")
    val characters: List<CharacterEntity>,
)

data class CharacterWithQuotes(
    @Embedded val character: CharacterEntity,
    @Relation(parentColumn = "id", entityColumn = "character_id")
    val quotes: List<QuoteEntity>,
)
