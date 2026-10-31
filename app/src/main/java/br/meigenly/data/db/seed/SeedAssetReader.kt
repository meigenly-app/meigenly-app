package br.meigenly.data.db.seed

import android.content.Context
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.serialization.json.Json
import javax.inject.Inject
import javax.inject.Singleton

/** JSON config used for parsing the embedded seed. */
object SeedJson {
    val json: Json = Json {
        ignoreUnknownKeys = true // lets authoring-only fields stay in the file
        isLenient = true
    }
}

@Singleton
class SeedAssetReader @Inject constructor(
    @ApplicationContext private val context: Context,
) {
    fun read(): SeedFile =
        context.assets.open(SEED_ASSET_PATH).bufferedReader().use { reader ->
            SeedJson.json.decodeFromString<SeedFile>(reader.readText())
        }

    companion object {
        const val SEED_ASSET_PATH = "seed/app_data.json"
        const val SEED_VERSION = 6L
    }
}
