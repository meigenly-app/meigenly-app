package br.meigenly.data.db

import androidx.room.Room
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
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
        assertEquals(3, works.size)
        // sort_order follows the seed file order
        assertEquals(listOf("naruto", "dragon-ball-z", "one-piece"), works.map { it.slug })
        assertEquals(10, db.characterDao().countAll())
        assertEquals(16, db.quoteDao().countAll())
    }

    @Test
    fun `installer is idempotent and does not duplicate content`() = runTest {
        val installer = SeedInstaller(db, SeedAssetReader(ApplicationProvider.getApplicationContext()))
        installer.installIfNeeded()
        installer.installIfNeeded()

        assertEquals(1L, db.seedStateDao().installedVersion())
        assertEquals(3, db.workDao().countAll())
        assertEquals(16, db.quoteDao().countAll())
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
}
