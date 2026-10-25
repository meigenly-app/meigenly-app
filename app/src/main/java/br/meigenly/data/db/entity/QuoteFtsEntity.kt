package br.meigenly.data.db.entity

import androidx.room.ColumnInfo
import androidx.room.Entity
import androidx.room.Fts4

/**
 * Full-text index over the pre-normalized quote text (TextNorm) — built at seed
 * install time so tokenizer quirks never affect accent folding.
 * rowid mirrors QuoteEntity.id via contentEntity.
 */
@Fts4(contentEntity = QuoteEntity::class)
@Entity(tableName = "quotes_fts")
data class QuoteFtsEntity(
    @ColumnInfo(name = "text_norm")
    val textNorm: String,
    @ColumnInfo(name = "text_original_norm")
    val textOriginalNorm: String? = null,
)
