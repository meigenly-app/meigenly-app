package br.meigenly.ui.screens.search

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.History
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import br.meigenly.data.db.entity.QuoteFull
import br.meigenly.domain.model.Character
import br.meigenly.domain.model.Work
import br.meigenly.ui.components.AccentAvatar
import br.meigenly.ui.components.CharacterImage

/** Global search: quote text (FTS), character names and work titles (E5). */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SearchScreen(
    onQuoteClick: (QuoteFull) -> Unit,
    onCharacterClick: (Character) -> Unit,
    onWorkClick: (Work) -> Unit,
    navigateBack: () -> Unit,
    viewModel: SearchViewModel = hiltViewModel(),
) {
    val query by viewModel.query.collectAsStateWithLifecycle()
    val history by viewModel.history.collectAsStateWithLifecycle()
    val resultsState = viewModel.results.collectAsStateWithLifecycle().value

    val focusRequester = remember { FocusRequester() }
    LaunchedEffect(Unit) { focusRequester.requestFocus() }

    Scaffold(
        topBar = {
            // Barra de busca mais abaixo do topo e com forma de pílula.
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(start = 4.dp, top = 26.dp, bottom = 6.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                IconButton(onClick = navigateBack) {
                    Icon(
                        imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                        contentDescription = "Voltar",
                    )
                }
                OutlinedTextField(
                    value = query,
                    onValueChange = viewModel::onQueryChange,
                    placeholder = { Text("Buscar frase, personagem ou obra") },
                    singleLine = true,
                    shape = RoundedCornerShape(28.dp),
                    modifier = Modifier
                        .weight(1f)
                        .padding(end = 12.dp)
                        .focusRequester(focusRequester),
                    trailingIcon = {
                        if (query.isNotEmpty()) {
                            IconButton(onClick = { viewModel.onQueryChange("") }) {
                                Icon(Icons.Filled.Close, contentDescription = "Limpar")
                            }
                        }
                    },
                )
            }
        },
    ) { padding ->
        val results = resultsState
        when {
            query.isBlank() -> {
                if (history.isNotEmpty()) {
                    HistoryList(
                        entries = history,
                        onPick = { viewModel.onQueryChange(it) },
                        onRemove = viewModel::removeHistoryEntry,
                        modifier = Modifier.padding(padding),
                    )
                } else {
                    SearchHint(Modifier.fillMaxSize().padding(padding))
                }
            }
            results != null && results.isEmpty -> {
                Column(
                    horizontalAlignment = Alignment.CenterHorizontally,
                    modifier = Modifier.fillMaxSize().padding(padding),
                ) {
                    Text("Nenhum resultado para \u201C$query\u201D")
                }
            }
            results != null -> {
                ResultsList(
                    results = results,
                    onQuoteClick = onQuoteClick,
                    onCharacterClick = onCharacterClick,
                    onWorkClick = onWorkClick,
                    modifier = Modifier.padding(padding),
                )
            }
            // still computing for a non-empty query
            else -> {}
        }
    }
}

@Composable
private fun SearchHint(modifier: Modifier) {
    Column(
        modifier = modifier,
        verticalArrangement = Arrangement.Center,
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Icon(Icons.Filled.Search, contentDescription = null)
        Text("Busque por texto da frase, nome ou obra")
    }
}

/** Last searches with a per-entry remove (X). Tapping an entry reruns it. */
@Composable
private fun HistoryList(
    entries: List<String>,
    onPick: (String) -> Unit,
    onRemove: (String) -> Unit,
    modifier: Modifier = Modifier,
) {
    Column(modifier = modifier.fillMaxSize()) {
        SectionTitle(
            title = "Buscas recentes",
            modifier = Modifier.padding(start = 16.dp, end = 16.dp, top = 12.dp, bottom = 8.dp),
        )
        LazyColumn(
            contentPadding = PaddingValues(horizontal = 16.dp, vertical = 4.dp),
            verticalArrangement = Arrangement.spacedBy(2.dp),
        ) {
            items(entries.size, key = { "h$it" }) { index ->
                val entry = entries[index]
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier.fillMaxWidth(),
                ) {
                    Icon(
                        imageVector = Icons.Filled.History,
                        contentDescription = null,
                        tint = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                    Text(
                        text = entry,
                        style = MaterialTheme.typography.bodyLarge,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                        modifier = Modifier
                            .weight(1f)
                            .clickable { onPick(entry) }
                            .padding(horizontal = 12.dp, vertical = 14.dp),
                    )
                    IconButton(onClick = { onRemove(entry) }) {
                        Icon(
                            imageVector = Icons.Filled.Close,
                            contentDescription = "Remover do histórico",
                            tint = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun ResultsList(
    results: SearchResults,
    onQuoteClick: (QuoteFull) -> Unit,
    onCharacterClick: (Character) -> Unit,
    onWorkClick: (Work) -> Unit,
    modifier: Modifier = Modifier,
) {
    LazyColumn(
        modifier = modifier.fillMaxSize(),
        contentPadding = androidx.compose.foundation.layout.PaddingValues(
            horizontal = 16.dp, vertical = 12.dp,
        ),
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        if (results.works.isNotEmpty()) {
            item { SectionTitle("Obras") }
            items(results.works, key = { "w${it.id}" }) { work ->
                WorkSearchRow(work, onWorkClick)
            }
        }
        if (results.characters.isNotEmpty()) {
            item { SectionTitle("Personagens") }
            items(results.characters, key = { "c${it.id}" }) { character ->
                CharacterSearchRow(character, onCharacterClick)
            }
        }
        if (results.quotes.isNotEmpty()) {
            item { SectionTitle("Frases") }
            items(results.quotes, key = { "q${it.quote.id}" }) { quote ->
                QuoteSearchRow(quote, onQuoteClick)
            }
        }
    }
}

@Composable
private fun SectionTitle(
    title: String,
    modifier: Modifier = Modifier,
) {
    Text(
        text = title,
        style = MaterialTheme.typography.labelLarge,
        color = MaterialTheme.colorScheme.primary,
        modifier = modifier.padding(top = 6.dp),
    )
}

@Composable
private fun WorkSearchRow(work: Work, onClick: (Work) -> Unit) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier.fillMaxWidth().clickable { onClick(work) },
    ) {
        AccentAvatar(name = work.title, accent = work.accentColor, size = 40.dp)
        Column(Modifier.weight(1f).padding(start = 12.dp)) {
            Text(work.title, style = MaterialTheme.typography.titleSmall)
            if (work.description != null) {
                Text(
                    text = work.description!!,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
            }
        }
    }
}

@Composable
private fun CharacterSearchRow(character: Character, onClick: (Character) -> Unit) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier.fillMaxWidth().clickable { onClick(character) },
    ) {
        CharacterImage(
            workSlug = character.workSlug,
            slug = character.slug,
            name = character.name,
            accent = null,
            size = 40.dp,
        )
        Column(Modifier.weight(1f).padding(start = 12.dp)) {
            Text(character.name, style = MaterialTheme.typography.titleSmall)
            if (character.arc != null) {
                Text(
                    text = character.arc!!,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }
    }
}

@Composable
private fun QuoteSearchRow(quote: QuoteFull, onClick: (QuoteFull) -> Unit) {
    Column(Modifier.fillMaxWidth().clickable { onClick(quote) }) {
        Text(
            text = "\u201C${quote.quote.text}\u201D",
            style = MaterialTheme.typography.bodyLarge,
            maxLines = 2,
            overflow = TextOverflow.Ellipsis,
        )
        Text(
            text = listOfNotNull(quote.workTitle, quote.characterName).joinToString(" · "),
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
}
