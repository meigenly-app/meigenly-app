package br.meigenly.data.db.entity

import androidx.room.ColumnInfo
import androidx.room.Entity
import androidx.room.PrimaryKey

/**
 * Single-row table tracking which seed version is installed,
 * so a future seed update can repopulate without touching user tables.
 */
@Entity(tableName = "seed_state")
data class SeedStateEntity(
    /** Always 1; enforced by the installer. */
    @PrimaryKey
    val id: Int = 1,
    @ColumnInfo(name = "seed_version")
    val seedVersion: Long,
)
