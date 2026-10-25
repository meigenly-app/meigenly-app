package br.meigenly.data.db.dao

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.Query
import androidx.room.RoomWarnings
import br.meigenly.data.db.entity.QuoteEntity
import br.meigenly.data.db.entity.QuoteFull
import kotlinx.coroutines.flow.Flow

@Dao
interface QuoteDao {

    @Query("SELECT * FROM quotes WHERE character_id = :characterId ORDER BY sort_order ASC")
    fun observeByCharacter(characterId: Long): Flow<List<QuoteEntity>>

    /** Full rows (quote + character + work) in reading order; feeds the swipe reader. */
    @Query(
        """
        SELECT q.*,
               c.name AS characterName,
               c.slug AS characterSlug,
               c.arc AS characterArc,
               w.title AS workTitle,
               w.slug AS workSlug,
               w.accent_color AS accent_color
        FROM quotes q
        JOIN characters c ON c.id = q.character_id
        JOIN works w ON w.id = c.work_id
        WHERE q.character_id = :characterId
        ORDER BY q.sort_order ASC
        """
    )
    @SuppressWarnings(RoomWarnings.CURSOR_MISMATCH) // viewed_at is history-only
    fun observeFullByCharacter(characterId: Long): Flow<List<QuoteFull>>

    /** Full-text search; :pattern is the sanitized, token-prefix form built by the repository. */
    @SuppressWarnings(RoomWarnings.CURSOR_MISMATCH) // viewed_at is history-only
    @Query(
        """
        SELECT q.*,
               c.name AS characterName,
               c.slug AS characterSlug,
               c.arc AS characterArc,
               w.title AS workTitle,
               w.slug AS workSlug,
               w.accent_color AS accent_color
        FROM quotes_fts f
        JOIN quotes q ON q.id = f.rowid
        JOIN characters c ON c.id = q.character_id
        JOIN works w ON w.id = c.work_id
        WHERE quotes_fts MATCH :pattern
        ORDER BY w.sort_order ASC, q.sort_order ASC
        LIMIT 30
        """
    )
    fun searchQuotes(pattern: String): Flow<List<QuoteFull>>

    @Query (
        """
        SELECT q.*,
               c.name AS characterName,
               c.slug AS characterSlug,
               c.arc AS characterArc,
               w.title AS workTitle,
               w.slug AS workSlug,
               w.accent_color AS accent_color
        FROM quotes q
        JOIN characters c ON c.id = q.character_id
        JOIN works w ON w.id = c.work_id
        WHERE q.id = :quoteId
        """
    )
    @SuppressWarnings(RoomWarnings.CURSOR_MISMATCH) // viewed_at is history-only
    fun observeQuoteFull(quoteId: Long): Flow<QuoteFull?>

    /** Deterministic daily pick (E8): single full row at :offset across the whole catalog. */
    @SuppressWarnings(RoomWarnings.CURSOR_MISMATCH) // viewed_at is history-only
    @Query(
        """
        SELECT q.*,
               c.name AS characterName,
               c.slug AS characterSlug,
               c.arc AS characterArc,
               w.title AS workTitle,
               w.slug AS workSlug,
               w.accent_color AS accent_color
        FROM quotes q
        JOIN characters c ON c.id = q.character_id
        JOIN works w ON w.id = c.work_id
        ORDER BY q.id ASC
        LIMIT 1 OFFSET :offset
        """
    )
    suspend fun quoteFullAtOffset(offset: Int): QuoteFull?

    @Query("SELECT COUNT(id) FROM quotes")
    suspend fun countAll(): Int

    @Query("SELECT id FROM quotes WHERE character_id = :characterId ORDER BY sort_order ASC")
    suspend fun idsByCharacter(characterId: Long): List<Long>

    @Query("SELECT id FROM quotes ORDER BY sort_order DESC, id DESC LIMIT 1")
    suspend fun lastQuoteId(): Long?

    @Insert
    suspend fun insertAll(quotes: List<QuoteEntity>): List<Long>

    @Query("DELETE FROM quotes")
    suspend fun deleteAll()
}
