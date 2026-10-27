package br.meigenly.core.share

import br.meigenly.data.db.entity.CharacterEntity
import br.meigenly.data.db.entity.QuoteEntity
import br.meigenly.data.db.entity.QuoteFull
import br.meigenly.data.db.entity.WorkEntity
import org.junit.Assert.assertEquals
import org.junit.Test

class ShareBuilderTest {

    private fun quoteFull(
        character: String,
        work: String,
        episode: String? = null,
    ) = QuoteFull(
        quote = QuoteEntity(id = 1, characterId = 2, text = "Frase de teste", episode = episode),
        characterName = character,
        characterSlug = "slug",
        characterArc = null,
        workTitle = work,
        workSlug = "work-slug",
        workAccentColor = null,
    )

    @Test
    fun `formats quote with attribution and brand`() {
        val text = ShareBuilder.buildShareText(
            quoteFull("Itachi Uchiha", "Naruto", "Shippuden Ep. 152"),
        )
        assertEquals(
            "\u201CFrase de teste\u201D\n" +
                "\u2014 Itachi Uchiha, Naruto (Shippuden Ep. 152)\n\n" +
                "via Meigenly",
            text,
        )
    }

    @Test
    fun `omits missing episode`() {
        val text = ShareBuilder.buildShareText(quoteFull("Haku", "Naruto"))
        assertEquals(
            "\u201CFrase de teste\u201D\n" +
                "\u2014 Haku, Naruto\n\n" +
                "via Meigenly",
            text,
        )
    }

    @Test
    fun `appends japanese source when present`() {
        val item = QuoteFull(
            quote = QuoteEntity(
                id = 1,
                characterId = 2,
                text = "Frase de teste",
                textJapanese = "日本語の原文",
            ),
            characterName = "Yuzuru Otonashi",
            characterSlug = "yuzuru-otonashi",
            characterArc = null,
            workTitle = "Angel Beats!",
            workSlug = "angel-beats",
            workAccentColor = null,
        )
        val text = ShareBuilder.buildShareText(item)
        assertEquals(
            "\u201CFrase de teste\u201D\n" +
                "\u2014 Yuzuru Otonashi, Angel Beats!\n" +
                "日本語の原文\n\n" +
                "via Meigenly",
            text,
        )
    }
}
