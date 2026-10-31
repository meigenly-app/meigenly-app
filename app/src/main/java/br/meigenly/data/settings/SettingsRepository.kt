package br.meigenly.data.settings

import android.content.Context
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.intPreferencesKey
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import br.meigenly.core.share.ShareTheme
import br.meigenly.core.theme.ThemeMode
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map
import javax.inject.Inject
import javax.inject.Singleton

private val Context.settingsDataStore by preferencesDataStore(name = "settings")

/**
 * User preferences persisted locally (theme mode today; notification toggle at E8).
 */
@Singleton
class SettingsRepository @Inject constructor(
    @ApplicationContext private val context: Context,
) {

    fun observeThemeMode(): Flow<ThemeMode> =
        context.settingsDataStore.data.map { prefs ->
            runCatching { ThemeMode.valueOf(prefs[KEY_THEME_MODE] ?: ThemeMode.SYSTEM.name) }
                .getOrDefault(ThemeMode.SYSTEM)
        }

    suspend fun setThemeMode(mode: ThemeMode) {
        context.settingsDataStore.edit { it[KEY_THEME_MODE] = mode.name }
    }

    suspend fun themeModeOnce(): ThemeMode =
        context.settingsDataStore.data.first().let { prefs ->
            runCatching { ThemeMode.valueOf(prefs[KEY_THEME_MODE] ?: ThemeMode.SYSTEM.name) }
                .getOrDefault(ThemeMode.SYSTEM)
        }

    // ---- Daily-quote notification (E8) ----

    fun observeDailyQuoteEnabled(): Flow<Boolean> =
        context.settingsDataStore.data.map { prefs -> prefs[KEY_DAILY_QUOTE] ?: true }

    suspend fun dailyQuoteEnabledOnce(): Boolean =
        context.settingsDataStore.data.first()[KEY_DAILY_QUOTE] ?: true

    suspend fun setDailyQuoteEnabled(enabled: Boolean) {
        context.settingsDataStore.edit { it[KEY_DAILY_QUOTE] = enabled }
    }

    // ---- Share image style ----

    fun observeShareTheme(): Flow<ShareTheme> =
        context.settingsDataStore.data.map { prefs ->
            runCatching { ShareTheme.valueOf(prefs[KEY_SHARE_THEME] ?: ShareTheme.INK.name) }
                .getOrDefault(ShareTheme.INK)
        }

    suspend fun shareThemeOnce(): ShareTheme =
        context.settingsDataStore.data.first().let { prefs ->
            runCatching { ShareTheme.valueOf(prefs[KEY_SHARE_THEME] ?: ShareTheme.INK.name) }
                .getOrDefault(ShareTheme.INK)
        }

    suspend fun setShareTheme(theme: ShareTheme) {
        context.settingsDataStore.edit { it[KEY_SHARE_THEME] = theme.name }
    }

    fun observeShareColor(): Flow<Int?> =
        context.settingsDataStore.data.map { prefs -> prefs[KEY_SHARE_COLOR] }

    suspend fun shareColorOnce(): Int? =
        context.settingsDataStore.data.first()[KEY_SHARE_COLOR]

    /** Null resets to the theme's own background. */
    suspend fun setShareColor(argb: Int?) {
        context.settingsDataStore.edit { prefs ->
            if (argb == null) {
                prefs.remove(KEY_SHARE_COLOR)
            } else {
                prefs[KEY_SHARE_COLOR] = argb
            }
        }
    }

    // ---- Search history (recent queries, most recent first) ----

    fun observeSearchHistory(): Flow<List<String>> =
        context.settingsDataStore.data.map { prefs -> decodeHistory(prefs[KEY_SEARCH_HISTORY]) }

    /** Registers a stabilized query; blanks are ignored, dedupe keeps the newest at top. */
    suspend fun addSearchQuery(query: String) {
        val q = query.trim()
        if (q.isEmpty()) return
        context.settingsDataStore.edit { prefs ->
            val list = decodeHistory(prefs[KEY_SEARCH_HISTORY]).toMutableList()
            list.removeAll { it.equals(q, ignoreCase = true) }
            list.add(0, q)
            if (list.size > MAX_SEARCH_HISTORY) list.subList(MAX_SEARCH_HISTORY, list.size).clear()
            prefs[KEY_SEARCH_HISTORY] = list.joinToString(SEARCH_HISTORY_SEPARATOR)
        }
    }

    /** Removes a single history entry (the X on each row). */
    suspend fun removeSearchQuery(query: String) {
        context.settingsDataStore.edit { prefs ->
            val list = decodeHistory(prefs[KEY_SEARCH_HISTORY]).filter { it != query }
            if (list.isEmpty()) {
                prefs.remove(KEY_SEARCH_HISTORY)
            } else {
                prefs[KEY_SEARCH_HISTORY] = list.joinToString(SEARCH_HISTORY_SEPARATOR)
            }
        }
    }

    private fun decodeHistory(raw: String?): List<String> =
        raw?.split(SEARCH_HISTORY_SEPARATOR)?.filter { it.isNotBlank() } ?: emptyList()

    private companion object {
        val KEY_THEME_MODE = stringPreferencesKey("theme_mode")
        val KEY_DAILY_QUOTE = booleanPreferencesKey("daily_quote_notification")
        val KEY_SHARE_THEME = stringPreferencesKey("share_theme")
        val KEY_SHARE_COLOR = intPreferencesKey("share_custom_color")
        val KEY_SEARCH_HISTORY = stringPreferencesKey("search_history")
        const val SEARCH_HISTORY_SEPARATOR = "\u001F"
        const val MAX_SEARCH_HISTORY = 10
    }
}
