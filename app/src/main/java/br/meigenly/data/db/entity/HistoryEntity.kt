package br.meigenly.data.db.entity

import androidx.room.ColumnInfo
import androidx.room.Entity
import androidx.room.ForeignKey
import androidx.room.Index
import androidx.room.PrimaryKey

/**
 * One row per quote reading. Later at E8 we trim old history.
 */
@Entity(
    tableName = "history",
    foreignKeys = [
        ForeignKey(
            entity = QuoteEntity::class,
            parentColumns = ["id"],
            childColumns = ["quote_id"],
            onDelete = ForeignKey.CASCADE,
        ),
    ],
    indices = [Index(value = ["quote_id"]), Index(value = ["viewed_at"])],
)
data class HistoryEntity(
    @PrimaryKey(autoGenerate = true)
    val id: Long = 0,
    @ColumnInfo(name = "quote_id")
    val quoteId: Long,
    @ColumnInfo(name = "viewed_at")
    val viewedAt: Long = System.currentTimeMillis(),
)
