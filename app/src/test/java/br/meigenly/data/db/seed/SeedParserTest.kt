package br.meigenly.data.db.seed

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/** Pure JVM parser tests: JSON contract -> entity mapping. */
class SeedParserTest {

    private val json = SeedJson.json

    @Test
    fun `parses seed file with nested characters and quotes`() {
        val seed = parseJson(
            """
            {
              "schemaVersion": 1,
              "works": [
                {
                  "slug": "naruto",
                  "title": "Naruto",
                  "year": 2002,
                  "characters": [
                    {
                      "slug": "haku",
                      "name": "Haku",
                      "quotes": [
                        { "text": "Frase 1", "episode": "Ep. 12", "review": true },
                        { "text": "Frase 2" }
                      ]
                    }
                  ]
                }
              ]
            }
            """.trimIndent(),
        )

        assertEquals(1, seed.works.size)
        assertEquals("naruto", seed.works[0].slug)
        assertEquals(2002, seed.works[0].year)
        assertEquals(1, seed.works[0].characters.size)
        assertEquals(2, seed.works[0].characters[0].quotes.size)
        assertEquals("Ep. 12", seed.works[0].characters[0].quotes[0].episode)
        assertEquals(2002, seed.works[0].year)
        assertEquals("Frase 2", seed.works[0].characters[0].quotes[1].text)
    }

    @Test
    fun `unknown authoring-only fields are ignored`() {
        val seed = parseJson(
            """
            {
              "schemaVersion": 1,
              "_note": "authoring metadata",
              "works": [
                {
                  "slug": "one-piece",
                  "title": "One Piece",
                  "review": true,
                  "characters": [
                    { "slug": "luffy", "name": "Luffy", "quotes": [] }
                  ]
                }
              ]
            }
            """.trimIndent(),
        )

        assertEquals(1, seed.works.size)
        assertNull(seed.works[0].year)
        assertNull(seed.works[0].description)
    }

    @Test
    fun `empty seed parses with empty lists`() {
        val seed = parseJson("""{ "schemaVersion": 1 }""")
        assertEquals(0, seed.works.size)
    }

    private fun parseJson(text: String): SeedFile =
        json.decodeFromString<SeedFile>(text)
}
