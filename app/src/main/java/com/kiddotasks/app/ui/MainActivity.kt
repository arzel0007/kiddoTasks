package com.kiddotasks.app.ui

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.ui.Modifier
import com.kiddotasks.app.KiddoTasksApplication
import com.kiddotasks.app.di.AppComponent
import com.kiddotasks.app.ui.theme.KiddoTheme
import javax.inject.Inject

class MainActivity : ComponentActivity() {

    @Inject lateinit var appComponent: AppComponent

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        (application as KiddoTasksApplication).appComponent.inject(this)

        setContent {
            KiddoTheme {
                Scaffold {
                    Text("KiddoTasks", modifier = Modifier.fillMaxSize())
                }
            }
        }
    }
}