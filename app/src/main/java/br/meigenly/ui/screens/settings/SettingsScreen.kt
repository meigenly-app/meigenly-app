package br.meigenly.ui.screens.settings

import android.Manifest
import android.os.Build
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.CenterAlignedTopAppBar
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.RadioButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import br.meigenly.core.theme.ThemeMode
import br.meigenly.data.daily.DailyQuoteNotifier

/** Settings: theme mode selector (requirement #7). */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SettingsScreen(
    navigateBack: () -> Unit,
    viewModel: SettingsViewModel = hiltViewModel(),
) {
    val themeMode by viewModel.themeMode.collectAsStateWithLifecycle()

    Scaffold(
        topBar = {
            CenterAlignedTopAppBar(
                title = { Text("Ajustes") },
                navigationIcon = {
                    IconButton(onClick = navigateBack) {
                        Icon(
                            imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                            contentDescription = "Voltar",
                        )
                    }
                },
            )
        },
    ) { padding ->
        Column(
            Modifier
                .fillMaxSize()
                .padding(padding)
                .verticalScroll(rememberScrollState()),
        ) {
            Text(
                text = "Tema",
                style = MaterialTheme.typography.labelLarge,
                color = MaterialTheme.colorScheme.primary,
                modifier = Modifier.padding(horizontal = 16.dp, vertical = 12.dp),
            )
            ThemeMode.entries.forEach { mode ->
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .selectable(
                            selected = themeMode == mode,
                            onClick = { viewModel.onThemeModeChange(mode) },
                        )
                        .padding(horizontal = 16.dp, vertical = 10.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    RadioButton(selected = themeMode == mode, onClick = null)
                    Text(
                        text = when (mode) {
                            ThemeMode.SYSTEM -> "Seguir o sistema"
                            ThemeMode.LIGHT -> "Claro"
                            ThemeMode.DARK -> "Escuro"
                        },
                        modifier = Modifier.padding(start = 12.dp),
                        style = MaterialTheme.typography.bodyLarge,
                    )
                }
            }

            Text(
                text = "Notificações",
                style = MaterialTheme.typography.labelLarge,
                color = MaterialTheme.colorScheme.primary,
                modifier = Modifier.padding(start = 16.dp, top = 20.dp, bottom = 12.dp),
            )
            DailyQuoteToggle(viewModel = viewModel)

            Text(
                text = "Sobre",
                style = MaterialTheme.typography.labelLarge,
                color = MaterialTheme.colorScheme.primary,
                modifier = Modifier.padding(start = 16.dp, top = 20.dp, bottom = 12.dp),
            )
            Text(
                text = "Meigenly · versão 0.9.0",
                style = MaterialTheme.typography.bodyLarge,
                modifier = Modifier.padding(horizontal = 16.dp),
            )
            Text(
                text = "Meigenly é um projeto de fã, sem fins lucrativos e não afiliado " +
                    "aos estúdios ou editores das obras listadas. Os direitos das frases " +
                    "citadas e das obras de origem (Naruto, Dragon Ball Z, One Piece) " +
                    "pertencem aos seus respectivos criadores e detentores. O app usa " +
                    "apenas citações curtas com atribuição e não contém nenhuma arte " +
                    "de terceiros. Desinstalar o app remove todos os dados locais.",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.padding(start = 16.dp, end = 16.dp, top = 8.dp),
            )
        }
    }
}

/**
 * Daily-quote section (E8). On API 33+ turning the toggle on first requests
 * POST_NOTIFICATIONS; only a grant persists the preference and schedules the work.
 */
@Composable
private fun DailyQuoteToggle(viewModel: SettingsViewModel) {
    val enabled by viewModel.dailyQuoteEnabled.collectAsStateWithLifecycle()
    val context = LocalContext.current

    // Remember the user's intent across the permission roundtrip.
    val requestedEnabled = remember { androidx.compose.runtime.mutableStateOf(true) }
    val permissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission(),
    ) { granted ->
        viewModel.onDailyQuotePermissionResult(
            isEnabledRequested = requestedEnabled.value,
            granted = granted,
        )
    }

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column(Modifier.weight(1f)) {
            Text("Frase do dia", style = MaterialTheme.typography.bodyLarge)
            Text(
                text = "Uma notificação por dia, às 9h, com uma frase do acervo",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
        Switch(
            checked = enabled,
            onCheckedChange = { turningOn ->
                val grantedNow = DailyQuoteNotifier.hasPermission(context)
                if (turningOn && Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU && !grantedNow) {
                    requestedEnabled.value = true
                    permissionLauncher.launch(Manifest.permission.POST_NOTIFICATIONS)
                } else {
                    DailyQuoteNotifier.ensureChannel(context)
                    viewModel.onDailyQuoteToggle(turningOn)
                }
            },
        )
    }
}
