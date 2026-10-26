package br.meigenly.core.share

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.RectF
import android.graphics.Shader
import android.graphics.Typeface
import android.text.Layout
import android.text.StaticLayout
import android.text.TextPaint
import br.meigenly.data.db.entity.QuoteFull

/**
 * Renders the share-image card with Canvas + StaticLayout (deterministic, no Compose capture).
 * Brand-first design: deep navy canvas with a subtle seigaiha (Japanese wave) pattern,
 * a vertical [mei-gen] motif and a vermilion hanko seal. Light Japanese theming only —
 * no third-party imagery. The work accent survives as a thin attribution marker.
 */
object ShareImageBuilder {

    private const val WIDTH = 1080
    private const val HEIGHT = 1350

    // Brand identity (launcher icon): navy ink + balloon blue.
    private const val NAVY = 0xFF111822.toInt()
    private const val NAVY_LIFT = 0xFF1A2433.toInt()
    private const val BALLOON_BLUE = 0xFF4DB9F9.toInt()
    private const val HANKO_RED = 0xFFC73E3A.toInt()

    fun createBitmap(item: QuoteFull, accentHex: String?): Bitmap {
        val accent = parseAccent(accentHex)
        val bitmap = Bitmap.createBitmap(WIDTH, HEIGHT, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        val w = WIDTH.toFloat()
        val h = HEIGHT.toFloat()

        drawSeigaihaBackground(canvas, w, h)
        drawVerticalMotif(canvas)
        drawBrandMark(canvas)

        // Quote, centered and auto-wrapped
        val textPaint = TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
            color = 0xFFFFFFFF.toInt()
            textSize = 62f
            typeface = Typeface.create(Typeface.SERIF, Typeface.BOLD)
        }
        val quote = "\u201C${item.quote.text}\u201D"
        val quoteLayout = StaticLayout.Builder
            .obtain(quote, 0, quote.length, textPaint, WIDTH - 200)
            .setAlignment(Layout.Alignment.ALIGN_CENTER)
            .setLineSpacing(16f, 1f)
            .build()
        canvas.save()
        canvas.translate(100f, (HEIGHT - quoteLayout.height) / 2f + 20f)
        quoteLayout.draw(canvas)
        canvas.restore()

        drawAttribution(canvas, item, accent)
        drawHanko(canvas)

        return bitmap
    }

    /**
     * Solid navy canvas with a subtle seigaiha pattern (staggered rows of concentric
     * circle arcs, each filled circle covering the row above — classic fish-scale waves)
     * and a soft darkening towards the bottom for text legibility.
     */
    private fun drawSeigaihaBackground(canvas: Canvas, w: Float, h: Float) {
        canvas.drawRect(0f, 0f, w, h, Paint().apply { color = NAVY })

        val radius = 120f
        val stroke = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeWidth = 3f
            color = 0x12FFFFFF.toInt() // ~7% white: present, never loud
        }
        val fill = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = NAVY }

        val rowStep = radius * 0.92f
        val colStep = radius * 2f
        var row = 0
        var y = -radius
        while (y < h + radius) {
            val offsetX = if (row % 2 == 0) 0f else radius
            var x = -radius * 2f + offsetX
            while (x < w + radius * 2f) {
                canvas.drawCircle(x, y, radius, fill)
                // nested arcs, outermost first
                var r = radius
                while (r > radius * 0.2f) {
                    canvas.drawCircle(x, y, r, stroke)
                    r -= radius * 0.22f
                }
                x += colStep
            }
            y += rowStep
            row++
        }

        // Gentle vignette: darker towards the bottom where attribution sits.
        val shade = LinearGradient(
            0f, 0f, 0f, h,
            intArrayOf(0x00000000, 0x2E000000),
            floatArrayOf(0.55f, 1f),
            Shader.TileMode.CLAMP,
        )
        canvas.drawRect(0f, 0f, w, h, Paint().apply { shader = shade })
    }

    /** Vertical [mei-gen] (famous saying) running down the right edge, whisper-quiet. */
    private fun drawVerticalMotif(canvas: Canvas) {
        val paint = TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
            color = 0x33FFFFFF.toInt()
            textSize = 88f
            typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
            textAlign = Paint.Align.CENTER
        }
        val chars = charArrayOf('名', '言')
        val x = WIDTH - 92f
        var y = 210f
        for (c in chars) {
            canvas.drawText(c.toString(), x, y, paint)
            y += paint.textSize * 1.18f
        }
    }

    /** Brand touchpoint: balloon-blue bar + wordmark, top-left. */
    private fun drawBrandMark(canvas: Canvas) {
        val bar = Paint().apply { color = BALLOON_BLUE }
        canvas.drawRoundRect(RectF(72f, 84f, 84f, 156f), 6f, 6f, bar)
        canvas.drawText(
            "Meigenly", 108f, 140f,
            TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
                color = 0xFFFFFFFF.toInt()
                textSize = 40f
                typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
            },
        )
    }

    /** Attribution pinned near the bottom, with the work accent as a thin marker. */
    private fun drawAttribution(canvas: Canvas, item: QuoteFull, accent: Int) {
        val attribution = buildList {
            add(item.characterName)
            add(item.workTitle)
            item.quote.episode?.takeIf { it.isNotBlank() }?.let { add(it) }
        }.joinToString("  ·  ")

        val textPaint = TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
            color = 0xD9FFFFFF.toInt()
            textSize = 38f
        }
        val textX = 132f
        val baseline = HEIGHT - 108f
        canvas.drawText("\u2014 $attribution", textX, baseline, textPaint)

        // Work accent marker, left of the attribution line.
        val marker = Paint().apply { color = accent }
        canvas.drawRoundRect(RectF(72f, baseline - 34f, 84f, baseline + 12f), 6f, 6f, marker)
    }

    /** Vermilion hanko seal with [mei], bottom-right above the attribution line. */
    private fun drawHanko(canvas: Canvas) {
        val size = 92f
        val right = WIDTH - 88f
        val bottom = HEIGHT - 196f
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = HANKO_RED }
        canvas.drawRoundRect(RectF(right - size, bottom - size, right, bottom), 14f, 14f, paint)

        val kanji = TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
            color = 0xFFFFFFFF.toInt()
            textSize = 56f
            typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
            textAlign = Paint.Align.CENTER
        }
        val cx = right - size / 2f
        val cy = bottom - size / 2f
        val baseline = cy - (kanji.fontMetrics.ascent + kanji.fontMetrics.descent) / 2f
        canvas.drawText("名", cx, baseline, kanji)
    }

    private fun parseAccent(hex: String?): Int {
        val clean = hex?.removePrefix("#") ?: return BALLOON_BLUE
        if (clean.length != 6) return BALLOON_BLUE
        return runCatching { clean.toLong(16).toInt() or 0xFF000000.toInt() }
            .getOrDefault(BALLOON_BLUE)
    }
}
