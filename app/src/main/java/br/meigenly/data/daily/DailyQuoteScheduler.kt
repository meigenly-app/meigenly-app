package br.meigenly.data.daily

import android.content.Context
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.PeriodicWorkRequest
import androidx.work.WorkManager
import java.time.Duration
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.LocalTime

/**
 * Schedules/cancels the daily quote worker. The task itself is deterministic,
 * so the policy UPDATE keeps re-enabling idempotent.
 */
object DailyQuoteScheduler {

    private const val WORK_NAME = "daily_quote"
    private val NOTIFICATION_TIME: LocalTime = LocalTime.of(9, 0)

    fun setEnabled(context: Context, enabled: Boolean) {
        val manager = WorkManager.getInstance(context)
        if (!enabled) {
            manager.cancelUniqueWork(WORK_NAME)
            return
        }
        val initialDelay = Duration.between(
            LocalDateTime.now(),
            nextRunAt(),
        ).coerceAtLeast(Duration.ofMinutes(1))

        val request = PeriodicWorkRequest.Builder(
            DailyQuoteWorker::class.java,
            Duration.ofHours(24),
        )
            .setInitialDelay(initialDelay)
            .build()

        manager.enqueueUniquePeriodicWork(
            WORK_NAME,
            ExistingPeriodicWorkPolicy.UPDATE,
            request,
        )
    }

    private fun nextRunAt(): LocalDateTime {
        val now = LocalDateTime.now()
        val todayRun = LocalDate.now().atTime(NOTIFICATION_TIME)
        return if (now.isBefore(todayRun)) todayRun else todayRun.plusDays(1)
    }
}
