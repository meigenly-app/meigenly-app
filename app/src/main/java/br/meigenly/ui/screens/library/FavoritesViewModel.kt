package br.meigenly.ui.screens.library

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import br.meigenly.data.db.entity.QuoteFull
import br.meigenly.data.repository.LibraryRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import javax.inject.Inject

/** Shared logic for Favorites and History screens. */
@HiltViewModel
class FavoritesViewModel @Inject constructor(
    private val libraryRepository: LibraryRepository,
) : ViewModel() {

    val favorites: StateFlow<List<QuoteFull>> = libraryRepository.observeFavorites()
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), emptyList())

    fun removeFavorite(quoteId: Long) {
        viewModelScope.launch { libraryRepository.toggleFavorite(quoteId) }
    }
}
