package br.meigenly.data.db.dao

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.Query
import br.meigenly.data.db.entity.HistoryEntity
import br.meigenly.data.db.entity.QuoteFull
import kotlinx.coroutines.flow.Flow

@Dao
interface HistoryDao {

    @Query(
        """
        SELECT q.*,
               h.viewed_at AS viewed_at,
               c.name AS characterName,
               c.slug AS characterSlug,
               c.arc AS characterArc,
               w.title AS workTitle,
               w.slug AS workSlug,
               w.accent_color AS accent_color
        FROM (SELECT * FROM history ORDER BY viewed_at DESC LIMIT :limit) h
        JOIN quotes q ON q.id = h.quote_id
        JOIN characters c ON c.id = q.character_id
        JOIN works w ON w.id = c.work_id
        ORDER BY h.viewed_at DESC
        """
    )
    fun observeRecent(limit: Int = HISTORY_LIMIT): Flow<List<QuoteFull>>

    @Query("SELECT viewed_at FROM history ORDER BY viewed_at DESC LIMIT 1")
    suspend fun mostRecentViewedAt(): Long?

    @Insert
    suspend fun add(entry: HistoryEntity)

    /** Keeps only the :keep most recent rows (deduplicates over time during reading). */
    @Query("DELETE FROM history WHERE id NOT IN (SELECT id FROM history ORDER BY viewed_at DESC LIMIT :keep)")
    suspend fun trim(keep: Int)

    @Query("DELETE FROM history")
    suspend fun clear()

    @Query("SELECT COUNT(id) FROM history")
    suspend fun countAll(): Int

    companion object {
        const val HISTORY_LIMIT = 200
    }
}
