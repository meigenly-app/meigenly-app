package br.meigenly.data.settings

import android.content.Context
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
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
        context.settingsDataStore.data.map { prefs -> prefs[KEY_DAILY_QUOTE] ?: false }

    suspend fun dailyQuoteEnabledOnce(): Boolean =
        context.settingsDataStore.data.first()[KEY_DAILY_QUOTE] ?: false

    suspend fun setDailyQuoteEnabled(enabled: Boolean) {
        context.settingsDataStore.edit { it[KEY_DAILY_QUOTE] = enabled }
    }

    private companion object {
        val KEY_THEME_MODE = stringPreferencesKey("theme_mode")
        val KEY_DAILY_QUOTE = booleanPreferencesKey("daily_quote_notification")
    }
}
