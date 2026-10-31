package br.meigenly.ui.screens.works

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import br.meigenly.data.db.entity.QuoteFull
import br.meigenly.data.repository.ContentRepository
import br.meigenly.domain.model.Work
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.flow
import kotlinx.coroutines.flow.flowOn
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.stateIn
import javax.inject.Inject

@HiltViewModel
class WorksViewModel @Inject constructor(
    contentRepository: ContentRepository,
) : ViewModel() {

    /** Works in alphabetical order (accent-insensitive, per user request). */
    val works: StateFlow<List<Work>> = contentRepository.observeWorks()
        .map { list ->
            list.sortedWith(
                compareBy(String.CASE_INSENSITIVE_ORDER) { it.title },
            )
        }
        .stateIn(
            scope = viewModelScope,
            started = SharingStarted.WhileSubscribed(5_000),
            initialValue = emptyList(),
        )

    /** Today's deterministic pick (E8), loaded once per subscription run. */
    val todayQuote: StateFlow<QuoteFull?> = flow {
        emit(contentRepository.todayQuote())
    }
        .flowOn(Dispatchers.IO)
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), null)
}
