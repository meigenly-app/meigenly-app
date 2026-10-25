package br.meigenly.ui.screens.quotes

import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import br.meigenly.data.repository.ContentRepository
import br.meigenly.domain.model.Character
import br.meigenly.domain.model.Quote
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.stateIn
import javax.inject.Inject

@HiltViewModel
class QuotesViewModel @Inject constructor(
    savedStateHandle: SavedStateHandle,
    repository: ContentRepository,
) : ViewModel() {

    /** Nav argument: characters route passes the selected character id. */
    private val characterId: Long = requireNotNull(savedStateHandle[ARG_CHARACTER_ID])

    // Simple list for E2; the swipe reader (E3) will take these quote ids.
    val quotes: StateFlow<List<Quote>> = repository.observeQuotes(characterId)
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), emptyList())

    val character: StateFlow<Character?> = repository.observeCharacter(characterId)
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), null)

    companion object {
        const val ARG_CHARACTER_ID = "characterId"
    }
}
