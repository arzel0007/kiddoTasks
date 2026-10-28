package com.kiddotasks.app.di

import android.app.Application
import com.google.firebase.FirebaseApp
import com.kiddotasks.app.data.api.ApiClient
import com.kiddotasks.app.data.api.ApiService
import com.kiddotasks.app.data.repository.*
import dagger.Module
import dagger.Provides
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.SupervisorJob

@Module
@ExperimentalCoroutinesApi
object AppModule {

    @Provides
    fun provideApplication(app: Application): Application = app

    @Provides
    fun provideCoroutineScope(): CoroutineScope =
        kotlinx.coroutines.CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)

    @Provides
    fun provideLocalDataStore(app: Application, scope: CoroutineScope): LocalFamilyDataStore =
        LocalFamilyDataStore(app, scope)

    @Provides
    fun provideApiClient(app: Application, scope: CoroutineScope): ApiClient =
        ApiClient.init("https://kiddotasks-app.web.app", scope)

    @Provides
    fun provideApiService(apiClient: ApiClient): ApiService =
        ApiService(apiClient)

    @Provides
    fun provideCloudSyncEngine(scope: CoroutineScope, localStore: LocalFamilyDataStore, apiService: ApiService): CloudSyncEngine =
        CloudSyncEngine(scope, localStore, apiService)

    @Provides
    fun provideCompletionEligibility(): CompletionEligibility = CompletionEligibility

    @Provides
    fun provideFirebase(app: Application) {
        FirebaseApp.initializeApp(app)
    }
}