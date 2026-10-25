package br.meigenly.ui.screens.reader

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Bookmark
import androidx.compose.material.icons.outlined.Bookmark
import androidx.compose.material.icons.outlined.Image
import androidx.compose.material.icons.outlined.Share
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LocalContentColor
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.derivedStateOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.snapshotFlow
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import br.meigenly.core.share.ShareBuilder
import br.meigenly.core.share.ShareImageBuilder
import br.meigenly.core.share.ShareIntents
import br.meigenly.core.util.toAccentColor
import br.meigenly.data.db.entity.QuoteFull
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.collectLatest
import kotlinx.coroutines.flow.filterNotNull
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.launch

/**
 * Full-screen quote reader with swipe navigation.
 * History is recorded when pages settle; bookmark toggles favorites (E4).
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ReaderScreen(
    navigateBack: () -> Unit,
    viewModel: ReaderViewModel = hiltViewModel(),
) {
    val quotes by viewModel.quotes.collectAsStateWithLifecycle()
    val character by viewModel.character.collectAsStateWithLifecycle()

    if (quotes.isEmpty()) {
        Scaffold(
            topBar = { ReaderTopBar(onBack = navigateBack) },
        ) { padding ->
            Box(
                modifier = Modifier.fillMaxSize().padding(padding),
                contentAlignment = Alignment.Center,
            ) {
                Text("Nenhuma frase")
            }
        }
        return
    }

    val initialIndex = remember(quotes, viewModel.openedQuoteId) {
        val found = quotes.indexOfFirst { it.quote.id == viewModel.openedQuoteId }
        if (found >= 0) found else 0
    }
    val pagerState = rememberPagerState(
        initialPage = initialIndex,
        pageCount = { quotes.size },
    )
    // derivedStateOf avoids recomposition storms on every frame delta
    val currentPage by remember { derivedStateOf { pagerState.currentPage } }
    val currentAccent = quotes.getOrNull(currentPage)?.workAccentColor

    // Record reading history when a page settles (not on every swipe pixel).
    LaunchedEffect(pagerState, quotes) {
        snapshotFlow { pagerState.settledPage }
            .map { page -> quotes.getOrNull(page)?.quote?.id }
            .filterNotNull()
            .collectLatest { quoteId -> viewModel.recordViewed(quoteId) }
    }

    Scaffold(
        topBar = {
            ReaderTopBar(
                title = character?.name,
                onBack = navigateBack,
            ) {
                val quoteId = quotes.getOrNull(currentPage)?.quote?.id
                if (quoteId != null) {
                    val isFavorite by viewModel.observeIsFavorite(quoteId)
                        .collectAsStateWithLifecycle(initialValue = false)
                    IconButton(onClick = { viewModel.toggleFavorite(quoteId) }) {
                        Icon(
                            imageVector = if (isFavorite) Icons.Filled.Bookmark else Icons.Outlined.Bookmark,
                            contentDescription = if (isFavorite) "Remover dos favoritos" else "Favoritar",
                            tint = if (isFavorite) {
                                currentAccent.toAccentColor()
                            } else {
                                LocalContentColor.current
                            },
                        )
                    }
                }
                val quote = quotes.getOrNull(currentPage)
                val context = LocalContext.current
                val scope = rememberCoroutineScope()
                if (quote != null) {
                    // Share as text
                    IconButton(onClick = {
                        ShareIntents.shareText(context, ShareBuilder.buildShareText(quote))
                    }) {
                        Icon(
                            imageVector = Icons.Outlined.Share,
                            contentDescription = "Compartilhar texto",
                        )
                    }
                    // Share as image (bitmap built off the main thread)
                    IconButton(onClick = {
                        scope.launch(Dispatchers.IO) {
                            val bitmap = ShareImageBuilder.createBitmap(quote, quote.workAccentColor)
                            ShareIntents.shareImage(context, bitmap, "meigenly_${quote.quote.id}")
                        }
                    }) {
                        Icon(
                            imageVector = Icons.Outlined.Image,
                            contentDescription = "Compartilhar imagem",
                        )
                    }
                }
            }
        },
        bottomBar = {
            Row(
                modifier = Modifier.fillMaxWidth().padding(bottom = 16.dp),
                horizontalArrangement = Arrangement.Center,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                DotsIndicator(count = quotes.size, current = currentPage, accentColor = currentAccent)
                Spacer(Modifier.size(10.dp))
                Text(
                    text = "${currentPage + 1}/${quotes.size}",
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        },
    ) { padding ->
        HorizontalPager(
            state = pagerState,
            // keep the neighbours pre-composed so the swipe feels instant
            beyondViewportPageCount = 1,
            modifier = Modifier.fillMaxSize().padding(padding),
        ) { page ->
            QuotePage(quote = quotes[page])
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun ReaderTopBar(
    title: String? = null,
    onBack: () -> Unit,
    actions: @Composable () -> Unit = {},
) {
    androidx.compose.material3.TopAppBar(
        title = { Text(title ?: "") },
        colors = TopAppBarDefaults.topAppBarColors(
            containerColor = MaterialTheme.colorScheme.background,
        ),
        navigationIcon = {
            IconButton(onClick = onBack) {
                Icon(
                    imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                    contentDescription = "Voltar",
                )
            }
        },
        actions = { actions() },
    )
}

@Composable
private fun QuotePage(
    quote: QuoteFull,
    modifier: Modifier = Modifier,
) {
    Column(
        modifier = modifier.fillMaxSize().padding(horizontal = 32.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        // Accent mark above the statement (brand touchpoint)
        Box(
            modifier = Modifier
                .size(10.dp)
                .background(
                    color = quote.workAccentColor.toAccentColor(),
                    shape = CircleShape,
                ),
        )
        Spacer(Modifier.height(20.dp))
        Text(
            text = "\u201C${quote.quote.text}\u201D",
            style = MaterialTheme.typography.headlineMedium,
            textAlign = TextAlign.Center,
        )
        if (quote.quote.textOriginal != null) {
            Spacer(Modifier.height(16.dp))
            Text(
                text = quote.quote.textOriginal!!,
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                textAlign = TextAlign.Center,
            )
        }
        Spacer(Modifier.height(28.dp))
        Text(
            text = quote.characterName,
            style = MaterialTheme.typography.titleMedium,
        )
        val meta = listOfNotNull(quote.workTitle, quote.quote.episode).joinToString("  ·  ")
        Text(
            text = meta,
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        if (quote.quote.context != null) {
            Spacer(Modifier.height(8.dp))
            Text(
                text = quote.quote.context!!,
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                textAlign = TextAlign.Center,
            )
        }
    }
}

@Composable
private fun DotsIndicator(
    count: Int,
    current: Int,
    accentColor: String?,
) {
    Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
        repeat(count) { index ->
            val color = if (index == current) {
                accentColor.toAccentColor()
            } else {
                MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.3f)
            }
            Box(
                modifier = Modifier.size(6.dp).background(color, CircleShape),
            )
        }
    }
}
