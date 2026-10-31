package br.meigenly.data.db.entity

import androidx.room.ColumnInfo
import androidx.room.Embedded

/**
 * Character row plus the owning work slug, so the search list can load the
 * bundled portrait from characters/<workSlug>/<slug>.jpg.
 */
data class CharacterSearchRow(
    @Embedded val character: CharacterEntity,
    @ColumnInfo(name = "work_slug")
    val workSlug: String,
)
