package br.meigenly.core.share

/**
 * Background themes for the share image. Each theme carries its canvas color and
 * ink color; every other surface (pattern, vignette, motifs) adapts to the ink
 * contrast computed in [ShareImageBuilder]. A user-picked [custom] color overrides
 * the preset background while keeping the same adaptive treatment.
 */
enum class ShareTheme(
    val label: String,
    val bg: Long,
    val onBg: Long,
) {
    /** Brand default: deep navy ink (launcher identity). */
    INK("Tinta", 0xFF111822, 0xFFFFFFFF),

    /** Washi paper: warm cream with dark ink. */
    WASHI("Washi", 0xFFF4ECDD, 0xFF2A2119),

    /** Sakura: soft blossom pink with plum ink. */
    SAKURA("Sakura", 0xFFF7E3EA, 0xFF4A2A35),

    /** Kaede: deep maple red with pale ink. */
    KAEDE("Kaede", 0xFF8C2B2B, 0xFFFCF1EC),

    /** Sumi: charcoal calligraphy black with light ink. */
    SUMI("Sumi", 0xFF1C1C1E, 0xFFEDEDED),

    /** Umi: deep sea teal with light ink. */
    UMI("Umi", 0xFF0F3B43, 0xFFEAF5F5),
}
