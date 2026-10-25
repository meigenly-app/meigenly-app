package br.meigenly.data.db.entity

import androidx.room.ColumnInfo
import androidx.room.Entity
import androidx.room.ForeignKey
import androidx.room.PrimaryKey

/**
 * Quote marked as favorite by the user (all-user-generated table).
 * Deleting a quote cascades to its favorite row.
 */
@Entity(
    tableName = "favorites",
    foreignKeys = [
        ForeignKey(
            entity = QuoteEntity::class,
            parentColumns = ["id"],
            childColumns = ["quote_id"],
            onDelete = ForeignKey.CASCADE,
        ),
    ],
)
data class FavoriteEntity(
    /** One favorite per quote. */
    @PrimaryKey
    @ColumnInfo(name = "quote_id")
    val quoteId: Long,
    @ColumnInfo(name = "created_at")
    val createdAt: Long = System.currentTimeMillis(),
)
