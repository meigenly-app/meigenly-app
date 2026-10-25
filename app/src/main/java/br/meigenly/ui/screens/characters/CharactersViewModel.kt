package br.meigenly.ui.screens.characters

import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import br.meigenly.data.repository.ContentRepository
import br.meigenly.domain.model.Character
import br.meigenly.domain.model.Work
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.stateIn
import javax.inject.Inject

@HiltViewModel
class CharactersViewModel @Inject constructor(
    savedStateHandle: SavedStateHandle,
    repository: ContentRepository,
) : ViewModel() {

    /** Nav argument: works route passes the selected work id. */
    private val workId: Long = requireNotNull(savedStateHandle[ARG_WORK_ID])

    val work: StateFlow<Work?> = repository.observeWork(workId)
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), null)

    val characters: StateFlow<List<Character>> = repository.observeCharacters(workId)
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), emptyList())

    companion object {
        const val ARG_WORK_ID = "workId"
    }
}
