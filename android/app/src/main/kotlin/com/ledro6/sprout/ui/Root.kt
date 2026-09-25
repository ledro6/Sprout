package com.ledro6.sprout.ui

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.expandHorizontally
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.shrinkHorizontally
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Icon
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.NavigationRail
import androidx.compose.material3.NavigationRailItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.navigation.NavGraph.Companion.findStartDestination
import androidx.navigation.NavHostController
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.navArgument
import com.ledro6.sprout.R
import com.ledro6.sprout.app.LocalSprout
import com.ledro6.sprout.design.Effects
import com.ledro6.sprout.model.Lang
import com.ledro6.sprout.ui.add.AddScreen
import com.ledro6.sprout.ui.components.CoachLayer
import com.ledro6.sprout.ui.components.UndoToast
import com.ledro6.sprout.ui.home.HomeScreen
import com.ledro6.sprout.ui.home.RoomsScreen
import com.ledro6.sprout.ui.home.TripScreen
import com.ledro6.sprout.ui.plant.ModelScreen
import com.ledro6.sprout.ui.plant.PlantScreen
import com.ledro6.sprout.ui.plant.PlantSettingsScreen
import com.ledro6.sprout.ui.profile.ProfileScreen
import com.ledro6.sprout.ui.search.SearchScreen
import com.ledro6.sprout.ui.settings.AboutScreen
import com.ledro6.sprout.ui.settings.GlossaryScreen
import com.ledro6.sprout.ui.settings.PrivacyScreen
import com.ledro6.sprout.ui.settings.SettingsScreen
import com.ledro6.sprout.ui.stats.OrreryScreen
import com.ledro6.sprout.ui.stats.PlantBookScreen
import com.ledro6.sprout.ui.stats.StatsScreen

/** Вкладки внизу — те же пять, что на iPhone. */
enum class Tab(val route: String, val icon: Int, val selectedIcon: Int, val key: String) {
    HOME("home", R.drawable.ic_home, R.drawable.ic_home_fill, "Главная"),
    STATS("stats", R.drawable.ic_bar_chart, R.drawable.ic_bar_chart, "Статистика"),
    ADD("add", R.drawable.ic_add_circle, R.drawable.ic_add_circle_fill, "Добавить"),
    PROFILE("profile", R.drawable.ic_person, R.drawable.ic_person_fill, "Профиль"),
    SEARCH("search", R.drawable.ic_search, R.drawable.ic_search, "Поиск");

    val title: String get() = Lang.text(key)
}

/** Переходы между экранами — одним словом из экрана, без маршрутов в нём. */
class Go(private val nav: NavHostController, val ar: (List<String>) -> Unit) {
    fun plant(id: String) = nav.navigate("plant/${enc(id)}")
    fun tune(id: String) = nav.navigate("tune/${enc(id)}")
    fun book(id: String) = nav.navigate("book/${enc(id)}")
    fun model(id: String) = nav.navigate("model/${enc(id)}")
    fun orrery() = nav.navigate("orrery")
    fun settings() = nav.navigate("settings")
    fun about() = nav.navigate("about")
    fun privacy() = nav.navigate("privacy")
    fun glossary() = nav.navigate("glossary")
    fun rooms() = nav.navigate("rooms")
    fun trip() = nav.navigate("trip")
    fun back() {
        if (!nav.popBackStack()) Unit
    }

    fun tab(tab: Tab) {
        nav.navigate(tab.route) {
            popUpTo(nav.graph.findStartDestination().id) { saveState = true }
            launchSingleTop = true
            restoreState = true
        }
    }

    private fun enc(id: String) = android.net.Uri.encode(id)
}

@Composable
fun SproutRoot(nav: NavHostController, go: Go) {
    val sprout = LocalSprout.current
    val entry by nav.currentBackStackEntryAsState()
    val route = entry?.destination?.route
    val top = Tab.entries.any { it.route == route } || route == null
    val shown = top && Effects.step >= Effects.LAST
    // Широкий экран (планшет, раскрытый складной) — вкладки сбоку, как в приложениях Google.
    BoxWithConstraints(Modifier.fillMaxSize()) {
        val rail = maxWidth >= 600.dp
        Row(Modifier.fillMaxSize()) {
            if (rail) {
                AnimatedVisibility(shown, enter = expandHorizontally() + fadeIn(), exit = shrinkHorizontally() + fadeOut()) {
                    NavigationRail(Modifier.fillMaxHeight()) {
                        Spacer(Modifier.weight(1f))
                        for (tab in Tab.entries) {
                            val picked = route == tab.route
                            NavigationRailItem(
                                selected = picked,
                                onClick = { go.tab(tab) },
                                icon = { Icon(painterResource(if (picked) tab.selectedIcon else tab.icon), contentDescription = null) },
                                label = { Text(tab.title, maxLines = 1, overflow = TextOverflow.Ellipsis) },
                            )
                        }
                        Spacer(Modifier.weight(1f))
                    }
                }
            }
            Scaffold(
                modifier = Modifier.weight(1f),
                bottomBar = {
                    if (!rail) AnimatedVisibility(shown, enter = slideInVertically { it } + fadeIn(), exit = slideOutVertically { it } + fadeOut()) {
                        NavigationBar {
                            for (tab in Tab.entries) {
                                val picked = route == tab.route
                                NavigationBarItem(
                                    selected = picked,
                                    onClick = { go.tab(tab) },
                                    icon = { Icon(painterResource(if (picked) tab.selectedIcon else tab.icon), contentDescription = null) },
                                    label = { Text(tab.title, maxLines = 1, overflow = TextOverflow.Ellipsis) },
                                )
                            }
                        }
                    }
                },
            ) { padding ->
                Box(Modifier.fillMaxSize()) {
                    NavHost(nav, startDestination = Tab.HOME.route) {
                        composable(Tab.HOME.route) { HomeScreen(go, padding) }
                        composable(Tab.STATS.route) { StatsScreen(go, padding) }
                        composable(Tab.ADD.route) { AddScreen(go, padding) }
                        composable(Tab.PROFILE.route) { ProfileScreen(go, padding) }
                        composable(Tab.SEARCH.route) { SearchScreen(go, padding) }
                        composable("plant/{id}", listOf(navArgument("id") { type = NavType.StringType })) {
                            PlantScreen(it.arguments?.getString("id").orEmpty(), go)
                        }
                        composable("tune/{id}", listOf(navArgument("id") { type = NavType.StringType })) {
                            PlantSettingsScreen(it.arguments?.getString("id").orEmpty(), go)
                        }
                        composable("book/{id}", listOf(navArgument("id") { type = NavType.StringType })) {
                            PlantBookScreen(it.arguments?.getString("id").orEmpty(), go)
                        }
                        composable("model/{id}", listOf(navArgument("id") { type = NavType.StringType })) {
                            ModelScreen(it.arguments?.getString("id").orEmpty(), go)
                        }
                        composable("orrery") { OrreryScreen(go) }
                        composable("settings") { SettingsScreen(go) }
                        composable("about") { AboutScreen(go) }
                        composable("privacy") { PrivacyScreen(go) }
                        composable("glossary") { GlossaryScreen(go) }
                        composable("rooms") { RoomsScreen(go) }
                        composable("trip") { TripScreen(go) }
                    }
                    UndoToast(
                        sprout.bin,
                        Modifier
                            .align(Alignment.BottomCenter)
                            .padding(bottom = padding.calculateBottomPadding()),
                    )
                }
            }
        }
        CoachLayer()
    }
}
