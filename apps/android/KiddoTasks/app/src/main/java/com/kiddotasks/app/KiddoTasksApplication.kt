package com.kiddotasks.app

import android.app.Application
import com.kiddotasks.app.di.DaggerAppComponent
import com.kiddotasks.app.di.AppComponent
import javax.inject.Inject

class KiddoTasksApplication : Application() {

    lateinit var appComponent: AppComponent
        private set

    override fun onCreate() {
        super.onCreate()
        appComponent = DaggerAppComponent.factory().create(application = this)
    }
}