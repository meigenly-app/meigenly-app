package br.meigenly.ui.screens.library

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.outlined.Bookmark
import androidx.compose.material3.CenterAlignedTopAppBar
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import br.meigenly.core.util.toAccentColor
import br.meigenly.data.db.entity.QuoteFull
import br.meigenly.ui.components.QuoteFullRow

/** Favorites — user-marked quotes. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun FavoritesScreen(
    onQuoteClick: (QuoteFull) -> Unit,
    navigateBack: () -> Unit,
    viewModel: FavoritesViewModel = hiltViewModel(),
) {
    val favorites by viewModel.favorites.collectAsStateWithLifecycle()

    Scaffold(
        topBar = {
            CenterAlignedTopAppBar(
                title = { Text("Favoritos") },
                navigationIcon = {
                    IconButton(onClick = navigateBack) {
                        Icon(
                            imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                            contentDescription = "Voltar",
                        )
                    }
                },
            )
        },
    ) { padding ->
        if (favorites.isEmpty()) {
            Box(
                modifier = Modifier.fillMaxSize().padding(padding),
                contentAlignment = Alignment.Center,
            ) {
                Text("Sem favoritos. Toque no marcador no leitor.")
            }
            return@Scaffold
        }

        LazyColumn(
            modifier = Modifier.padding(padding),
            contentPadding = PaddingValues(horizontal = 16.dp, vertical = 12.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            items(favorites, key = { it.quote.id }) { item ->
                QuoteFullRow(
                    item = item,
                    onClick = onQuoteClick,
                    trailing = {
                        IconButton(onClick = { viewModel.removeFavorite(item.quote.id) }) {
                            Icon(
                                imageVector = Icons.Outlined.Bookmark,
                                contentDescription = "Remover dos favoritos",
                                tint = item.workAccentColor.toAccentColor(),
                            )
                        }
                    },
                )
            }
        }
    }
}
