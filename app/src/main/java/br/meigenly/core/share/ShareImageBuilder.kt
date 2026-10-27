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
 * Japanese theming only - no third-party imagery. The seigaiha (wave) pattern, the vertical
 * [mei-gen] motif and the vermilion hanko seal survive any [ShareTheme]; ink colors adapt to
 * the chosen background (preset or user-picked [custom color][createBitmap]).
 */
object ShareImageBuilder {

    private const val WIDTH = 1080
    private const val HEIGHT = 1350

    // Brand identity (launcher icon).
    private const val BALLOON_BLUE = 0xFF4DB9F9.toInt()
    private const val HANKO_RED = 0xFFC73E3A.toInt()

    fun createBitmap(
        item: QuoteFull,
        accentHex: String?,
        theme: ShareTheme = ShareTheme.INK,
        customColor: Int? = null,
    ): Bitmap {
        val accent = parseAccent(accentHex)
        val bitmap = Bitmap.createBitmap(WIDTH, HEIGHT, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        val w = WIDTH.toFloat()
        val h = HEIGHT.toFloat()

        val palette = Palette(
            bg = customColor ?: theme.bg.toInt(),
            ink = if (customColor != null) inkFor(customColor) else theme.onBg.toInt(),
        )

        drawSeigaihaBackground(canvas, w, h, palette)
        drawVerticalMotif(canvas, palette)
        drawBrandMark(canvas, palette)

        // Quote + japanese source, centered and auto-wrapped
        val quotePaint = TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
            color = palette.primaryInk
            textSize = 62f
            typeface = Typeface.create(Typeface.SERIF, Typeface.BOLD)
        }
        val quote = "\u201C${item.quote.text}\u201D"
        val quoteLayout = StaticLayout.Builder
            .obtain(quote, 0, quote.length, quotePaint, WIDTH - 200)
            .setAlignment(Layout.Alignment.ALIGN_CENTER)
            .setLineSpacing(16f, 1f)
            .build()

        val japanese = item.quote.textJapanese?.takeIf { it.isNotBlank() }
        val japaneseLayout = japanese?.let { jp ->
            StaticLayout.Builder
                .obtain(jp, 0, jp.length, TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
                    color = palette.ink
                    textSize = 46f
                    typeface = Typeface.create(Typeface.SERIF, Typeface.NORMAL)
                }, WIDTH - 260)
                .setAlignment(Layout.Alignment.ALIGN_CENTER)
                .setLineSpacing(10f, 1f)
                .build()
        }
        val blockGap = if (japaneseLayout != null) 24 else 0
        val blockHeight = quoteLayout.height + (japaneseLayout?.height ?: 0) + blockGap

        canvas.save()
        canvas.translate(100f, (HEIGHT - blockHeight) / 2f + 20f)
        quoteLayout.draw(canvas)
        japaneseLayout?.let {
            canvas.translate(0f, quoteLayout.height.toFloat() + blockGap)
            it.draw(canvas)
        }
        canvas.restore()

        drawAttribution(canvas, item, accent, palette)
        drawHanko(canvas)

        return bitmap
    }

    /** Ink/paint data derived from the chosen background. */
    private data class Palette(val bg: Int, val ink: Int) {
        /** White quote text on dark canvases; full ink on light ones. */
        val primaryInk: Int
            get() = if (isDark) 0xFFFFFFFF.toInt() else ink
        val isDark: Boolean
            get() {
                val r = (bg shr 16) and 0xFF
                val g = (bg shr 8) and 0xFF
                val b = bg and 0xFF
                return (r * 299 + g * 587 + b * 114) / 1000 < 128
            }
    }

    /** Luminance-driven ink for a user-picked color. */
    private fun inkFor(argb: Int): Int {
        val r = (argb shr 16) and 0xFF
        val g = (argb shr 8) and 0xFF
        val b = argb and 0xFF
        return if ((r * 299 + g * 587 + b * 114) / 1000 < 128) {
            0xFFF3EFE8.toInt()
        } else {
            0xFF241C14.toInt()
        }
    }

    /**
     * Solid canvas with a subtle seigaiha pattern (staggered rows of concentric
     * circle arcs, each filled circle covering the row above - classic fish-scale waves)
     * and a soft darkening towards the bottom for text legibility.
     */
    private fun drawSeigaihaBackground(canvas: Canvas, w: Float, h: Float, palette: Palette) {
        canvas.drawRect(0f, 0f, w, h, Paint().apply { color = palette.bg })

        val radius = 120f
        // ~8% contrast strokes: white on dark canvases, ink on light ones.
        val strokeColor = if (palette.isDark) 0x12FFFFFF.toInt() else 0x11000000.toInt()
        val stroke = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeWidth = 3f
            color = strokeColor
        }
        val fill = Paint().apply { color = palette.bg }

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
        val shadeAlpha = if (palette.isDark) 0x2E000000.toInt() else 0x14000000.toInt()
        val shade = LinearGradient(
            0f, 0f, 0f, h,
            intArrayOf(0x00000000, shadeAlpha),
            floatArrayOf(0.55f, 1f),
            Shader.TileMode.CLAMP,
        )
        canvas.drawRect(0f, 0f, w, h, Paint().apply { shader = shade })
    }

    /** Vertical [mei-gen] (famous saying) running down the right edge, whisper-quiet. */
    private fun drawVerticalMotif(canvas: Canvas, palette: Palette) {
        val paint = TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
            color = if (palette.isDark) 0x33FFFFFF.toInt() else 0x22000000.toInt()
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
    private fun drawBrandMark(canvas: Canvas, palette: Palette) {
        val bar = Paint().apply { color = BALLOON_BLUE }
        canvas.drawRoundRect(RectF(72f, 84f, 84f, 156f), 6f, 6f, bar)
        canvas.drawText(
            "Meigenly", 108f, 140f,
            TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
                color = palette.primaryInk
                textSize = 40f
                typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
            },
        )
    }

    /** Attribution pinned near the bottom, with the work accent as a thin marker. */
    private fun drawAttribution(canvas: Canvas, item: QuoteFull, accent: Int, palette: Palette) {
        val attribution = buildList {
            add(item.characterName)
            add(item.workTitle)
            item.quote.episode?.takeIf { it.isNotBlank() }?.let { add(it) }
        }.joinToString("  \u2022  ")
        val full = "\u2014 $attribution"

        val textPaint = TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
            color = palette.primaryInk
            textSize = 38f
        }
        val textX = 132f
        val baseline = HEIGHT - 108f
        val maxWidth = WIDTH - textX - 220f // keep clear of the hanko
        // Single-line fit: shrink to nothing instead of clipping long titles.
        while (textPaint.textSize > 22f && textPaint.measureText(full) > maxWidth) {
            textPaint.textSize -= 2f
        }
        canvas.drawText(full, textX, baseline, textPaint)

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
