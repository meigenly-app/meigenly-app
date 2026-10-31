package br.meigenly.core.share

import android.graphics.Bitmap
import android.graphics.BitmapShader
import android.graphics.Canvas
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF
import android.graphics.Shader
import android.graphics.Typeface
import android.text.Layout
import android.text.StaticLayout
import android.text.TextPaint
import br.meigenly.data.db.entity.QuoteFull
import kotlin.random.Random

/**
 * Renders the share-image card with Canvas + StaticLayout (deterministic, no Compose capture).
 * Japanese theming only - no third-party imagery. The seigaiha (wave) pattern, the vertical
 * [mei-gen] motif and the vermilion hanko seal survive any [ShareTheme]; ink colors adapt to
 * the chosen background (preset or user-picked [custom color][createBitmap]).
 * [portrait] (character photo, iff bundled) is drawn as an accent-ringed circle next to the
 * attribution; romaji appears under the kanji block.
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
        portrait: Bitmap? = null,
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

        drawThemeBackground(canvas, w, h, palette, theme)
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

        // Romaji under the kanji, quieter.
        val romaji = item.quote.textOriginal?.takeIf { it.isNotBlank() }
        val romajiLayout = romaji?.let { rm ->
            StaticLayout.Builder
                .obtain(rm, 0, rm.length, TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
                    color = palette.ink
                    alpha = 153 // ~0.6
                    textSize = 40f
                    typeface = Typeface.create(Typeface.SERIF, Typeface.ITALIC)
                }, WIDTH - 260)
                .setAlignment(Layout.Alignment.ALIGN_CENTER)
                .setLineSpacing(10f, 1f)
                .build()
        }

        val blockGap = if (japaneseLayout != null) 24 else 0
        val romajiGap = if (romajiLayout != null) 20 else 0
        val blockHeight = quoteLayout.height +
            (japaneseLayout?.height ?: 0) +
            (romajiLayout?.height ?: 0) +
            blockGap + romajiGap

        canvas.save()
        canvas.translate(100f, (HEIGHT - blockHeight) / 2f + 20f)
        quoteLayout.draw(canvas)
        japaneseLayout?.let {
            canvas.translate(0f, quoteLayout.height.toFloat() + blockGap)
            it.draw(canvas)
        }
        romajiLayout?.let {
            canvas.translate(0f, (japaneseLayout?.height ?: 0).toFloat() + romajiGap)
            it.draw(canvas)
        }
        canvas.restore()

        drawAttribution(canvas, item, accent, palette, portrait)
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
     * Solid canvas + the theme's own motif + a soft darkening towards the bottom
     * for text legibility. Motifs use whisper-quiet ink adaptations so quote text
     * stays readable on every background (preset or user-picked color).
     */
    private fun drawThemeBackground(canvas: Canvas, w: Float, h: Float, palette: Palette, theme: ShareTheme) {
        canvas.drawRect(0f, 0f, w, h, Paint().apply { color = palette.bg })
        when (theme) {
            ShareTheme.INK -> drawInkSplashes(canvas, w, h, palette)
            ShareTheme.WASHI -> drawPaperFibers(canvas, w, h, palette)
            ShareTheme.SAKURA -> drawSakuraPetals(canvas, w, h, palette)
            ShareTheme.KAEDE -> drawMapleLeaves(canvas, w, h, palette)
            ShareTheme.SUMI -> drawSumiWashes(canvas, w, h, palette)
            ShareTheme.UMI -> drawSeigaiha(canvas, w, h, palette)
        }

        drawVignette(canvas, w, h, palette)
    }

    /** [Umi]: seigaiha - staggered rows of concentric arcs, classic fish-scale waves. */
    private fun drawSeigaiha(canvas: Canvas, w: Float, h: Float, palette: Palette) {
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
    }

    /** Gentle darkening towards the bottom where attribution sits. */
    private fun drawVignette(canvas: Canvas, w: Float, h: Float, palette: Palette) {
        val shadeAlpha = if (palette.isDark) 0x2E000000.toInt() else 0x14000000.toInt()
        val shade = LinearGradient(
            0f, 0f, 0f, h,
            intArrayOf(0x00000000, shadeAlpha),
            floatArrayOf(0.55f, 1f),
            Shader.TileMode.CLAMP,
        )
        canvas.drawRect(0f, 0f, w, h, Paint().apply { shader = shade })
    }

    // ---- Theme motifs (all deterministic: fixed Random seed, no asset imagery) ----

    private const val PATTERN_SEED = 20251029

    private fun patternInk(palette: Palette, alpha: Int): Int {
        val rgb = if (palette.isDark) 0xFFFFFF else 0x000000
        return (alpha shl 24) or rgb
    }

    /** [Ink]: soft sumi blots and rounded brush strokes drifting across the canvas. */
    private fun drawInkSplashes(canvas: Canvas, w: Float, h: Float, palette: Palette) {
        val rnd = Random(PATTERN_SEED)
        val blot = Paint(Paint.ANTI_ALIAS_FLAG)
        val brush = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeWidth = 52f
            strokeCap = Paint.Cap.ROUND
        }

        repeat(16) {
            blot.color = patternInk(palette, 0x08 + rnd.nextInt(0x0C))
            val cx = rnd.nextFloat() * w
            val cy = rnd.nextFloat() * h
            val r = 40f + rnd.nextFloat() * 130f
            canvas.drawOval(
                RectF(cx - r, cy - r * 1.45f, cx + r, cy + r * 1.45f),
                blot,
            )
        }
        repeat(6) {
            brush.color = patternInk(palette, 0x0A + rnd.nextInt(0x0A))
            val x0 = rnd.nextFloat() * w
            val y0 = rnd.nextFloat() * h
            val len = 220f + rnd.nextFloat() * 340f
            val angle = (-0.28 + rnd.nextDouble() * 0.55) // shallow slant, both sides
            canvas.drawLine(
                x0,
                y0,
                x0 + (len * Math.sin(angle)).toFloat(),
                y0 - (len * Math.cos(angle)).toFloat(),
                brush,
            )
        }
    }

    /** [Washi]: the visible fiber weave of kozo paper - mostly horizontal threads. */
    private fun drawPaperFibers(canvas: Canvas, w: Float, h: Float, palette: Palette) {
        val rnd = Random(PATTERN_SEED + 1)
        val fiber = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeCap = Paint.Cap.ROUND
            strokeWidth = 2.4f
        }
        repeat(170) {
            fiber.color = patternInk(palette, 0x0C + rnd.nextInt(0x0A))
            val x0 = rnd.nextFloat() * w
            val y0 = rnd.nextFloat() * h
            val len = 40f + rnd.nextFloat() * 90f
            val dy = (rnd.nextFloat() - 0.5f) * 0.4f // slight vertical jitter
            canvas.drawLine(x0, y0, x0 + len, y0 + (len * dy), fiber)
        }
    }

    /** [Sakura]: scattered petals plus a few five-petal blossoms. */
    private fun drawSakuraPetals(canvas: Canvas, w: Float, h: Float, palette: Palette) {
        val rnd = Random(PATTERN_SEED + 2)
        val petal = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = if (palette.isDark) 0x2AF5C9D5.toInt() else 0x26C97D93
        }
        repeat(30) {
            val cx = rnd.nextFloat() * w
            val cy = rnd.nextFloat() * h
            val size = 24f + rnd.nextFloat() * 42f
            canvas.save()
            canvas.rotate(rnd.nextFloat() * 360f, cx, cy)
            canvas.drawOval(
                RectF(cx - size * 0.42f, cy - size * 0.78f, cx + size * 0.42f, cy + size * 0.78f),
                petal,
            )
            canvas.restore()
        }
        // Five-petal blossoms: loose circles around a tiny core.
        repeat(5) {
            val cx = rnd.nextFloat() * w
            val cy = rnd.nextFloat() * h
            val r = 30f + rnd.nextFloat() * 22f
            for (k in 0 until 5) {
                val angle = Math.toRadians((k * 72 + rnd.nextInt(18)).toDouble())
                canvas.drawCircle(
                    cx + (r * Math.sin(angle)).toFloat(),
                    cy - (r * Math.cos(angle)).toFloat(),
                    r * 0.52f,
                    petal,
                )
            }
            canvas.drawCircle(cx, cy, r * 0.34f, petal)
        }
    }

    /** [Kaede]: stylized five-lobed maple leaves, each rotated differently. */
    private fun drawMapleLeaves(canvas: Canvas, w: Float, h: Float, palette: Palette) {
        val rnd = Random(PATTERN_SEED + 3)
        val leaf = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = if (palette.isDark) 0x32FCF1EC.toInt() else 0x2CB4523B
        }
        repeat(18) {
            val cx = rnd.nextInt(w.toInt()).toFloat()
            val cy = rnd.nextInt(h.toInt()).toFloat()
            canvas.save()
            canvas.translate(cx, cy)
            canvas.rotate(rnd.nextFloat() * 360f)
            canvas.drawPath(MapleLeafPath(rnd.nextFloat() * 34f + 40f), leaf)
            canvas.restore()
        }
    }

    /** [Sumi]: vertical ink washes - tall bands fading at the edges. */
    private fun drawSumiWashes(canvas: Canvas, w: Float, h: Float, palette: Palette) {
        val rnd = Random(PATTERN_SEED + 4)
        repeat(7) {
            val x = rnd.nextFloat() * w
            val bandW = 70f + rnd.nextFloat() * 200f
            val alpha = 0x07 + rnd.nextInt(0x10)
            val washColor = patternInk(palette, alpha)
            val wash = LinearGradient(
                x, 0f, x + bandW, 0f,
                intArrayOf(0x00000000, washColor, 0x00000000),
                floatArrayOf(0f, 0.5f, 1f),
                Shader.TileMode.CLAMP,
            )
            canvas.drawRect(x, 0f, x + bandW, h, Paint().apply { shader = wash })
        }
        // Two pooling blots where washes would settle.
        val blot = Paint(Paint.ANTI_ALIAS_FLAG)
        repeat(2) {
            blot.color = patternInk(palette, 0x08 + rnd.nextInt(0x0A))
            val cx = rnd.nextFloat() * w
            val cy = rnd.nextFloat() * h
            canvas.drawOval(RectF(cx - 90f, cy - 26f, cx + 90f, cy + 26f), blot)
        }
    }

    /** Stylized maple-leaf silhouette: five sharp lobes, centered on (0, 0), pointing up. */
    private fun MapleLeafPath(size: Float): Path {
        val path = Path()
        val r = size / 2f
        val tips = 5
        for (k in 0 until tips) {
            val tipAngle = -Math.PI / 2 + k * (2 * Math.PI / tips)
            val notchAngle = tipAngle + Math.PI / tips
            if (k == 0) {
                path.moveTo((r * Math.cos(tipAngle)).toFloat(), (r * Math.sin(tipAngle)).toFloat())
            } else {
                path.lineTo((r * Math.cos(tipAngle)).toFloat(), (r * Math.sin(tipAngle)).toFloat())
            }
            path.lineTo(
                (r * 0.45f * Math.cos(notchAngle)).toFloat(),
                (r * 0.45f * Math.sin(notchAngle)).toFloat(),
            )
        }
        path.close()
        return path
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

    /** Attribution pinned near the bottom, with the work accent marker and character portrait. */
    private fun drawAttribution(
        canvas: Canvas,
        item: QuoteFull,
        accent: Int,
        palette: Palette,
        portrait: Bitmap? = null,
    ) {
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
        val baseline = HEIGHT - 108f
        var textX = 132f

        // Character portrait as a closed circle with a 4px accent ring, left of the attribution.
        if (portrait != null) {
            val diameter = 140f
            val ringWidth = 8f // 4px ring drawn as stroke on each side
            val cx = 152f
            val cy = baseline - 46f
            val radius = diameter / 2f
            val backing = Paint().apply {
                color = if (palette.isDark) 0xFF241C14.toInt() else 0xFFF3EFE8.toInt()
            }
            canvas.drawCircle(cx, cy, radius, backing)

            // Clip the bitmap into the circle, covering the full diameter.
            canvas.save()
            val clipPath = Path().apply { addCircle(cx, cy, radius, Path.Direction.CW) }
            canvas.clipPath(clipPath)
            canvas.drawBitmap(
                portrait,
                null,
                RectF(cx - radius, cy - radius, cx + radius, cy + radius),
                null,
            )
            canvas.restore()

            // Accent ring on top of the photo edge.
            val ring = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                style = Paint.Style.STROKE
                strokeWidth = 4f
                color = accent
            }
            canvas.drawCircle(cx, cy, radius - ringWidth / 2f + 2f, ring)

            textX = cx + radius + 28f
        }

        val maxWidth = WIDTH - textX - 220f // keep clear of the hanko
        // Single-line fit: shrink to nothing instead of clipping long titles.
        while (textPaint.textSize > 22f && textPaint.measureText(full) > maxWidth) {
            textPaint.textSize -= 2f
        }
        canvas.drawText(full, textX, baseline, textPaint)

        // Work accent marker, left of the attribution line (redundant next to the ringed portrait).
        if (portrait == null) {
            val marker = Paint().apply { color = accent }
            canvas.drawRoundRect(RectF(72f, baseline - 34f, 84f, baseline + 12f), 6f, 6f, marker)
        }
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
