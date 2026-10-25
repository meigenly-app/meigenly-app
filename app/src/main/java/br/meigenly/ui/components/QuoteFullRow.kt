package br.meigenly.ui.components

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Card
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import br.meigenly.data.db.entity.QuoteFull

/**
 * Shared list row for the favorites and history screens (both show QuoteFull rows).
 */
@Composable
fun QuoteFullRow(
    item: QuoteFull,
    trailing: (@Composable () -> Unit)? = null,
    onClick: (QuoteFull) -> Unit,
) {
    Card(
        modifier = Modifier.fillMaxWidth().clickable { onClick(item) },
    ) {
        Column(Modifier.padding(16.dp)) {
            Text(
                text = "\u201C${item.quote.text}\u201D",
                style = MaterialTheme.typography.bodyLarge,
                maxLines = 3,
                overflow = TextOverflow.Ellipsis,
            )
            Row(
                modifier = Modifier.padding(top = 8.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.SpaceBetween,
            ) {
                Text(
                    text = listOfNotNull(item.workTitle, item.characterName).joinToString(" · "),
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    modifier = Modifier.weight(1f),
                )
                if (trailing != null) {
                    trailing()
                }
            }
        }
    }
}
