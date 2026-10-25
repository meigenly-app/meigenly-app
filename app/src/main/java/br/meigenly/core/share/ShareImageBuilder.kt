package br.meigenly.core.share

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.Shader
import android.graphics.Typeface
import android.text.Layout
import android.text.StaticLayout
import android.text.TextPaint
import br.meigenly.data.db.entity.QuoteFull

/**
 * Renders the share-image card with Canvas + StaticLayout (deterministic, no Compose capture).
 * No third-party imagery: brand wordmark plus the work accent used as gradient anchor.
 */
object ShareImageBuilder {

    private const val WIDTH = 1080
    private const val HEIGHT = 1350

    fun createBitmap(item: QuoteFull, accentHex: String?): Bitmap {
        val accent = parseAccent(accentHex)
        val bitmap = Bitmap.createBitmap(WIDTH, HEIGHT, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)

        // Background: dark tinted gradient anchored on the work accent
        val gradient = LinearGradient(
            0f, 0f, 0f, HEIGHT.toFloat(),
            scale(accent, 0.18f),
            scale(accent, 0.55f),
            Shader.TileMode.CLAMP,
        )
        canvas.drawRect(0f, 0f, WIDTH.toFloat(), HEIGHT.toFloat(), Paint().apply { shader = gradient })

        // Brand touchpoint: accent bar + wordmark
        canvas.drawRect(72f, 96f, 72f + 96f, 112f, Paint().apply { color = accent })
        canvas.drawText(
            "Meigenly", 72f, 96f + 58f,
            TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
                color = 0xAAFFFFFF.toInt()
                textSize = 34f
                typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
            },
        )

        // Quote, centered and auto-wrapped
        val textPaint = TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
            color = 0xFFFFFFFF.toInt()
            textSize = 62f
            typeface = Typeface.create(Typeface.SERIF, Typeface.BOLD)
        }
        val quote = "\u201C${item.quote.text}\u201D"
        val quoteLayout = StaticLayout.Builder
            .obtain(quote, 0, quote.length, textPaint, WIDTH - 144)
            .setAlignment(Layout.Alignment.ALIGN_CENTER)
            .setLineSpacing(16f, 1f)
            .build()
        canvas.save()
        canvas.translate(72f, (HEIGHT - quoteLayout.height) / 2f + 40f)
        quoteLayout.draw(canvas)
        canvas.restore()

        // Attribution pinned near the bottom
        val attribution = buildList {
            add(item.characterName)
            add(item.workTitle)
            item.quote.episode?.takeIf { it.isNotBlank() }?.let { add(it) }
        }.joinToString("  ·  ")
        canvas.drawText(
            "\u2014 $attribution",
            72f, HEIGHT - 96f,
            TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
                color = 0xB3FFFFFF.toInt()
                textSize = 38f
            },
        )

        return bitmap
    }

    private fun parseAccent(hex: String?): Int {
        val clean = hex?.removePrefix("#") ?: return 0xFFB34700.toInt()
        if (clean.length != 6) return 0xFFB34700.toInt()
        return runCatching { clean.toLong(16).toInt() or 0xFF000000.toInt() }
            .getOrDefault(0xFFB34700.toInt())
    }

    /** Scales an ARGB color towards black by [factor] (0f = black-ish, 1f = original). */
    private fun scale(argb: Int, factor: Float): Int {
        val r = ((argb shr 16 and 0xFF) * factor).toInt()
        val g = ((argb shr 8 and 0xFF) * factor).toInt()
        val b = ((argb and 0xFF) * factor).toInt()
        return 0xFF shl 24 or (r shl 16) or (g shl 8) or b
    }
}
