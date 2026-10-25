package br.meigenly.data.db

import androidx.room.Database
import androidx.room.RoomDatabase
import br.meigenly.data.db.dao.CharacterDao
import br.meigenly.data.db.dao.FavoriteDao
import br.meigenly.data.db.dao.HistoryDao
import br.meigenly.data.db.dao.QuoteDao
import br.meigenly.data.db.dao.SeedStateDao
import br.meigenly.data.db.dao.WorkDao
import br.meigenly.data.db.entity.CharacterEntity
import br.meigenly.data.db.entity.FavoriteEntity
import br.meigenly.data.db.entity.HistoryEntity
import br.meigenly.data.db.entity.QuoteEntity
import br.meigenly.data.db.entity.QuoteFtsEntity
import br.meigenly.data.db.entity.SeedStateEntity
import br.meigenly.data.db.entity.WorkEntity

/**
 * Offline database for Meigenly.
 *
 * Schema notes:
 * - v1: content tables (works/characters/quotes) + user tables (favorites/history)
 *   + seed_state for seed versioning.
 * - v2: added quotes_fts full-text index (E5), done while no public build exists.
 * - v3: quotes gained text_norm; FTS re-indexed over normalized text (accent folding).
 * - exportSchema=false for the MVP; enable schema export when migration history matters (E9).
 */
@Database(
    entities = [
        WorkEntity::class,
        CharacterEntity::class,
        QuoteEntity::class,
        QuoteFtsEntity::class,
        FavoriteEntity::class,
        HistoryEntity::class,
        SeedStateEntity::class,
    ],
    version = 3,
    exportSchema = true,
)
abstract class AppDatabase : RoomDatabase() {
    abstract fun workDao(): WorkDao
    abstract fun characterDao(): CharacterDao
    abstract fun quoteDao(): QuoteDao
    abstract fun seedStateDao(): SeedStateDao
    abstract fun favoriteDao(): FavoriteDao
    abstract fun historyDao(): HistoryDao

    companion object {
        const val NAME = "meigenly.db"

        /** Sanity limit: a v1 database can't be migrated to v2 without the FTS rebuild scripts. */
        const val REQUIRED_VERSION = 2
    }
}
