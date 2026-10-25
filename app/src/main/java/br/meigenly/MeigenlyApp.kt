package br.meigenly

import android.app.Application
import androidx.hilt.work.HiltWorkerFactory
import androidx.work.Configuration
import br.meigenly.data.daily.DailyQuoteScheduler
import br.meigenly.data.db.seed.SeedInstaller
import br.meigenly.data.settings.SettingsRepository
import dagger.hilt.android.HiltAndroidApp
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.launch
import javax.inject.Inject

/**
 * Application entry point; Hilt DI root.
 * Also supplies the Hilt-aware WorkManager configuration for the E8 daily worker.
 */
@HiltAndroidApp
class MeigenlyApp : Application(), Configuration.Provider {

    @Inject lateinit var seedInstaller: SeedInstaller
    @Inject lateinit var settingsRepository: SettingsRepository
    @Inject lateinit var applicationScope: CoroutineScope
    @Inject lateinit var workerFactory: HiltWorkerFactory

    override val workManagerConfiguration: Configuration
        get() = Configuration.Builder()
            .setWorkerFactory(workerFactory)
            .build()

    override fun onCreate() {
        super.onCreate()
        // Small dataset; ~50ms on a real device. Installer itself is a no-op on 2nd launches.
        applicationScope.launch {
            seedInstaller.installIfNeeded()
        }
        // Re-sync the daily-quote schedule with the stored preference (E8);
        // WorkManager survives reboots, this just keeps toggle-off guaranteed.
        applicationScope.launch {
            DailyQuoteScheduler.setEnabled(this@MeigenlyApp, settingsRepository.dailyQuoteEnabledOnce())
        }
    }
}
