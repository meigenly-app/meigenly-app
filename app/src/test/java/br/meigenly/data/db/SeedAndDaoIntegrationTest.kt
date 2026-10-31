package br.meigenly.data.db

import androidx.room.Room
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import br.meigenly.data.db.entity.FavoriteEntity
import br.meigenly.data.db.entity.HistoryEntity
import br.meigenly.data.db.entity.SeedStateEntity
import br.meigenly.data.db.seed.SeedAssetReader
import br.meigenly.data.db.seed.SeedInstaller
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.test.runTest
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config

/**
 * Robolectric tests: real SQLite (in memory), real embedded seed asset, no emulator needed.
 */
@RunWith(AndroidJUnit4::class)
@Config(sdk = [34], application = TestApplication::class)
class SeedAndDaoIntegrationTest {

    private lateinit var db: AppDatabase

    @Before
    fun setUp() {
        db = Room.inMemoryDatabaseBuilder(
            ApplicationProvider.getApplicationContext(),
            AppDatabase::class.java,
        ).build()
    }

    @After
    fun tearDown() {
        db.close()
    }

    @Test
    fun `seed installer populates works, characters and quotes with sort order`() = runTest {
        SeedInstaller(db, SeedAssetReader(ApplicationProvider.getApplicationContext()))
            .installIfNeeded()

        val works = db.workDao().observeWorks().first()
        assertEquals(122, works.size)
        // sort_order follows the seed file order
        assertEquals("berserk", works.first().slug)
        assertEquals("sousou-no-frieren", works.last().slug)
        assertTrue(works.any { it.slug == "naruto" })
        assertEquals(541, db.characterDao().countAll())
        assertEquals(712, db.quoteDao().countAll())
    }

    @Test
    fun `installer is idempotent and does not duplicate content`() = runTest {
        val installer = SeedInstaller(db, SeedAssetReader(ApplicationProvider.getApplicationContext()))
        installer.installIfNeeded()
        installer.installIfNeeded()

        assertEquals(SeedAssetReader.SEED_VERSION, db.seedStateDao().installedVersion())
        assertEquals(122, db.workDao().countAll())
        assertEquals(712, db.quoteDao().countAll())
    }

    @Test
    fun `quote full join maps character and work names`() = runTest {
        SeedInstaller(db, SeedAssetReader(ApplicationProvider.getApplicationContext()))
            .installIfNeeded()

        val narutoWork = db.workDao().observeWorks().first().first { it.slug == "naruto" }
        val hakuId = db.characterDao().idBySlug(narutoWork.id, "haku")!!
        val quotes = db.quoteDao().observeByCharacter(hakuId).first()

        assertTrue(quotes.isNotEmpty())
        val full = db.quoteDao().observeQuoteFull(quotes.first().id).first()!!
        assertEquals("Haku", full.characterName)
        assertEquals("Naruto", full.workTitle)
        assertEquals("naruto", full.workSlug)
    }

    @Test
    fun `reseed reconciles favorites and history by normalized text`() = runTest {
        val installer = SeedInstaller(db, SeedAssetReader(ApplicationProvider.getApplicationContext()))
        installer.installIfNeeded()

        // User data on a quote that also exists in the new seed (Haku's famous line).
        val narutoWork = db.workDao().observeWorks().first().first { it.slug == "naruto" }
        val hakuId = db.characterDao().idBySlug(narutoWork.id, "haku")!!
        val hakuQuote = db.quoteDao().observeByCharacter(hakuId).first().first()
        db.favoriteDao().add(FavoriteEntity(quoteId = hakuQuote.id))
        db.historyDao().add(HistoryEntity(quoteId = hakuQuote.id))

        // Simulate an older installed seed to force the re-seed path.
        db.seedStateDao().upsert(SeedStateEntity(seedVersion = SeedAssetReader.SEED_VERSION - 1))
        installer.installIfNeeded()

        // Content reloaded, not duplicated.
        assertEquals(122, db.workDao().countAll())
        assertEquals(712, db.quoteDao().countAll())

        // Favorite and history survive on the new quote id (matched by normalized text).
        val favorites = db.favoriteDao().observeFavorites().first()
        assertEquals(1, favorites.size)
        assertEquals("Haku", favorites.first().characterName)
        assertEquals(1, db.historyDao().countAll())
    }
}
