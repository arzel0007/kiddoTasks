package com.kiddotasks.app.ui

import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.navigation.NavHostController
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import com.kiddotasks.app.ui.theme.KiddoTheme

sealed object Screen {
    object WELCOME { const val route = "welcome" }
    object KIDS_PIN { const val route = "kids_pin" }
    object PARENT_CENTER { const val route = "parent_center" }
    object KID_STATION { const val route = "kid_station" }
}

@Composable
fun AppNavHost() {
    val navController = rememberNavController()
    KiddoTheme {
        NavHost(navController = navController, startDestination = Screen.WELCOME.route) {
            composable(Screen.WELCOME.route) {
                WelcomeScreen(onAuthenticated = {
                    navController.navigate(Screen.PARENT_CENTER.route) {
                        popUpTo(Screen.WELCOME.route) { inclusive = true }
                    }
                })
            }
            composable(Screen.KIDS_PIN.route) {
                KidsPinScreen(onUnlocked = {
                    navController.navigate(Screen.KID_STATION.route) {
                        popUpTo(Screen.KIDS_PIN.route) { inclusive = true }
                    }
                })
            }
            composable(Screen.PARENT_CENTER.route) {
                ParentCenterScreen()
            }
            composable(Screen.KID_STATION.route) {
                KidStationScreen()
            }
        }
    }
}

typealias NavHostController = androidx.navigation.NavHostController