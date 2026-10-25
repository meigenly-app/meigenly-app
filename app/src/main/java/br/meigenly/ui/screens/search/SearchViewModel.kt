package br.meigenly.ui.screens.search

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import br.meigenly.data.db.entity.QuoteFull
import br.meigenly.data.repository.ContentRepository
import br.meigenly.domain.model.Character
import br.meigenly.domain.model.Work
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.FlowPreview
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.debounce
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.flow.flatMapLatest
import kotlinx.coroutines.flow.stateIn
import javax.inject.Inject

/** Empty query state marker. */
data class SearchResults(
    val quotes: List<QuoteFull> = emptyList(),
    val characters: List<Character> = emptyList(),
    val works: List<Work> = emptyList(),
) {
    val isEmpty: Boolean get() = quotes.isEmpty() && characters.isEmpty() && works.isEmpty()
}

@OptIn(ExperimentalCoroutinesApi::class, FlowPreview::class)
@HiltViewModel
class SearchViewModel @Inject constructor(
    private val repository: ContentRepository,
) : ViewModel() {

    private val _query = MutableStateFlow("")
    val query: StateFlow<String> = _query.asStateFlow()

    /** Debounced, react-to-typing results across the three search fronts. */
    val results: StateFlow<SearchResults?> = _query
        .debounce(250)
        .distinctUntilChanged()
        .flatMapLatest { text ->
            if (text.isBlank()) {
                flowOf(null)
            } else {
                combine(
                    repository.searchQuotes(text),
                    repository.searchCharacters(text),
                    repository.searchWorks(text),
                ) { quotes, characters, works ->
                    SearchResults(quotes, characters, works)
                }
            }
        }
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), null)

    fun onQueryChange(newQuery: String) {
        _query.value = newQuery
    }
}
