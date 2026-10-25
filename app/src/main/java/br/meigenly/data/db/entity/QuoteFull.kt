package br.meigenly.data.db.entity

import androidx.room.ColumnInfo
import androidx.room.Embedded

/**
 * Quote plus the display names of its character and work (single JOIN query),
 * consumed by the reader, favorites, search and share features.
 */
data class QuoteFull(
    @Embedded val quote: QuoteEntity,
    val characterName: String,
    val characterSlug: String,
    val characterArc: String?,
    val workTitle: String,
    val workSlug: String,
    @ColumnInfo(name = "accent_color")
    val workAccentColor: String?,
    /** Only filled by the history JOIN; null in favorites/content queries. */
    @ColumnInfo(name = "viewed_at")
    val viewedAt: Long? = null,
)
