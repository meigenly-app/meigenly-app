package br.meigenly.data.daily

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import br.meigenly.R
import br.meigenly.data.db.entity.QuoteFull

/**
 * Builds and posts the daily-quote notification (E8).
 * Separated from the Worker so tests / future UI can reuse the channel + build logic.
 */
object DailyQuoteNotifier {

    const val CHANNEL_ID = "daily_quote"
    private const val NOTIFICATION_ID = 42 // one daily notification; ids never collide

    fun ensureChannel(context: Context) {
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Frase do dia",
            NotificationManager.IMPORTANCE_DEFAULT,
        ).apply {
            description = "Notificação diária com uma frase do acervo"
        }
        manager.createNotificationChannel(channel)
    }

    fun hasPermission(context: Context): Boolean =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            ContextCompat.checkSelfPermission(
                context,
                Manifest.permission.POST_NOTIFICATIONS,
            ) == PackageManager.PERMISSION_GRANTED
        } else {
            true // pre-33: notification permission does not exist
        }

    fun build(context: Context, quote: QuoteFull): Notification {
        val deepLink = PendingIntent.getActivity(
            context,
            0,
            Intent(Intent.ACTION_VIEW, deepLinkUri(quote)).apply {
                setPackage(context.packageName)
            },
            PendingIntent.FLAG_IMMUTABLE,
        )
        return NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_launcher_foreground)
            .setContentTitle(quote.characterName)
            .setContentText("“${quote.quote.text}”")
            .setStyle(
                NotificationCompat.BigTextStyle()
                    .bigText("“${quote.quote.text}”\n— ${quote.workTitle}"),
            )
            .setContentIntent(deepLink)
            .setAutoCancel(true)
            .build()
    }

    fun post(context: Context, quote: QuoteFull) {
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.notify(NOTIFICATION_ID, build(context, quote))
    }

    /** Mirrors the READER nav route; MainActivity's NavHost consumes it as a deep link. */
    fun deepLinkUri(quote: QuoteFull): Uri =
        Uri.parse("meigenly://reader/${quote.quote.characterId}/${quote.quote.id}")
}
