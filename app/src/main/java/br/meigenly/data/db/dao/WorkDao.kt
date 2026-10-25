package br.meigenly.data.db.dao

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.Query
import androidx.room.Transaction
import br.meigenly.data.db.entity.WorkEntity
import br.meigenly.data.db.entity.WorkWithCharacters
import kotlinx.coroutines.flow.Flow

@Dao
interface WorkDao {

    @Query("SELECT * FROM works ORDER BY sort_order ASC")
    fun observeWorks(): Flow<List<WorkEntity>>

    @Transaction
    @Query("SELECT * FROM works WHERE id = :workId")
    fun observeWorkWithCharacters(workId: Long): Flow<WorkWithCharacters?>

    @Query("SELECT COUNT(id) FROM works WHERE slug = :slug")
    suspend fun countBySlug(slug: String): Int

    @Query("SELECT COUNT(id) FROM works")
    suspend fun countAll(): Int

    @Query("SELECT id FROM works WHERE slug = :slug")
    suspend fun idBySlug(slug: String): Long?

    @Query(
        """
        SELECT * FROM works
        WHERE lower(title) LIKE '%' || :query || '%'
           OR lower(title_original) LIKE '%' || :query || '%'
        ORDER BY sort_order ASC
        """
    )
    fun searchByTitle(query: String): Flow<List<WorkEntity>>

    /** Bulk loader used by the seed installer. */
    @Insert
    suspend fun insertAll(works: List<WorkEntity>): List<Long>

    @Query("DELETE FROM works")
    suspend fun deleteAll()
}
