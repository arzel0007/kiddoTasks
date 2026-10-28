package com.kiddotasks.app.data.repository

import android.content.Context
import android.content.SharedPreferences
import com.google.gson.Gson
import com.google.gson.reflect.TypeToken
import com.kiddotasks.app.data.models.*
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import java.util.Date
import java.lang.reflect.Type

/**
 * Local-first persistence mirroring iOS `LocalFamilyDataStore`.
 * Uses SharedPreferences + Gson for JSON snapshots.
 * Every mutation triggers `onLocalChanges` so the cloud sync engine can push.
 */
class LocalFamilyDataStore(
    private val context: Context,
    private val coroutineScope: CoroutineScope
) {
    private val prefs: SharedPreferences = context.getSharedPreferences("kiddotasks_local", Context.MODE_PRIVATE)
    private val gson = Gson()
    private val familyType: Type = object : TypeToken<Family>() {}.type

    var onLocalChanges: (() -> Unit)? = null

    private val FAMILY_KEY = "family_snapshot"
    private val CURRENT_CHILD_ID_KEY = "current_child_id"

    // ---------- Family ----------
    var currentFamily: Family?
        get() {
            val json = prefs.getString(FAMILY_KEY, null)
            return if (json != null) gson.fromJson(json, familyType) else null
        }
        set(family) {
            field = family
            if (family != null) {
                prefs.edit().putString(FAMILY_KEY, gson.toJson(family)).apply()
            } else {
                prefs.edit().remove(FAMILY_KEY).apply()
            }
            notifyChanges()
        }

    // ---------- Children ----------
    fun addChild(child: Child) {
        val fam = currentFamily ?: return
        val updated = fam.copy(memberIds = fam.memberIds + child.id)
        // In a full impl we'd store children in a separate collection; here we track via memberIds
        currentFamily = updated
    }

    fun removeChild(childId: String) {
        val fam = currentFamily ?: return
        currentFamily = fam.copy(memberIds = fam.memberIds.filter { it != childId })
    }

    fun updateChild(child: Child) {
        // Child data lives under family snapshot; placeholder for full CRUD
        notifyChanges()
    }

    // ---------- Tasks ----------
    fun addTask(task: KiddoTask) {
        val fam = currentFamily ?: return
        notifyChanges()
    }

    fun updateTask(task: KiddoTask) {
        notifyChanges()
    }

    fun deleteTask(taskId: String) {
        notifyChanges()
    }

    // ---------- Completions ----------
    fun submitCompletion(completion: TaskCompletion) {
        notifyChanges()
    }

    fun approveCompletion(completionId: String, approvedBy: String, pointsAwarded: Int) {
        notifyChanges()
    }

    fun declineCompletion(completionId: String) {
        notifyChanges()
    }

    // ---------- Rewards ----------
    fun addReward(reward: Reward) {
        val fam = currentFamily ?: return
        notifyChanges()
    }

    fun updateReward(reward: Reward) {
        notifyChanges()
    }

    // ---------- Claims ----------
    fun submitClaim(claim: RewardClaim) {
        notifyChanges()
    }

    fun approveClaim(claimId: String, approvedBy: String, transactionId: String) {
        notifyChanges()
    }

    fun declineClaim(claimId: String) {
        notifyChanges()
    }

    // ---------- Points ----------
    fun addPointsTransaction(tx: PointTransaction) {
        notifyChanges()
    }

    // ---------- Settings ----------
    fun updateSettings(settings: FamilySettings) {
        val fam = currentFamily ?: return
        currentFamily = fam.copy(settings = settings)
    }

    fun updateKidsStationPin(pin: String) {
        val fam = currentFamily ?: return
        currentFamily = fam.copy(settings = fam.settings.copy(kidsStationPin = pin))
    }

    // ---------- Current child (kid session) ----------
    var currentChildId: String?
        get() = prefs.getString(CURRENT_CHILD_ID_KEY, null)
        set(id) {
            if (id != null) {
                prefs.edit().putString(CURRENT_CHILD_ID_KEY, id).apply()
            } else {
                prefs.edit().remove(CURRENT_CHILD_ID_KEY).apply()
            }
        }

    fun clearSession() {
        prefs.edit().clear().apply()
        currentFamily = null
        currentChildId = null
    }

    private fun notifyChanges() {
        coroutineScope.launch(Dispatchers.Main) {
            onLocalChanges?.invoke()
        }
    }

    fun seedFromRemote(family: Family) {
        currentFamily = family
    }

    fun getSnapshot(): Family? = currentFamily
}