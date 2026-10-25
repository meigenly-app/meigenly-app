package br.meigenly.data.db.entity

import androidx.room.ColumnInfo
import androidx.room.Entity
import androidx.room.Index
import androidx.room.PrimaryKey

/**
 * "Livro" do mapeamento: uma obra de anime.
 * Read-only content, populated from the embedded seed JSON.
 */
@Entity(
    tableName = "works",
    indices = [Index(value = ["slug"], unique = true)],
)
data class WorkEntity(
    @PrimaryKey(autoGenerate = true)
    val id: Long = 0,
    @ColumnInfo(name = "slug")
    val slug: String,
    val title: String,
    @ColumnInfo(name = "title_original")
    val titleOriginal: String? = null,
    val year: Int? = null,
    val description: String? = null,
    @ColumnInfo(name = "accent_color")
    val accentColor: String? = null,
    @ColumnInfo(name = "sort_order")
    val sortOrder: Int = 0,
)
