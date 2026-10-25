package br.meigenly.data.db.entity

import androidx.room.ColumnInfo
import androidx.room.Embedded

/**
 * Character row plus its quote count, for the character list screen (E2).
 */
data class CharacterWithCount(
    @Embedded val character: CharacterEntity,
    @ColumnInfo(name = "quote_count")
    val quoteCount: Int,
)
