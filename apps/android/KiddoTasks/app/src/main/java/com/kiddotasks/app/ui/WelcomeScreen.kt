package com.kiddotasks.app.ui

import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.kiddotasks.app.di.AppComponent
import com.kiddotasks.app.ui.theme.KiddoTheme
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import javax.inject.Inject

@Composable
fun WelcomeScreen(onAuthenticated: () -> Unit) {
    val scope = rememberCoroutineScope()
    val email by remember { mutableStateOf("") }
    val password by remember { mutableStateOf("") }
    val mode by remember { mutableStateOf("signin") } // "signin" | "signup"
    val loading by remember { mutableStateOf(false) }
    val error by remember { mutableStateOf<String?>(null) }
    val appComponent: AppComponent = LocalAppComponent.current

    Column(
        modifier = Modifier.fillMaxSize().padding(24.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Text("KiddoTasks", style = MaterialTheme.typography.displayLarge, modifier = Modifier.padding(bottom = 8.dp))
        Text("Family chores & rewards", style = MaterialTheme.typography.bodyMedium, modifier = Modifier.padding(bottom = 32.dp))

        OutlinedTextField(
            value = email,
            onValueChange = { email = it },
            label = { Text("Email") },
            modifier = Modifier.fillMaxWidth().padding(bottom = 12.dp)
        )
        OutlinedTextField(
            value = password,
            onValueChange = { password = it },
            label = { Text("Password") },
            visualTransformation = PasswordVisualTransformation(),
            modifier = Modifier.fillMaxWidth().padding(bottom = 16.dp)
        )

        error?.let { msg ->
            Text(text = msg, color = MaterialTheme.colorScheme.error, modifier = Modifier.padding(bottom = 12.dp))
        }

        Button(
            onClick = {
                scope.launch {
                    loading = true
                    try {
                        if (mode == "signin") {
                            appComponent.cloudSyncEngine().signIn(email, password)
                        } else {
                            appComponent.cloudSyncEngine().signUp(email, password)
                        }
                        onAuthenticated()
                    } catch (e: Exception) {
                        error = e.message ?: "Sign in failed"
                    } finally {
                        loading = false
                    }
                }
            },
            enabled = !loading && email.isNotEmpty() && password.isNotEmpty(),
            modifier = Modifier.fillMaxWidth().padding(bottom = 12.dp)
        ) {
            Text(if (loading) "Signing in…" else (if (mode == "signin") "Sign in" else "Create account"))
        }

        TextButton(onClick = { mode = if (mode == "signin") "signup" else "signin" }) {
            Text(if (mode == "signin") "Create an account" else "Already have an account? Sign in")
        }
    }
}

@Composable
private fun LocalAppComponent: AppComponent = remember {
    val activity = LocalContext.current as androidx.activity.ComponentActivity
    // The AppComponent is injected into MainActivity; retrieve via a static holder
    AppComponentHolder.instance
}

object AppComponentHolder {
    @Volatile var instance: AppComponent? = null
    fun set(component: AppComponent) { instance = component }
}

// Coroutine helper (duplicate to keep this file self-contained)
private suspend fun com.google.android.gms.tasks.Task<com.google.firebase.auth.AuthResult>.await(): com.google.firebase.auth.AuthResult =
    kotlinx.coroutines.await(this)