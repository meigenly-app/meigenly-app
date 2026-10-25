package br.meigenly.core.daily

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/** Pure JVM tests for the deterministic daily pick. */
class DailyQuotePickerTest {

    @Test
    fun `same seed always picks the same offset`() {
        val a = DailyQuotePicker.pickOffset(17, "2026-10-25-v1")
        val b = DailyQuotePicker.pickOffset(17, "2026-10-25-v1")
        assertEquals(a, b)
    }

    @Test
    fun `offset is always within bounds`() {
        repeat(200) { day ->
            val offset = DailyQuotePicker.pickOffset(17, "2026-08-01-day$day-v1")
            assertTrue(offset in 0 until 17)
        }
    }

    @Test
    fun `different seeds spread the picks across the catalog`() {
        val picks = (0 until 30)
            .map { DailyQuotePicker.pickOffset(17, "2026-09-$it-v1") }
            .toSet()
        // 30 days over 17 items must touch most of them (no catastrophic clustering)
        assertTrue(picks.size >= 10)
    }

    @Test(expected = IllegalArgumentException::class)
    fun `empty catalog is rejected`() {
        DailyQuotePicker.pickOffset(0, "2026-10-25-v1")
    }
}
