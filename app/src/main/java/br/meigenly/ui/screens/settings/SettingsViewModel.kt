package br.meigenly.ui.screens.settings

import android.app.Application
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import br.meigenly.core.theme.ThemeMode
import br.meigenly.data.daily.DailyQuoteScheduler
import br.meigenly.data.settings.SettingsRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class SettingsViewModel @Inject constructor(
    private val settingsRepository: SettingsRepository,
    private val application: Application,
) : ViewModel() {

    val themeMode: StateFlow<ThemeMode> = settingsRepository.observeThemeMode()
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), ThemeMode.SYSTEM)

    val dailyQuoteEnabled: StateFlow<Boolean> = settingsRepository.observeDailyQuoteEnabled()
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), false)

    fun onThemeModeChange(mode: ThemeMode) {
        viewModelScope.launch { settingsRepository.setThemeMode(mode) }
    }

    /**
     * Called after the POST_NOTIFICATIONS runtime decision (granted=true) —
     * persists the toggle and syncs the WorkManager schedule.
     */
    fun onDailyQuotePermissionResult(isEnabledRequested: Boolean, granted: Boolean) {
        viewModelScope.launch {
            val enabled = isEnabledRequested && granted
            settingsRepository.setDailyQuoteEnabled(enabled)
            DailyQuoteScheduler.setEnabled(application, enabled)
        }
    }

    fun onDailyQuoteToggle(enabled: Boolean) {
        viewModelScope.launch {
            settingsRepository.setDailyQuoteEnabled(enabled)
            DailyQuoteScheduler.setEnabled(application, enabled)
        }
    }
}
