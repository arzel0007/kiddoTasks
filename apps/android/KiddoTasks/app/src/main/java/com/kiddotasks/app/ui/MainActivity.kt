package com.kiddotasks.app.ui

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import com.kiddotasks.app.KiddoTasksApplication
import com.kiddotasks.app.di.AppComponent
import com.kiddotasks.app.data.repository.PlayBillingManager
import com.kiddotasks.app.ui.theme.KiddoTheme
import javax.inject.Inject

class MainActivity : ComponentActivity() {

    @Inject lateinit var appComponent: AppComponent

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        (application as KiddoTasksApplication).appComponent.inject(this)

        // Expose component for screens that need it (WelcomeScreen)
        com.kiddotasks.app.ui.AppComponentHolder.set(appComponent)

        // Initialize the API client (OkHttp + Firebase ID token interceptor)
        appComponent.apiService() // triggers Dagger graph; ApiClient initialized in AppModule
        // ApiClient.init is called lazily via provideApiClient; no explicit init needed here
        // because ApiClient.init() is called in provideApiClient at DI time.

        setContent {
            AppNavHost()
        }
    }
}