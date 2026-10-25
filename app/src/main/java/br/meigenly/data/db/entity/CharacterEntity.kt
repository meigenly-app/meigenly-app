package br.meigenly.data.db.entity

import androidx.room.ColumnInfo
import androidx.room.Entity
import androidx.room.ForeignKey
import androidx.room.Index
import androidx.room.PrimaryKey

/**
 * "Capítulo" do mapeamento: um personagem dentro de uma obra.
 * Deleting a work cascades to its characters, quotes, favorites and history rows.
 */
@Entity(
    tableName = "characters",
    foreignKeys = [
        ForeignKey(
            entity = WorkEntity::class,
            parentColumns = ["id"],
            childColumns = ["work_id"],
            onDelete = ForeignKey.CASCADE,
        ),
    ],
    indices = [
        Index(value = ["work_id"]),
        Index(value = ["work_id", "slug"], unique = true),
    ],
)
data class CharacterEntity(
    @PrimaryKey(autoGenerate = true)
    val id: Long = 0,
    @ColumnInfo(name = "work_id")
    val workId: Long,
    @ColumnInfo(name = "slug")
    val slug: String,
    @ColumnInfo(name = "name")
    val name: String,
    @ColumnInfo(name = "name_original")
    val nameOriginal: String? = null,
    val arc: String? = null,
    val description: String? = null,
    @ColumnInfo(name = "sort_order")
    val sortOrder: Int = 0,
)
