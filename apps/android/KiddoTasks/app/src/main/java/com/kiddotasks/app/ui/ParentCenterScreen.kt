package com.kiddotasks.app.ui

import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.kiddotasks.app.ui.theme.KiddoTheme

@Composable
fun ParentCenterScreen() {
    Column(
        modifier = Modifier.fillMaxSize().padding(16.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Text("Parent Center", style = MaterialTheme.typography.displayLarge, modifier = Modifier.padding(bottom = 24.dp))

        Button(
            onClick = { /* open kids station pin screen */ },
            modifier = Modifier.fillMaxWidth().padding(bottom = 12.dp)
        ) {
            Text("Kids Station")
        }

        Button(
            onClick = { /* manage tasks */ },
            modifier = Modifier.fillMaxWidth().padding(bottom = 12.dp)
        ) {
            Text("Manage Tasks")
        }

        Button(
            onClick = { /* manage rewards */ },
            modifier = Modifier.fillMaxWidth().padding(bottom = 12.dp)
        ) {
            Text("Manage Rewards")
        }

        Button(
            onClick = { /* settings */ },
            modifier = Modifier.fillMaxWidth()
        ) {
            Text("Settings")
        }
    }
}

@Composable
fun KidStationScreen() {
    Column(
        modifier = Modifier.fillMaxSize().padding(16.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Text("Kids Station", style = MaterialTheme.typography.displayLarge, modifier = Modifier.padding(bottom = 24.dp))
        Text("Coming soon: child task view", style = MaterialTheme.typography.bodyMedium)
    }
}