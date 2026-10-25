package br.meigenly.data.repository

import br.meigenly.data.db.dao.FavoriteDao
import br.meigenly.data.db.dao.HistoryDao
import br.meigenly.data.db.entity.FavoriteEntity
import br.meigenly.data.db.entity.HistoryEntity
import br.meigenly.data.db.entity.QuoteFull
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.first
import javax.inject.Inject
import javax.inject.Singleton

/**
 * User-owned data: favorites and reading history. Never touches content tables.
 */
@Singleton
class LibraryRepository @Inject constructor(
    private val favoriteDao: FavoriteDao,
    private val historyDao: HistoryDao,
) {

    fun observeFavorites(): Flow<List<QuoteFull>> = favoriteDao.observeFavorites()

    fun observeIsFavorite(quoteId: Long): Flow<Boolean> = favoriteDao.observeIsFavorite(quoteId)

    /** Returns the new state after toggling (true = now favorite). */
    suspend fun toggleFavorite(quoteId: Long): Boolean {
        val isFavorite = favoriteDao.observeIsFavorite(quoteId).first()
        if (isFavorite) {
            favoriteDao.remove(quoteId)
        } else {
            favoriteDao.add(FavoriteEntity(quoteId = quoteId))
        }
        return !isFavorite
    }

    /** Called when a page settles in the reader; keeps history bounded by [HistoryDao.HISTORY_LIMIT]. */
    suspend fun recordHistory(quoteId: Long) {
        historyDao.add(HistoryEntity(quoteId = quoteId))
        historyDao.trim(keep = HistoryDao.HISTORY_LIMIT)
    }

    fun observeHistory(limit: Int = HistoryDao.HISTORY_LIMIT): Flow<List<QuoteFull>> =
        historyDao.observeRecent(limit)

    suspend fun clearHistory() = historyDao.clear()
}
