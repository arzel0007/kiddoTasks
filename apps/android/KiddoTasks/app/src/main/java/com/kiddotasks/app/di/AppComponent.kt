package com.kiddotasks.app.di

import android.app.Application
import com.kiddotasks.app.data.api.ApiService
import com.kiddotasks.app.data.repository.*
import com.kiddotasks.app.ui.MainActivity
import dagger.Component
import javax.inject.Singleton

@Singleton
@Component(modules = [AppModule::class])
interface AppComponent {
    fun localDataStore(): LocalFamilyDataStore
    fun cloudSyncEngine(): CloudSyncEngine
    fun completionEligibility(): CompletionEligibility
    fun apiService(): ApiService

    fun inject(activity: MainActivity)

    @Component.Factory
    interface Factory {
        fun create(@BindsInstance application: Application): AppComponent
    }
}