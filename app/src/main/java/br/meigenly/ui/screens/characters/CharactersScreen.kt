package br.meigenly.ui.screens.characters

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
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.AssistChip
import androidx.compose.material3.Card
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
import br.meigenly.domain.model.Character
import br.meigenly.ui.components.AccentAvatar

/** Level 2: characters ("captulos") of the selected work. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CharactersScreen(
    onCharacterClick: (characterId: Long) -> Unit,
    navigateBack: () -> Unit,
    viewModel: CharactersViewModel = hiltViewModel(),
) {
    val work by viewModel.work.collectAsStateWithLifecycle()
    val characters by viewModel.characters.collectAsStateWithLifecycle()

    Scaffold(
        topBar = {
            androidx.compose.material3.TopAppBar(
                title = { Text(work?.title ?: "Personagens") },
                navigationIcon = {
                    IconButton(onClick = navigateBack) {
                        Icon(
                            imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                            contentDescription = "Voltar",
                            tint = MaterialTheme.colorScheme.onSurface,
                        )
                    }
                },
            )
        },
    ) { padding ->
        if (characters.isEmpty()) {
            Box(
                modifier = Modifier.fillMaxSize().padding(padding),
                contentAlignment = Alignment.Center,
            ) {
                Text("Nenhum personagem")
            }
            return@Scaffold
        }

        LazyColumn(
            modifier = Modifier.padding(padding),
            contentPadding = PaddingValues(horizontal = 16.dp, vertical = 12.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            items(characters, key = { it.id }) { character ->
                CharacterCard(
                    character = character,
                    accent = work?.accentColor,
                    onClick = { onCharacterClick(character.id) },
                )
            }
        }
    }
}

@Composable
private fun CharacterCard(
    character: Character,
    accent: String?,
    onClick: () -> Unit,
) {
    Card(
        modifier = Modifier.fillMaxWidth().clickable(onClick = onClick),
    ) {
        Column(Modifier.padding(16.dp)) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(14.dp),
            ) {
                AccentAvatar(name = character.name, accent = accent)
                Column(Modifier.weight(1f)) {
                    Text(
                        text = character.name,
                        style = MaterialTheme.typography.titleMedium,
                    )
                    if (character.nameOriginal != null || character.arc != null) {
                        val meta = listOfNotNull(character.nameOriginal, character.arc)
                        Text(
                            text = meta.joinToString(" · "),
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                }
                Text(
                    text = if (character.quoteCount == 1) "1 frase" else "${character.quoteCount} frases",
                    style = MaterialTheme.typography.labelLarge,
                    color = accent.toAccentColor(),
                )
            }
            if (character.description != null) {
                Text(
                    text = character.description!!,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    maxLines = 2,
                    modifier = Modifier.padding(top = 10.dp),
                )
            }
        }
    }
}
