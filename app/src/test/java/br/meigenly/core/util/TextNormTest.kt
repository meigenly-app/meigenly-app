package br.meigenly.core.util

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/** Pure JVM tests for the FTS pattern builder used by ContentRepository. */
class TextNormTest {

    @Test
    fun `folds diacritics and case`() {
        assertEquals("nao", TextNorm.normalize("não"))
        assertEquals("historia", TextNorm.normalize("História"))
        assertEquals("amanha", TextNorm.normalize("amanhã"))
    }

    @Test
    fun `empty input stays empty`() {
        assertEquals("", TextNorm.normalize(""))
    }
}
