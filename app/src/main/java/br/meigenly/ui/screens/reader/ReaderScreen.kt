package br.meigenly.ui.screens.reader

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.horizontalScroll
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
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Bookmark
import androidx.compose.material.icons.outlined.Bookmark
import androidx.compose.material.icons.outlined.Image
import androidx.compose.material.icons.outlined.Palette
import androidx.compose.material.icons.outlined.Share
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LocalContentColor
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.derivedStateOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.runtime.snapshotFlow
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.foundation.clickable
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import br.meigenly.core.share.ShareBuilder
import br.meigenly.core.share.ShareImageBuilder
import br.meigenly.core.share.ShareIntents
import br.meigenly.core.share.ShareTheme
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
    val shareTheme by viewModel.shareTheme.collectAsStateWithLifecycle()
    val shareColor by viewModel.shareColor.collectAsStateWithLifecycle()
    var showPalette by remember { mutableStateOf(false) }

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
                    // Share as image + text (bitmap built off the main thread)
                    IconButton(onClick = {
                        scope.launch(Dispatchers.IO) {
                            val bitmap = ShareImageBuilder.createBitmap(
                                item = quote,
                                accentHex = quote.workAccentColor,
                                theme = shareTheme,
                                customColor = shareColor,
                            )
                            ShareIntents.shareImage(
                                context,
                                bitmap,
                                "meigenly_${quote.quote.id}",
                                extraText = ShareBuilder.buildShareText(quote),
                            )
                        }
                    }) {
                        Icon(
                            imageVector = Icons.Outlined.Image,
                            contentDescription = "Compartilhar imagem",
                        )
                    }
                    // Image style picker (themes + custom color)
                    IconButton(onClick = { showPalette = true }) {
                        Icon(
                            imageVector = Icons.Outlined.Palette,
                            contentDescription = "Estilo da imagem",
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

    if (showPalette) {
        ModalBottomSheet(onDismissRequest = { showPalette = false }) {
            ShareStyleSheet(
                selectedTheme = shareTheme,
                selectedColor = shareColor,
                onPickTheme = viewModel::setShareTheme,
                onPickColor = viewModel::setShareColor,
            )
        }
    }
}

/** Preset colors the user can paint the share image with (theme-independent). */
private val CustomColors = listOf(
    0xFF111822.toInt(), // tinta preta
    0xFF0F3B43.toInt(), // mar
    0xFF4A148C.toInt(), // roxo
    0xFF1565C0.toInt(), // azul
    0xFF2E7D32.toInt(), // verde
    0xFF8C2B2B.toInt(), // vermelho
    0xFFE65100.toInt(), // laranja
    0xFFF9A825.toInt(), // âmbar
    0xFFF4ECDD.toInt(), // washi claro
    0xFFF7E3EA.toInt(), // sakura claro
    0xFFE0E0E0.toInt(), // prata
    0xFF6D4C41.toInt(), // terra
)

/** Bottom-sheet style picker: six themes + twelve custom paint colors. */
@Composable
private fun ShareStyleSheet(
    selectedTheme: ShareTheme,
    selectedColor: Int?,
    onPickTheme: (ShareTheme) -> Unit,
    onPickColor: (Int?) -> Unit,
) {
    Column(
        modifier = Modifier.fillMaxWidth().padding(horizontal = 20.dp).padding(bottom = 28.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Text(
            text = "Tema do fundo",
            style = MaterialTheme.typography.titleMedium,
        )
        Row(
            modifier = Modifier.horizontalScroll(rememberScrollState()),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            ShareTheme.entries.forEach { theme ->
                FilterChip(
                    selected = theme == selectedTheme,
                    onClick = { onPickTheme(theme) },
                    label = { Text(theme.label) },
                )
            }
        }
        Text(
            text = "Cor",
            style = MaterialTheme.typography.titleMedium,
        )
        Row(
            modifier = Modifier.horizontalScroll(rememberScrollState()),
            horizontalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            // Reset swatch: back to the theme's own background.
            Swatch(
                argb = null,
                selected = selectedColor == null,
                onClick = { onPickColor(null) },
            )
            CustomColors.forEach { color ->
                Swatch(
                    argb = color,
                    selected = color == selectedColor,
                    onClick = { onPickColor(color) },
                )
            }
        }
    }
}

@Composable
private fun Swatch(
    argb: Int?,
    selected: Boolean,
    onClick: () -> Unit,
) {
    Box(
        modifier = Modifier
            .size(40.dp)
            .background(
                color = argb?.let { Color(it) } ?: MaterialTheme.colorScheme.surfaceContainerHighest,
                shape = CircleShape,
            )
            .border(
                width = if (selected) 3.dp else 1.dp,
                color = if (selected) {
                    MaterialTheme.colorScheme.onBackground
                } else {
                    MaterialTheme.colorScheme.outlineVariant
                },
                shape = CircleShape,
            )
            .clickable(onClick = onClick),
        contentAlignment = Alignment.Center,
    ) {
        if (argb == null) {
            Text(
                text = "A",
                style = MaterialTheme.typography.titleSmall,
                color = MaterialTheme.colorScheme.onSurface,
            )
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
    val cs = MaterialTheme.colorScheme
    Box(
        modifier = modifier
            .fillMaxSize()
            .background(
                Brush.verticalGradient(
                    listOf(cs.surfaceContainerLow, cs.background),
                ),
            ),
    ) {
        Column(
            modifier = Modifier.fillMaxSize().padding(20.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center,
        ) {
            Card(
                modifier = Modifier.fillMaxWidth(),
                shape = RoundedCornerShape(28.dp),
                colors = CardDefaults.cardColors(containerColor = cs.surfaceContainer),
                elevation = CardDefaults.cardElevation(defaultElevation = 2.dp),
            ) {
                Column(
                    Modifier.fillMaxWidth().padding(horizontal = 28.dp, vertical = 32.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
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
                    if (quote.quote.textJapanese != null) {
                        Spacer(Modifier.height(16.dp))
                        Text(
                            text = quote.quote.textJapanese!!,
                            style = MaterialTheme.typography.bodyLarge,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                            textAlign = TextAlign.Center,
                        )
                    }
                    if (quote.quote.textOriginal != null) {
                        Spacer(Modifier.height(8.dp))
                        Text(
                            text = quote.quote.textOriginal!!,
                            style = MaterialTheme.typography.bodyMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                            textAlign = TextAlign.Center,
                        )
                    }
                    Spacer(Modifier.height(24.dp))
                    HorizontalDivider(color = cs.outlineVariant.copy(alpha = 0.6f))
                    Spacer(Modifier.height(20.dp))
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
