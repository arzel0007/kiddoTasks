package com.kiddotasks.app.di

import android.app.Application
import com.kiddotasks.app.data.repository.*
import dagger.Component
import javax.inject.Singleton

@Singleton
@Component(modules = [AppModule::class])
interface AppComponent {
    fun localDataStore(): LocalFamilyDataStore
    fun cloudSyncEngine(): CloudSyncEngine
    fun completionEligibility(): CompletionEligibility
    fun playBillingManager(): PlayBillingManager

    @Component.Factory
    interface Factory {
        fun create(@BindsInstance application: Application): AppComponent
    }
}