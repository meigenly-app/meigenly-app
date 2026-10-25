package br.meigenly.ui.navigation

import androidx.compose.runtime.Composable
import androidx.navigation.NavHostController
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.navArgument
import androidx.navigation.navDeepLink
import br.meigenly.ui.screens.characters.CharactersScreen
import br.meigenly.ui.screens.library.FavoritesScreen
import br.meigenly.ui.screens.library.HistoryScreen
import br.meigenly.ui.screens.quotes.QuotesScreen
import br.meigenly.ui.screens.reader.ReaderScreen
import br.meigenly.ui.screens.search.SearchScreen
import br.meigenly.ui.screens.settings.SettingsScreen
import br.meigenly.ui.screens.works.WorksScreen

/** Route table; ids (stable DB keys) travel as long args. */
object Routes {
    const val WORKS = "works"
    const val CHARACTERS = "characters/{workId}"
    const val QUOTES = "quotes/{characterId}"
    const val READER = "reader/{characterId}/{quoteId}"
    const val FAVORITES = "favorites"
    const val HISTORY = "history"
    const val SEARCH = "search"
    const val SETTINGS = "settings"
}

@Composable
fun MeigenlyNavHost(navController: NavHostController) {
    NavHost(
        navController = navController,
        startDestination = Routes.WORKS,
    ) {
        composable(Routes.WORKS) {
            WorksScreen(
                onWorkClick = { workId ->
                    navController.navigate("characters/$workId") {
                        // single-top: avoid stacking a duplicated characters destination
                        launchSingleTop = true
                    }
                },
                onOpenFavorites = {
                    navController.navigate(Routes.FAVORITES) { launchSingleTop = true }
                },
                onOpenHistory = {
                    navController.navigate(Routes.HISTORY) { launchSingleTop = true }
                },
                onOpenSearch = {
                    navController.navigate(Routes.SEARCH) { launchSingleTop = true }
                },
                onOpenSettings = {
                    navController.navigate(Routes.SETTINGS) { launchSingleTop = true }
                },
                onTodayQuoteClick = { quote ->
                    navController.navigate("reader/${quote.quote.characterId}/${quote.quote.id}")
                },
            )
        }

        composable(
            route = Routes.CHARACTERS,
            arguments = listOf(navArgument("workId") { type = NavType.LongType }),
        ) {
            CharactersScreen(
                onCharacterClick = { characterId ->
                    navController.navigate("quotes/$characterId")
                },
                navigateBack = { navController.popBackStack() },
            )
        }

        composable(
            route = Routes.QUOTES,
            arguments = listOf(navArgument("characterId") { type = NavType.LongType }),
        ) {
            QuotesScreen(
                onQuoteClick = { quoteId ->
                    val characterId = it.arguments?.getLong("characterId") ?: 0L
                    navController.navigate("reader/$characterId/$quoteId")
                },
                navigateBack = { navController.popBackStack() },
            )
        }

        composable(
            route = Routes.READER,
            arguments = listOf(
                navArgument("characterId") { type = NavType.LongType },
                navArgument("quoteId") { type = NavType.LongType },
            ),
            deepLinks = listOf(
                navDeepLink { uriPattern = "meigenly://reader/{characterId}/{quoteId}" },
            ),
        ) {
            ReaderScreen(
                navigateBack = { navController.popBackStack() },
            )
        }

        composable(Routes.FAVORITES) {
            FavoritesScreen(
                onQuoteClick = { item ->
                    navController.navigate("reader/${item.quote.characterId}/${item.quote.id}")
                },
                navigateBack = { navController.popBackStack() },
            )
        }

        composable(Routes.HISTORY) {
            HistoryScreen(
                onQuoteClick = { item ->
                    navController.navigate("reader/${item.quote.characterId}/${item.quote.id}")
                },
                navigateBack = { navController.popBackStack() },
            )
        }

        composable(Routes.SEARCH) {
            SearchScreen(
                onQuoteClick = { item ->
                    navController.navigate("reader/${item.quote.characterId}/${item.quote.id}")
                },
                onCharacterClick = { character ->
                    navController.navigate("characters/${character.workId}")
                },
                onWorkClick = { work ->
                    navController.navigate("characters/${work.id}")
                },
                navigateBack = { navController.popBackStack() },
            )
        }

        composable(Routes.SETTINGS) {
            SettingsScreen(
                navigateBack = { navController.popBackStack() },
            )
        }
    }
}
