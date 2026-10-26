package br.meigenly.ui.screens.works

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.Card
import androidx.compose.material3.CenterAlignedTopAppBar
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.LibraryBooks
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.outlined.Bookmark
import androidx.compose.material.icons.outlined.History
import androidx.compose.material.icons.outlined.Settings
import br.meigenly.data.db.entity.QuoteFull
import br.meigenly.domain.model.Work
import br.meigenly.ui.components.WorkCover

private const val TAB_WORKS = 0
private const val TAB_FAVORITES = 1
private const val TAB_HISTORY = 2

/** Level 1: works list ("livros"); bottom tabs reach favorites and history (E4). */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun WorksScreen(
    onWorkClick: (workId: Long) -> Unit,
    onOpenFavorites: () -> Unit,
    onOpenHistory: () -> Unit,
    onOpenSearch: () -> Unit,
    onOpenSettings: () -> Unit,
    onTodayQuoteClick: (QuoteFull) -> Unit,
    viewModel: WorksViewModel = hiltViewModel(),
) {
    val works by viewModel.works.collectAsStateWithLifecycle()
    val todayQuote by viewModel.todayQuote.collectAsStateWithLifecycle()
    val selectedTab by rememberSaveable { mutableIntStateOf(0) }

    Scaffold(
        topBar = {
            CenterAlignedTopAppBar(
                title = { Text("Meigenly") },
                actions = {
                    IconButton(onClick = onOpenSearch) {
                        Icon(Icons.Filled.Search, contentDescription = "Buscar")
                    }
                    IconButton(onClick = onOpenSettings) {
                        Icon(Icons.Outlined.Settings, contentDescription = "Ajustes")
                    }
                },
            )
        },
        bottomBar = {
            NavigationBar {
                NavigationBarItem(
                    selected = selectedTab == TAB_WORKS,
                    onClick = { /* already the works tab */ },
                    icon = { Icon(Icons.AutoMirrored.Outlined.LibraryBooks, contentDescription = null) },
                    label = { Text("Obras") },
                )
                NavigationBarItem(
                    selected = selectedTab == TAB_FAVORITES,
                    onClick = { onOpenFavorites() },
                    icon = { Icon(Icons.Outlined.Bookmark, contentDescription = null) },
                    label = { Text("Favoritos") },
                )
                NavigationBarItem(
                    selected = selectedTab == TAB_HISTORY,
                    onClick = { onOpenHistory() },
                    icon = { Icon(Icons.Outlined.History, contentDescription = null) },
                    label = { Text("Histórico") },
                )
            }
        },
    ) { padding ->
        if (works.isEmpty()) {
            Box(
                modifier = Modifier.fillMaxSize().padding(padding),
                contentAlignment = Alignment.Center,
            ) {
                Text("Biblioteca vazia")
            }
            return@Scaffold
        }

        LazyColumn(
            modifier = Modifier.padding(padding),
            contentPadding = PaddingValues(horizontal = 16.dp, vertical = 12.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            todayQuote?.let { quote ->
                item(key = "today_quote") {
                    TodayQuoteCard(quote = quote, onClick = { onTodayQuoteClick(quote) })
                }
            }

            items(works, key = { it.id }) { work ->
                WorkCard(work = work, onClick = { onWorkClick(work.id) })
            }
        }
    }
}

/** Deterministic daily pick (E8): tap opens the reader directly at that quote. */
@Composable
private fun TodayQuoteCard(quote: QuoteFull, onClick: () -> Unit) {
    Card(
        modifier = Modifier.fillMaxWidth().clickable(onClick = onClick),
    ) {
        Column(Modifier.padding(16.dp)) {
            Text(
                text = "Frase do dia",
                style = MaterialTheme.typography.labelLarge,
                color = MaterialTheme.colorScheme.primary,
            )
            Text(
                text = "“${quote.quote.text}”",
                style = MaterialTheme.typography.bodyLarge,
                maxLines = 3,
                modifier = Modifier.padding(top = 8.dp),
            )
            Text(
                text = listOfNotNull(quote.characterName, quote.workTitle).joinToString(" · "),
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.padding(top = 8.dp),
            )
        }
    }
}

@Composable
private fun WorkCard(work: Work, onClick: () -> Unit) {
    Card(
        modifier = Modifier.fillMaxWidth().clickable(onClick = onClick),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth().padding(16.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(14.dp),
        ) {
            WorkCover(slug = work.slug, title = work.title, accent = work.accentColor)
            Column(Modifier.weight(1f)) {
                Text(
                    text = work.title,
                    style = MaterialTheme.typography.titleMedium,
                )
                if (work.titleOriginal != null || work.year != null) {
                    val meta = listOfNotNull(work.titleOriginal, work.year?.toString())
                    Text(
                        text = meta.joinToString(" · "),
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
                if (work.description != null) {
                    Text(
                        text = work.description,
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        maxLines = 2,
                    )
                }
            }
        }
    }
}
