package br.meigenly.data.db.dao

import androidx.room.Dao
import androidx.room.Query
import androidx.room.Upsert
import br.meigenly.data.db.entity.SeedStateEntity

@Dao
interface SeedStateDao {

    @Query("SELECT seed_version FROM seed_state WHERE id = 1")
    suspend fun installedVersion(): Long?

    @Upsert
    suspend fun upsert(state: SeedStateEntity)
}
