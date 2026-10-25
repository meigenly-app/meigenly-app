package br.meigenly.core.daily

/**
 * Deterministic daily pick: the same day always maps to the same quote for every user,
 * with no backend involvement. Pure JVM function (easily testable).
 *
 * Seed format recommended: "2026-10-25" plus a seed-version suffix, e.g. "2026-10-25-v1";
 * bumping the suffix re-shuffles the calendar without touching the app store.
 */
object DailyQuotePicker {

    fun pickOffset(count: Int, seed: String): Int {
        require(count > 0) { "count must be positive" }
        var hash = 1125899906842597L // large prime constant
        seed.toByteArray().forEach { byte ->
            hash = 31 * hash + byte
        }
        // Division-free positive modulo
        return (((hash % count) + count) % count).toInt()
    }
}
