package com.kiddotasks.app.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.Color
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme

val LightColorScheme = lightColorScheme(
    primary = Color(0xFF3978A8),
    primaryContainer = Color(0xFFD7E8F6),
    secondary = Color(0xFF647487),
    secondaryContainer = Color(0xFFE2E8F0),
    tertiary = Color(0xFFD59A3A),
    surface = Color(0xFFFFFFFF),
    surfaceContainer = Color(0xFFF8FAFC),
    background = Color(0xFFFFFFFF),
    error = Color(0xFFD97868),
    onPrimary = Color(0xFFFFFFFF),
    onSecondary = Color(0xFFFFFFFF),
    onSurface = Color(0xFF0F172A),
    onBackground = Color(0xFF0F172A),
    outline = Color(0xFFCBD5E1)
)

val DarkColorScheme = darkColorScheme(
    primary = Color(0xFF6EB6E8),
    primaryContainer = Color(0xFF1E4A6B),
    secondary = Color(0xFF94A3B8),
    secondaryContainer = Color(0xFF334155),
    tertiary = Color(0xFFE2A35E),
    surface = Color(0xFF0F172A),
    surfaceContainer = Color(0xFF1E293B),
    background = Color(0xFF020617),
    error = Color(0xFFEF8A7E),
    onPrimary = Color(0xFF000000),
    onSecondary = Color(0xFF000000),
    onSurface = Color(0xFFF8FAFC),
    onBackground = Color(0xFFF8FAFC),
    outline = Color(0xFF334155)
)

val kiddoPurple = Color(0xFF8B5CF6)
val kiddoPink = Color(0xFFEC4899)
val kiddoBlue = Color(0xFF3978A8)
val kiddoGreen = Color(0xFF3F8B70)
val kiddoOrange = Color(0xFFD59A3A)

fun dynamicColorScheme(application: androidx.compose.runtime.ApplicationContext): androidx.compose.material3.ColorScheme =
    if (isSystemInDarkTheme()) DarkColorScheme else LightColorScheme