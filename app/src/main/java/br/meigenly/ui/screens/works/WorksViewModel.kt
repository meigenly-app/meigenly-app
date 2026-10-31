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
import kotlinx.coroutines.flow.flowOn
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.stateIn
import javax.inject.Inject

/**
 * Home state emitted as a single snapshot.
 *
 * Works and the daily quote travel together so the list composes already containing the
 * quote card at index 0. Emitting them separately lets LazyColumn keep the first work
 * anchored when the card is prepended later, which pushes the card out of view.
 */
data class WorksUiState(
    val works: List<Work> = emptyList(),
    val todayQuote: QuoteFull? = null,
)

@HiltViewModel
class WorksViewModel @Inject constructor(
    private val contentRepository: ContentRepository,
) : ViewModel() {

    /**
     * Works in alphabetical order (accent-insensitive, per user request) plus today's
     * deterministic pick (E8).
     *
     * The quote is re-read whenever the catalog changes: on a fresh install the seed
     * import may still be running when the screen subscribes, so a one-shot query
     * could return null and leave the card hidden until the app restarts.
     */
    val state: StateFlow<WorksUiState> = contentRepository.observeWorks()
        .map { works ->
            WorksUiState(
                works = works.sortedWith(
                    compareBy(String.CASE_INSENSITIVE_ORDER) { it.title },
                ),
                todayQuote = contentRepository.todayQuote(),
            )
        }
        .flowOn(Dispatchers.IO)
        .stateIn(
            scope = viewModelScope,
            started = SharingStarted.WhileSubscribed(5_000),
            initialValue = WorksUiState(),
        )
}
