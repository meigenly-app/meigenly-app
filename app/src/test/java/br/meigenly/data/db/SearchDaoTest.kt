package br.meigenly.data.db

import android.content.Context
import androidx.room.Room
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import br.meigenly.data.db.seed.SeedAssetReader
import br.meigenly.data.db.seed.SeedInstaller
import br.meigenly.data.repository.ContentRepository
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
 * FTS + LIKE search flows against the seeded real asset.
 */
@RunWith(AndroidJUnit4::class)
@Config(sdk = [34], application = TestApplication::class)
class SearchDaoTest {

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
    fun `fts search matches quote text token prefix`() = runTest {
        val results = db.quoteDao().searchQuotes("rei*").first()
        assertTrue(results.isNotEmpty())
        assertTrue(results.all { it.quote.text.lowercase().contains("rei") || it.quote.textOriginal?.lowercase()?.contains("rei") == true })
    }

    @Test
    fun `fts search folds diacritics both ways`() = runTest {
        val repo = ContentRepository(db.workDao(), db.characterDao(), db.quoteDao())
        // accent-less query must find accented text ("não" -> norm "nao")...
        val plain = repo.searchQuotes("nao").first()
        assertTrue(plain.isNotEmpty())
        // ...and an accented query must land on the same normalized tokens
        val accented = repo.searchQuotes("não").first()
        assertEquals(plain.size, accented.size)
    }

    @Test
    fun `character name search is case insensitive`() = runTest {
        val results = db.characterDao().searchByName("vegeta").first()
        // Vegeta exists in Dragon Ball Z and Dragon Ball GT (variant "Majin Vegeta" merged into DBZ's).
        assertEquals(2, results.size)
        assertTrue(results.all { it.name == "Vegeta" })
    }

    @Test
    fun `work title search finds by partial title`() = runTest {
        val results = db.workDao().searchByTitle("one").first()
        assertTrue(results.any { it.slug == "one-piece" })
    }

    @Test
    fun `daily quote offset returns a valid full row`() = runTest {
        val repo = ContentRepository(db.workDao(), db.characterDao(), db.quoteDao())
        val today = repo.todayQuote()
        assertEquals(true, today != null)
        // The deterministic count must match the whole 292-quote catalog
        assertEquals(292, db.quoteDao().countAll())
        // Two calls on the same day must pick the same quote
        assertEquals(today?.quote?.id, repo.todayQuote()?.quote?.id)
    }
}
