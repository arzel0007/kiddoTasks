package com.kiddotasks.app.ui

import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.kiddotasks.app.ui.theme.KiddoTheme
import javax.inject.Inject

@Composable
fun KidsPinScreen(onUnlocked: () -> Unit) {
    val pin by remember { mutableStateOf("") }
    val error by remember { mutableStateOf<String?>(null) }

    Column(
        modifier = Modifier.fillMaxSize().padding(24.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Text("Kids Station", style = MaterialTheme.typography.displayLarge, modifier = Modifier.padding(bottom = 8.dp))
        Text("Enter the 6-digit PIN", style = MaterialTheme.typography.bodyMedium, modifier = Modifier.padding(bottom = 32.dp))

        error?.let { msg ->
            Text(text = msg, color = MaterialTheme.colorScheme.error, modifier = Modifier.padding(bottom = 12.dp))
        }

        OutlinedTextField(
            value = pin,
            onValueChange = { pin = it.filter { it.isDigit() }.take(6).toString() },
            label = { Text("PIN") },
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
            maxLength = 6,
            modifier = Modifier.width(200.dp).padding(bottom = 16.dp)
        )

        Button(
            onClick = {
                // Validate against local store PIN; placeholder check
                if (pin.length == 6) {
                    onUnlocked()
                } else {
                    error = "Enter a 6-digit PIN"
                }
            },
            modifier = Modifier.width(200.dp)
        ) {
            Text("Unlock")
        }
    }
}