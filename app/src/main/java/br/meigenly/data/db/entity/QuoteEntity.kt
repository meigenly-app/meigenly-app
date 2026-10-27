package br.meigenly.data.db.entity

import androidx.room.ColumnInfo
import androidx.room.Entity
import androidx.room.ForeignKey
import androidx.room.Index
import androidx.room.PrimaryKey

/**
 * "Versículo" do mapeamento: uma frase individual.
 */
@Entity(
    tableName = "quotes",
    foreignKeys = [
        ForeignKey(
            entity = CharacterEntity::class,
            parentColumns = ["id"],
            childColumns = ["character_id"],
            onDelete = ForeignKey.CASCADE,
        ),
    ],
    indices = [Index(value = ["character_id"])],
)
data class QuoteEntity(
    @PrimaryKey(autoGenerate = true)
    val id: Long = 0,
    @ColumnInfo(name = "character_id")
    val characterId: Long,
    @ColumnInfo(name = "text")
    val text: String,
    /** Diacritic/case-folded copy of [text] for accent-insensitive FTS search. */
    @ColumnInfo(name = "text_norm")
    val textNorm: String? = null,
    @ColumnInfo(name = "text_original")
    val textOriginal: String? = null,
    /** Japanese kanji source text (seed v4). */
    @ColumnInfo(name = "text_japanese")
    val textJapanese: String? = null,
    /** Diacritic/case-folded copy of [textOriginal] for FTS search (null when no original). */
    @ColumnInfo(name = "text_original_norm")
    val textOriginalNorm: String? = null,
    /** e.g. "Naruto Ep. 12"; null when the source is unknown. */
    @ColumnInfo(name = "episode")
    val episode: String? = null,
    @ColumnInfo(name = "context_info")
    val context: String? = null,
    @ColumnInfo(name = "sort_order")
    val sortOrder: Int = 0,
)
