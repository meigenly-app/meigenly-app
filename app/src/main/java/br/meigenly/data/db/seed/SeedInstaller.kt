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
 * Populates the database from the embedded asset on first launch only
 * (installedVersion == null).
 *
 * Future seed content updates (E9+) must NOT wipe user tables: favorites and history
 * must be preserved via slug-based reconciliation (old quote id -> new quote id matched
 * by work.slug + character.slug + quote.text). Skipping any delete cascade is exactly
 * why this installer never deletes rows wholesale.
 */
@Singleton
class SeedInstaller @Inject constructor(
    private val database: AppDatabase,
    private val assetReader: SeedAssetReader,
) {

    suspend fun installIfNeeded() {
        if (database.seedStateDao().installedVersion() != null) return

        val seed = assetReader.read()
        require(seed.schemaVersion <= SeedAssetReader.SEED_VERSION) {
            "Seed file schemaVersion ${seed.schemaVersion} is newer than the parser"
        }

        database.withTransaction {
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
                                sortOrder = charIndex,
                            ),
                        ),
                    ).first()

                    database.quoteDao().insertAll(
                        seedCharacter.quotes.mapIndexed { quoteIndex, quote ->
                            QuoteEntity(
                                characterId = characterId,
                                text = quote.text,
                                textNorm = TextNorm.normalize(quote.text),
                                textOriginal = quote.textOriginal,
                                textOriginalNorm = quote.textOriginal?.let { TextNorm.normalize(it) },
                                episode = quote.episode,
                                context = quote.context,
                                sortOrder = quoteIndex,
                            )
                        },
                    )
                }
            }

            database.seedStateDao().upsert(
                SeedStateEntity(seedVersion = SeedAssetReader.SEED_VERSION),
            )
        }
    }
}
