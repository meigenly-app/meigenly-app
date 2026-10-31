package br.meigenly.data.db.seed

import androidx.room.withTransaction
import br.meigenly.core.util.TextNorm
import br.meigenly.data.db.AppDatabase
import br.meigenly.data.db.entity.CharacterEntity
import br.meigenly.data.db.entity.QuoteEntity
import br.meigenly.data.db.entity.SeedStateEntity
import br.meigenly.data.db.entity.WorkEntity
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Populates the database from the embedded asset.
 *
 * - First launch (installedVersion == null): plain install.
 * - Older installed version (< SEED_VERSION): re-seed. Content tables are wiped and
 *   reloaded, while user tables are preserved: favorites and history are captured
 *   BEFORE the wipe (their FK CASCADE would erase them) and re-mapped to the new
 *   quote ids by normalized quote text; entries whose text no longer exists are dropped.
 * - Same or newer installed version: no-op (also covers app downgrades).
 *
 * The FTS table is a contentEntity of quotes, so it follows the wipe/reload automatically.
 */
@Singleton
class SeedInstaller @Inject constructor(
    private val database: AppDatabase,
    private val assetReader: SeedAssetReader,
) {

    suspend fun installIfNeeded() {
        val installed = database.seedStateDao().installedVersion()
        if (installed != null && installed >= SeedAssetReader.SEED_VERSION) return

        val seed = assetReader.read()
        require(seed.schemaVersion <= SeedAssetReader.SEED_VERSION) {
            "Seed file schemaVersion ${seed.schemaVersion} is newer than the parser"
        }

        database.withTransaction {
            val isReseed = installed != null

            // Capture user data BEFORE the wipe: CASCADE on quotes would erase them.
            val oldNormByQuoteId = if (isReseed) {
                database.quoteDao().idTextNormPairs()
                    .associate { it.id to it.text_norm }
            } else {
                emptyMap()
            }
            val oldFavorites = if (isReseed) database.favoriteDao().captureAll() else emptyList()
            val oldHistory = if (isReseed) database.historyDao().captureAll() else emptyList()

            database.quoteDao().deleteAll()
            database.characterDao().deleteAll()
            database.workDao().deleteAll()

            val newIdByNorm = seedContent(seed)

            if (isReseed) {
                val newIdByOldQuoteId = HashMap<Long, Long>(oldNormByQuoteId.size)
                oldNormByQuoteId.forEach { (oldId, norm) ->
                    if (norm != null) {
                        newIdByNorm[norm]?.let { newIdByOldQuoteId[oldId] = it }
                    }
                }

                val favorites = oldFavorites.mapNotNull { favorite ->
                    newIdByOldQuoteId[favorite.quoteId]?.let {
                        br.meigenly.data.db.entity.FavoriteEntity(quoteId = it, createdAt = favorite.createdAt)
                    }
                }
                val history = oldHistory.mapNotNull { entry ->
                    newIdByOldQuoteId[entry.quoteId]?.let {
                        br.meigenly.data.db.entity.HistoryEntity(quoteId = it, viewedAt = entry.viewedAt)
                    }
                }
                database.favoriteDao().addAll(favorites)
                database.historyDao().addAll(history)
            }

            database.seedStateDao().upsert(
                SeedStateEntity(seedVersion = SeedAssetReader.SEED_VERSION),
            )
        }
    }

    /** Inserts all seed content and returns new quote ids keyed by normalized text. */
    private suspend fun seedContent(seed: SeedFile): Map<String, Long> {
        val newIdByNorm = HashMap<String, Long>()
        seed.works.forEachIndexed { workIndex, seedWork ->
            val workId = database.workDao().insertAll(
                listOf(
                    WorkEntity(
                        slug = seedWork.slug,
                        title = seedWork.title,
                        titleOriginal = seedWork.titleOriginal,
                        year = seedWork.year,
                        description = seedWork.description,
                        accentColor = seedWork.accentColor,
                        sortOrder = workIndex,
                    ),
                ),
            ).first()

            seedWork.characters.forEachIndexed { charIndex, seedCharacter ->
                val characterId = database.characterDao().insertAll(
                    listOf(
                        CharacterEntity(
                            workId = workId,
                            slug = seedCharacter.slug,
                            name = seedCharacter.name,
                            nameOriginal = seedCharacter.nameOriginal,
                            arc = seedCharacter.arc,
                            description = seedCharacter.description,
                            firstChapter = seedCharacter.firstChapter,
                            firstEpisode = seedCharacter.firstEpisode,
                            firstEpisodeSeason = seedCharacter.firstEpisodeSeason,
                            sortOrder = charIndex,
                        ),
                    ),
                ).first()

                val entities = seedCharacter.quotes.mapIndexed { quoteIndex, quote ->
                    QuoteEntity(
                        characterId = characterId,
                        text = quote.text,
                        textNorm = TextNorm.normalize(quote.text),
                        textOriginal = quote.textOriginal,
                        textJapanese = quote.textJapanese,
                        textOriginalNorm = quote.textOriginal?.let { TextNorm.normalize(it) },
                        episode = quote.episode,
                        context = quote.context,
                        sortOrder = quoteIndex,
                    )
                }
                val ids = database.quoteDao().insertAll(entities)
                entities.zip(ids) { entity, id ->
                    val norm = entity.textNorm
                    if (norm != null) newIdByNorm.putIfAbsent(norm, id)
                }
            }
        }
        return newIdByNorm
    }
}
