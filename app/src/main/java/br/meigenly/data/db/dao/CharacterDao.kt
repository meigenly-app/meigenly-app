package br.meigenly.data.db.dao

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.Query
import androidx.room.Transaction
import br.meigenly.data.db.entity.CharacterEntity
import br.meigenly.data.db.entity.CharacterSearchRow
import br.meigenly.data.db.entity.CharacterWithCount
import br.meigenly.data.db.entity.CharacterWithQuotes
import kotlinx.coroutines.flow.Flow

@Dao
interface CharacterDao {

    /** Character list for a work, each row with its quote count (E2 list screen). */
    @Query(
        """
        SELECT c.*, COUNT(q.id) AS quote_count
        FROM characters c
        LEFT JOIN quotes q ON q.character_id = c.id
        WHERE c.work_id = :workId
        GROUP BY c.id
        ORDER BY c.sort_order ASC
        """
    )
    fun observeByWork(workId: Long): Flow<List<CharacterWithCount>>

    @Transaction
    @Query("SELECT * FROM characters WHERE id = :characterId")
    fun observeWithQuotes(characterId: Long): Flow<CharacterWithQuotes?>

    @Query("SELECT * FROM characters WHERE id = :characterId")
    suspend fun byId(characterId: Long): CharacterEntity?

    @Query("SELECT COUNT(id) FROM characters")
    suspend fun countAll(): Int

    @Query("SELECT id FROM characters WHERE work_id = :workId AND slug = :slug")
    suspend fun idBySlug(workId: Long, slug: String): Long?

    @Query(
        """
        SELECT c.*, w.slug AS work_slug
        FROM characters c
        JOIN works w ON w.id = c.work_id
        WHERE lower(c.name) LIKE '%' || :query || '%'
           OR lower(c.name_original) LIKE '%' || :query || '%'
            OR lower(c.arc) LIKE '%' || :query || '%'
        ORDER BY c.sort_order ASC
        LIMIT 20
        """
    )
    fun searchByName(query: String): Flow<List<CharacterSearchRow>>

    @Insert
    suspend fun insertAll(characters: List<CharacterEntity>): List<Long>

    @Query("DELETE FROM characters")
    suspend fun deleteAll()
}
