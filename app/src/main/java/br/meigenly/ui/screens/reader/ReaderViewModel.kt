package br.meigenly.ui.screens.reader

import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import br.meigenly.data.db.entity.QuoteFull
import br.meigenly.data.repository.ContentRepository
import br.meigenly.data.repository.LibraryRepository
import br.meigenly.domain.model.Character
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.launch
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.stateIn
import javax.inject.Inject

@HiltViewModel
class ReaderViewModel @Inject constructor(
    savedStateHandle: SavedStateHandle,
    contentRepository: ContentRepository,
    private val libraryRepository: LibraryRepository,
) : ViewModel() {

    /** Nav arguments: reader route receives the character and the opened quote. */
    private val characterId: Long = requireNotNull(savedStateHandle[ARG_CHARACTER_ID])

    /** Quote the user tapped in the list — determines the initial pager index. */
    val openedQuoteId: Long = requireNotNull(savedStateHandle[ARG_QUOTE_ID])

    val character: StateFlow<Character?> = contentRepository.observeCharacter(characterId)
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), null)

    val quotes: StateFlow<List<QuoteFull>> = contentRepository.observeQuotesFull(characterId)
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), emptyList())

    fun recordViewed(quoteId: Long) {
        viewModelScope.launch {
            libraryRepository.recordHistory(quoteId)
        }
    }

    fun toggleFavorite(quoteId: Long, onResult: (Boolean) -> Unit = {}) {
        viewModelScope.launch {
            onResult(libraryRepository.toggleFavorite(quoteId))
        }
    }

    /** Favorite state for a quote, observed from the screen with the current page id. */
    fun observeIsFavorite(quoteId: Long) =
        libraryRepository.observeIsFavorite(quoteId)

    companion object {
        const val ARG_CHARACTER_ID = "characterId"
        const val ARG_QUOTE_ID = "quoteId"
    }
}
