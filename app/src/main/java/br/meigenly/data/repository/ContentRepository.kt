package br.meigenly.data.repository

import br.meigenly.core.daily.DailyQuotePicker
import br.meigenly.data.db.dao.CharacterDao
import br.meigenly.data.db.dao.QuoteDao
import br.meigenly.data.db.dao.WorkDao
import br.meigenly.data.db.entity.CharacterEntity
import br.meigenly.data.db.entity.QuoteEntity
import br.meigenly.data.db.entity.QuoteFull
import br.meigenly.data.db.entity.WorkEntity
import br.meigenly.core.util.TextNorm
import br.meigenly.data.db.seed.SeedAssetReader
import br.meigenly.domain.model.Character
import br.meigenly.domain.model.Quote
import br.meigenly.domain.model.Work
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import java.time.LocalDate
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Read-only content repository. DAOs stay hidden behind this seam.
 */
@Singleton
class ContentRepository @Inject constructor(
    private val workDao: WorkDao,
    private val characterDao: CharacterDao,
    private val quoteDao: QuoteDao,
) {

    fun observeWorks(): Flow<List<Work>> =
        workDao.observeWorks().map { works ->
            works.map { entity -> entity.toModel() }
        }

    fun observeWork(workId: Long): Flow<Work?> =
        workDao.observeWorkWithCharacters(workId).map { relation ->
            relation?.work?.toModel()
        }

    fun observeCharacters(workId: Long): Flow<List<Character>> =
        characterDao.observeByWork(workId).map { rows ->
            rows.map { row -> row.character.toModel(quoteCount = row.quoteCount) }
        }

    fun observeCharacter(characterId: Long): Flow<Character?> =
        characterDao.observeWithQuotes(characterId).map { relation ->
            relation?.character?.toModel(
                // count is not used on this screen; join keeps the repository contract simple
                quoteCount = relation.quotes.size,
            )
        }

    fun observeQuotes(characterId: Long): Flow<List<Quote>> =
        quoteDao.observeByCharacter(characterId).map { quotes ->
            quotes.map { entity -> entity.toModel() }
        }

    fun observeQuotesFull(characterId: Long): Flow<List<QuoteFull>> =
        quoteDao.observeFullByCharacter(characterId)

    // ---- Search (E5) ----

    /**
     * Builds the FTS pattern: letters/digits only per token, prefix-matched.
     * Sanitization keeps user punctuation (quotes, apostrophes) from breaking MATCH syntax.
     */
    fun ftsPatternFor(query: String): String =
        TextNorm.normalize(query)
            .split(WHITESPACE)
            .filter { token -> token.isNotBlank() }
            .map { token -> token.filter { char -> char.isLetterOrDigit() } + "*" }
            .filter { it.length > 1 } // refuse single-char prefix storms
            .joinToString(" ")

    fun searchQuotes(query: String): Flow<List<QuoteFull>> {
        val pattern = ftsPatternFor(query)
        return if (pattern.isBlank()) {
            kotlinx.coroutines.flow.flowOf(emptyList())
        } else {
            quoteDao.searchQuotes(pattern)
        }
    }

    fun searchCharacters(query: String): Flow<List<Character>> =
        characterDao.searchByName(query.lowercase()).map { rows ->
            rows.map { row -> row.character.toModel(quoteCount = 0, workSlug = row.workSlug) }
        }

    fun searchWorks(query: String): Flow<List<Work>> =
        workDao.searchByTitle(query.lowercase()).map { works ->
            works.map { entity -> entity.toModel() }
        }

    // ---- Daily quote (E8) ----

    /**
     * Today's deterministic pick across the whole catalog.
     * Seed = ISO date + version suffix so a future content update can re-shuffle the calendar.
     */
    suspend fun todayQuote(): QuoteFull? {
        val count = quoteDao.countAll()
        if (count == 0) return null
        val seed = "${LocalDate.now()}-v${SeedAssetReader.SEED_VERSION}"
        return quoteDao.quoteFullAtOffset(DailyQuotePicker.pickOffset(count, seed))
    }

    private companion object {
        val WHITESPACE = "\\s+".toRegex()
    }
}

private fun WorkEntity.toModel(): Work = Work(
    id = id,
    slug = slug,
    title = title,
    titleOriginal = titleOriginal,
    year = year,
    description = description,
    accentColor = accentColor,
)

private fun CharacterEntity.toModel(quoteCount: Int, workSlug: String? = null): Character = Character(
    id = id,
    workId = workId,
    slug = slug,
    name = name,
    nameOriginal = nameOriginal,
    arc = arc,
    description = description,
    firstChapter = firstChapter,
    firstEpisode = firstEpisode,
    firstEpisodeSeason = firstEpisodeSeason,
    quoteCount = quoteCount,
    workSlug = workSlug,
)

private fun QuoteEntity.toModel(): Quote = Quote(
    id = id,
    characterId = characterId,
    text = text,
    textOriginal = textOriginal,
    textJapanese = textJapanese,
    episode = episode,
    context = context,
)
