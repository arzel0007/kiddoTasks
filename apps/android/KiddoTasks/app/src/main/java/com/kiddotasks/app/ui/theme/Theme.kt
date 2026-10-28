package com.kiddotasks.app.ui.theme

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.LocalContext
import androidx.compose.runtime.Composable
import androidx.compose.runtime.SideEffect
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.sp

@Composable
fun KiddoTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    content: @Composable () -> Unit
) {
    val colorScheme = if (darkTheme) DarkColorScheme else LightColorScheme
    SideEffect {
        // No dynamic color seeding; keep fixed kid brand colors
    }
    MaterialTheme(
        colorScheme = colorScheme,
        typography = KiddoTypography,
        content = content
    )
}