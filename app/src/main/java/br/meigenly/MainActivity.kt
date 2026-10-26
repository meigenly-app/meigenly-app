package br.meigenly

import android.content.Intent
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.navigation.compose.rememberNavController
import br.meigenly.core.theme.MeigenlyTheme
import br.meigenly.core.theme.ThemeMode
import br.meigenly.data.settings.SettingsRepository
import br.meigenly.ui.intro.IntroOverlay
import br.meigenly.ui.navigation.MeigenlyNavHost
import dagger.hilt.android.AndroidEntryPoint
import javax.inject.Inject

@AndroidEntryPoint
class MainActivity : ComponentActivity() {

    @Inject lateinit var settingsRepository: SettingsRepository

    /**
     * Deep links arriving while the task is already alive (launchMode=singleTask)
     * come through onNewIntent; we forward them to the NavHost (e.g. tapping the
     * daily-quote notification with the app open).
     */
    private val newDeepLinkIntent = mutableStateOf<Intent?>(null)

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        newDeepLinkIntent.value = intent
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            val themeMode by settingsRepository.observeThemeMode()
                .collectAsState(initial = ThemeMode.SYSTEM)

            MeigenlyTheme(themeMode = themeMode) {
                val navController = rememberNavController()
                LaunchedEffect(newDeepLinkIntent.value) {
                    newDeepLinkIntent.value?.let { navController.handleDeepLink(it) }
                }
                Box(modifier = Modifier.fillMaxSize()) {
                    MeigenlyNavHost(navController = navController)

                    // Brand moment: intro video on open; tap to skip.
                    var showIntro by rememberSaveable { mutableStateOf(true) }
                    if (showIntro) {
                        IntroOverlay(onFinished = { showIntro = false })
                    }
                }
            }
        }
    }
}
