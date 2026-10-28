package com.kiddotasks.app.data.repository

import android.util.Log
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FirebaseFirestore
import com.kiddotasks.app.data.api.ApiService
import com.kiddotasks.app.data.models.*
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

class CloudSyncEngine(
    private val coroutineScope: CoroutineScope,
    private val localStore: LocalFamilyDataStore,
    private val apiService: ApiService
) {
    private val auth = FirebaseAuth.getInstance()
    private val firestore = FirebaseFirestore.getInstance()

    var isCloudMode: Boolean = false
        private set

    var currentUserId: String?
        get() = auth.currentUser?.uid

    var onFamilyUpdated: ((Family) -> Unit)? = null
    var onAuthStateChanged: ((Boolean) -> Unit)? = null
    var onError: ((String) -> Unit)? = null

    private var familyListener: com.google.firebase.firestore.ListenerRegistration? = null

    init {
        auth.addAuthStateListener { firebaseAuth ->
            val signedIn = firebaseAuth.currentUser != null
            coroutineScope.launch(Dispatchers.Main) {
                onAuthStateChanged?.invoke(signedIn)
                if (signedIn) {
                    pullFamily()
                }
            }
        }
    }

    fun isConfigured(): Boolean = isCloudMode

    // ---------- Auth ----------
    suspend fun signUp(email: String, password: String): String {
        auth.createUserWithEmailAndPassword(email, password).await()
        val userId = auth.currentUser!!.uid
        isCloudMode = true
        // Bootstrap family via the webapp API (canonical source of truth)
        val result = apiService.bootstrapFamily()
        localStore.seedFromRemote(
            Family(
                id = result.familyId,
                name = "My Family",
                memberIds = listOf(userId),
                settings = FamilySettings(kidsStationPin = result.kidsPin)
            )
        )
        coroutineScope.launch(Dispatchers.Main) {
            onAuthStateChanged?.invoke(true)
        }
        return userId
    }

    suspend fun signIn(email: String, password: String): String {
        auth.signInWithEmailAndPassword(email, password).await()
        isCloudMode = true
        coroutineScope.launch(Dispatchers.Main) {
            onAuthStateChanged?.invoke(true)
        }
        return auth.currentUser!!.uid
    }

    suspend fun signOut() {
        auth.signOut()
        isCloudMode = false
        coroutineScope.launch(Dispatchers.Main) {
            localStore.clearSession()
            onAuthStateChanged?.invoke(false)
        }
    }

    // ---------- Pull ----------
    private suspend fun pullFamily() {
        val userId = currentUserId ?: return
        try {
            // Try API first (webapp is source of truth)
            val family = apiService.getFamily()
            if (family != null) {
                coroutineScope.launch(Dispatchers.Main) {
                    localStore.seedFromRemote(family)
                    onFamilyUpdated?.invoke(family)
                }
                startFamilyListener(userId)
                return
            }
            // Fallback: direct Firestore read
            val doc = firestore.collection("families").document(userId).get().await()
            if (doc.exists) {
                val family = mapToFamily(doc.data!!)
                coroutineScope.launch(Dispatchers.Main) {
                    localStore.seedFromRemote(family)
                    onFamilyUpdated?.invoke(family)
                }
                startFamilyListener(userId)
            }
        } catch (e: Exception) {
            Log.e("CloudSync", "Pull failed", e)
            coroutineScope.launch(Dispatchers.Main) {
                onError?.invoke(e.message ?: "Pull failed")
            }
        }
    }

    private fun startFamilyListener(userId: String) {
        familyListener?.remove()
        familyListener = firestore.collection("families").document(userId)
            .addSnapshotListener { snapshot, e ->
                if (e != null) return@addSnapshotListener
                val data = snapshot?.data ?: return@addSnapshotListener
                val family = mapToFamily(data)
                coroutineScope.launch(Dispatchers.Main) {
                    localStore.seedFromRemote(family)
                    onFamilyUpdated?.invoke(family)
                }
            }
    }

    // ---------- Firebase helpers ----------
    private fun mapToFamily(data: Map<String, Any?>): Family {
        val settingsData = data["settings"] as? Map<*, *> ?: emptyMap()
        val settings = FamilySettings(
            pointDisplaySymbol = settingsData["pointDisplaySymbol"] as? String ?: "⭐",
            enableNotifications = settingsData["enableNotifications"] as? Boolean ?: true,
            celebrationAnimationsEnabled = settingsData["celebrationAnimationsEnabled"] as? Boolean ?: true,
            requireApprovalByDefault = settingsData["requireApprovalByDefault"] as? Boolean ?: true,
            weekStartsOn = (settingsData["weekStartsOn"] as? Number)?.toInt() ?: 1,
            kidsStationPin = settingsData["kidsStationPIN"] as? String ?: FamilySettings.generateRandomPin(),
            enableMiniGames = settingsData["enableMiniGames"] as? Boolean ?: true,
            basketballMaxMinutes = (settingsData["basketballMaxMinutes"] as? Number)?.toInt() ?: 0,
            allowanceMode = AllowanceMode(settingsData["allowanceMode"] as? String ?: "starsOnly"),
            flatDailyAmount = (settingsData["flatDailyAmount"] as? Number)?.toDouble() ?: 1.0,
            weekBonusTitle = settingsData["weekBonusTitle"] as? String ?: "Full week!",
            plan = settingsData["plan"] as? String ?: "free",
            enableWishlist = settingsData["enableWishlist"] as? Boolean ?: false
        )
        return Family(
            id = data["id"] as? String ?: "",
            name = data["name"] as? String ?: "My Family",
            memberIds = (data["members"] as? List<*> ?: emptyList()).map { it.toString() },
            familyCode = data["familyCode"] as? String ?: "",
            photoUrl = data["photoURL"] as? String,
            settings = settings,
            createdAt = Date((data["createdAt"] as? Number)?.time ?: System.currentTimeMillis()),
            updatedAt = Date((data["updatedAt"] as? Number)?.time ?: System.currentTimeMillis()),
            serverUpdatedAt = (data["serverUpdatedAt"] as? Number)?.let { Date(it.toLong()) }
        )
    }

    fun stop() {
        familyListener?.remove()
    }
}

// Coroutine helper for Firebase Auth Tasks
private suspend fun com.google.android.gms.tasks.Task<com.google.firebase.auth.AuthResult>.await(): com.google.firebase.auth.AuthResult =
    kotlinx.coroutines.await(this)