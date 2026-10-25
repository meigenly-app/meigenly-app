package br.meigenly.data.db

import android.content.Context
import androidx.room.Room
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import br.meigenly.data.db.dao.FavoriteDao
import br.meigenly.data.db.dao.HistoryDao
import br.meigenly.data.db.seed.SeedAssetReader
import br.meigenly.data.db.seed.SeedInstaller
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.test.runTest
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config

/**
 * Library (favorites + history) DAO flows, always on top of the seeded real asset.
 */
@RunWith(AndroidJUnit4::class)
@Config(sdk = [34], application = TestApplication::class)
class LibraryDaoTest {

    private lateinit var db: AppDatabase

    @Before
    fun setUp() = runTest {
        val context = ApplicationProvider.getApplicationContext<Context>()
        db = Room.inMemoryDatabaseBuilder(context, AppDatabase::class.java).build()
        SeedInstaller(db, SeedAssetReader(context)).installIfNeeded()
    }

    @After
    fun tearDown() {
        db.close()
    }

    @Test
    fun `toggle favorite inserts then removes`() = runTest {
        val firstQuote = db.quoteDao().idsByCharacter(
            db.characterDao().idBySlug(db.workDao().idBySlug("naruto")!!, "haku")!!,
        ).first()

        val favoriteDao: FavoriteDao = db.favoriteDao()

        assertFalse(favoriteDao.observeIsFavorite(firstQuote).first())
        favoriteDao.add(br.meigenly.data.db.entity.FavoriteEntity(quoteId = firstQuote))
        assertTrue(favoriteDao.observeIsFavorite(firstQuote).first())
        assertEquals(1, favoriteDao.countAll())

        favoriteDao.remove(firstQuote)
        assertFalse(favoriteDao.observeIsFavorite(firstQuote).first())
        assertEquals(0, favoriteDao.countAll())
    }

    @Test
    fun `history records and trim keeps the most recent rows`() = runTest {
        val quoteIds = db.quoteDao().idsByCharacter(
            db.characterDao().idBySlug(db.workDao().idBySlug("dragon-ball-z")!!, "vegeta")!!,
        )
        assertTrue(quoteIds.isNotEmpty())

        val historyDao: HistoryDao = db.historyDao()
        quoteIds.forEach { historyDao.add(br.meigenly.data.db.entity.HistoryEntity(quoteId = it)) }

        assertEquals(quoteIds.size, historyDao.countAll())

        // trim beyond the constant; small keep used to exercise the SQL
        historyDao.trim(keep = 2)
        assertEquals(2, historyDao.countAll())
    }

    @Test
    fun `favorites join returns QuoteFull with names`() = runTest {
        val luffyId = db.characterDao().idBySlug(db.workDao().idBySlug("one-piece")!!, "monkey-d-luffy")!!
        val firstQuote = db.quoteDao().idsByCharacter(luffyId).first()

        db.favoriteDao().add(br.meigenly.data.db.entity.FavoriteEntity(quoteId = firstQuote))
        val row = db.favoriteDao().observeFavorites().first().single()
        assertEquals("Monkey D. Luffy", row.characterName)
        assertEquals("One Piece", row.workTitle)
    }
}
