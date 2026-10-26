package br.meigenly.data.db.dao

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import androidx.room.RoomWarnings
import br.meigenly.data.db.entity.FavoriteEntity
import br.meigenly.data.db.entity.QuoteFull
import kotlinx.coroutines.flow.Flow

@Dao
interface FavoriteDao {

    @Query(
        """
        SELECT q.*,
               c.name AS characterName,
               c.slug AS characterSlug,
               c.arc AS characterArc,
               w.title AS workTitle,
               w.slug AS workSlug,
               w.accent_color AS accent_color
        FROM favorites f
        JOIN quotes q ON q.id = f.quote_id
        JOIN characters c ON c.id = q.character_id
        JOIN works w ON w.id = c.work_id
        ORDER BY f.created_at DESC
        """
    )
    @SuppressWarnings(RoomWarnings.CURSOR_MISMATCH) // viewed_at is history-only
    fun observeFavorites(): Flow<List<QuoteFull>>

    @Query("SELECT COUNT(f.quote_id) FROM favorites f WHERE f.quote_id = :quoteId")
    fun observeIsFavorite(quoteId: Long): Flow<Boolean>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun add(favorite: FavoriteEntity)

    @Query("DELETE FROM favorites WHERE quote_id = :quoteId")
    suspend fun remove(quoteId: Long)

    @Query("SELECT COUNT(quote_id) FROM favorites")
    suspend fun countAll(): Int

    /** Bulk loader used by the seed installer to preserve favorites across reseeds. */
    @Query("SELECT * FROM favorites")
    suspend fun captureAll(): List<FavoriteEntity>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun addAll(favorites: List<FavoriteEntity>)
}
