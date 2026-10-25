package br.meigenly.data.daily

import android.content.Context
import androidx.hilt.work.HiltWorker
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import br.meigenly.data.repository.ContentRepository
import br.meigenly.data.settings.SettingsRepository
import dagger.assisted.Assisted
import dagger.assisted.AssistedInject

/**
 * Daily task (E8): picks today's deterministic quote and posts it,
 * only if the user's toggle is on AND the notification permission is granted.
 */
@HiltWorker
class DailyQuoteWorker @AssistedInject constructor(
    @Assisted context: Context,
    @Assisted params: WorkerParameters,
    private val contentRepository: ContentRepository,
    private val settingsRepository: SettingsRepository,
) : CoroutineWorker(context, params) {

    override suspend fun doWork(): Result {
        if (!settingsRepository.dailyQuoteEnabledOnce()) return Result.success()
        val quote = contentRepository.todayQuote() ?: return Result.retry()
        if (DailyQuoteNotifier.hasPermission(applicationContext)) {
            DailyQuoteNotifier.post(applicationContext, quote)
        }
        return Result.success()
    }
}
