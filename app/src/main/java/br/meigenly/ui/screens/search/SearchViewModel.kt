package br.meigenly.ui.screens.search

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import br.meigenly.data.db.entity.QuoteFull
import br.meigenly.data.repository.ContentRepository
import br.meigenly.data.settings.SettingsRepository
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
import kotlinx.coroutines.launch
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
    private val settingsRepository: SettingsRepository,
) : ViewModel() {

    private val _query = MutableStateFlow("")
    val query: StateFlow<String> = _query.asStateFlow()

    /** Recent queries shown while the field is empty (most recent first). */
    val history: StateFlow<List<String>> = settingsRepository.observeSearchHistory()
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), emptyList())

    init {
        // Registra no histórico cada consulta que estabiliza (250ms sem digitar).
        viewModelScope.launch {
            _query.debounce(250).distinctUntilChanged().collect { text ->
                if (text.isNotBlank()) settingsRepository.addSearchQuery(text)
            }
        }
    }

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

    /** Removes one entry from the search history (the X on each row). */
    fun removeHistoryEntry(entry: String) {
        viewModelScope.launch { settingsRepository.removeSearchQuery(entry) }
    }
}
