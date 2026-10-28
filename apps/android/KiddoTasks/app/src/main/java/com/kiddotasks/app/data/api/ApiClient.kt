package com.kiddotasks.app.data.api

import android.util.Log
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.auth.GetTokenResult
import java.io.IOException
import java.util.concurrent.TimeUnit
import okhttp3.*
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

/**
 * Thin OkHttp client that attaches the Firebase ID token to every request.
 * Base URL: https://kiddotasks-app.web.app
 */
class ApiClient private constructor(
    private val client: OkHttpClient,
    private val baseUrl: String,
    private val coroutineScope: CoroutineScope
) {
    companion object {
        @Volatile private var instance: ApiClient? = null

        fun init(baseUrl: String, scope: CoroutineScope): ApiClient {
            return synchronized(this) {
                instance ?: ApiClient(
                    OkHttpClient.Builder()
                        .connectTimeout(10, TimeUnit.SECONDS)
                        .readTimeout(10, TimeUnit.SECONDS)
                        .writeTimeout(10, TimeUnit.SECONDS)
                        .addInterceptor { chain ->
                            val original = chain.request()
                            val token = FirebaseAuth.getInstance().currentUser
                                ?.getIdToken(true)
                                ?.token
                            val builder = original.newBuilder()
                                .header("Accept", "application/json")
                                .header("Content-Type", "application/json")
                            if (token != null && !token.isEmpty()) {
                                builder.header("Authorization", "Bearer $token")
                            }
                            chain.proceed(builder.build())
                        }
                        .build(),
                    baseUrl,
                    scope
                ).also { instance = it }
            }
        }

        fun get(): ApiClient = instance ?: throw IllegalStateException("ApiClient not initialized. Call init() first.")
    }

    private suspend fun <T> execute(
        method: String,
        path: String,
        body: RequestBody?,
        parser: (Response) -> T
    ): T {
        return withContext(Dispatchers.IO) {
            val url = "$baseUrl$path"
            val request = Request.Builder()
                .url(url)
                .method(method, body)
                .build()
            try {
                val response = client.newCall(request).execute()
                if (!response.isSuccessful) {
                    val bodyStr = response.body?.string() ?: "no body"
                    Log.e("ApiClient", "$method $url failed: ${response.code} $bodyStr")
                    throw IOException("HTTP ${response.code}: $bodyStr")
                }
                parser(response)
            } catch (e: IOException) {
                Log.e("ApiClient", "$method $url network error", e)
                throw e
            }
        }
    }

    suspend fun getJson(path: String): String =
        execute("GET", path, null) { it.body?.string() ?: "" }

    suspend fun postJson(path: String, body: String): String =
        execute("POST", path, RequestBody.create(body, MediaType.get("application/json")!!)) {
            it.body?.string() ?: ""
        }

    suspend fun putJson(path: String, body: String): String =
        execute("PUT", path, RequestBody.create(body, MediaType.get("application/json")!!)) {
            it.body?.string() ?: ""
        }

    suspend fun deleteJson(path: String): String =
        execute("DELETE", path, null) { it.body?.string() ?: "" }
}

/** Convenience: parse a JSON string into a Kotlin object using Moshi or kotlinx.serialization. */
inline fun <reified T> String.fromJson(): T {
    // The caller is expected to use Moshi (already a dependency) or kotlinx.serialization.
    // We keep this as a thin wrapper so ApiClient stays dependency-agnostic.
    throw UnsupportedOperationException("Use ApiService methods instead of raw fromJson.")
}