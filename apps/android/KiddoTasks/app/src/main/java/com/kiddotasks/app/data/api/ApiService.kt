package com.kiddotasks.app.data.api

import com.google.gson.Gson
import com.google.gson.GsonBuilder
import com.google.gson.JsonDeserializationContext
import com.google.gson.JsonDeserializer
import com.google.gson.JsonElement
import com.google.gson.JsonParseException
import com.google.gson.reflect.TypeToken
import com.kiddotasks.app.data.models.*
import kotlinx.coroutines.CoroutineScope
import java.lang.reflect.Type
import java.text.ParseException
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone

class ApiService(
    private val apiClient: ApiClient,
    private val gson: Gson = buildGson()
) {
    companion object {
        private fun buildGson(): Gson {
            return GsonBuilder()
                .registerTypeAdapter(Date::class.java, object : JsonDeserializer<Date> {
                    override fun deserialize(json: JsonElement, typeOfT: Type, context: JsonDeserializationContext): Date {
                        val s = json.asString
                        val formats = listOf(
                            "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'",
                            "yyyy-MM-dd'T'HH:mm:ss'Z'",
                            "yyyy-MM-dd'T'HH:mm:ss.SSS",
                            "yyyy-MM-dd'T'HH:mm:ss",
                            "yyyy-MM-dd"
                        )
                        val sdf = SimpleDateFormat(formats.first(), Locale.US)
                        sdf.timeZone = TimeZone.getTimeZone("UTC")
                        return try {
                            sdf.parse(s) ?: Date()
                        } catch (_: ParseException) {
                            // Fallback: try other formats
                            formats.drop(1).firstOrNull { fmt ->
                                try {
                                    val f = SimpleDateFormat(fmt, Locale.US)
                                    f.timeZone = TimeZone.getTimeZone("UTC")
                                    f.parse(s) != null
                                } catch (_: Exception) {
                                    false
                                }
                            }?.let { fmt ->
                                val f = SimpleDateFormat(fmt, Locale.US)
                                f.timeZone = TimeZone.getTimeZone("UTC")
                                f.parse(s) ?: Date()
                            } ?: Date()
                        }
                    }
                })
                .create()
        }
    }
    private fun <T> parseList(json: String, type: Type): List<T> {
        val trimmed = json.trim()
        return if (trimmed.startsWith("[")) {
            gson.fromJson(json, type)
        } else {
            val map = gson.fromJson(json, Map::class.java) ?: emptyMap()
            for ((_, v) in map) {
                if (v is List<*>) return v as List<T>
            }
            emptyList()
        }
    }

    private fun <T> parseObject(json: String, clazz: Class<T>): T? =
        gson.fromJson(json, clazz)

    // ---------- Auth ----------
    suspend fun bootstrapFamily(): BootstrapResult {
        val json = apiClient.postJson("/api/auth/bootstrap", "{}")
        val map = gson.fromJson(json, Map::class.java) ?: emptyMap()
        return BootstrapResult(
            familyId = map["familyId"]?.toString() ?: "",
            kidsPin = map["kidsPin"]?.toString() ?: ""
        )
    }

    // ---------- Family ----------
    suspend fun getFamily(): Family? {
        val json = apiClient.getJson("/api/family")
        return gson.fromJson(json, Family::class.java)
    }

    suspend fun updateFamily(name: String?, settings: FamilySettings?): Boolean {
        val map = mutableMapOf<String, Any?>()
        if (name != null) map["name"] = name
        if (settings != null) map["settings"] = settings
        val json = apiClient.putJson("/api/family", gson.toJson(map))
        return gson.fromJson(json, Map::class.java)?.get("ok") == true
    }
}

// ---------- Children ----------
    suspend fun getChildren(): List<Child> {
        val json = apiClient.getJson("/api/children")
        val type = object : TypeToken<Map<String, List<Child>>>() {}.type
        val map = gson.fromJson(json, type)
        return map?.get("children") ?: emptyList()
    }

    suspend fun createChild(name: String, avatar: String?, colorHex: String?, dateOfBirth: String?): Child? {
        val map = mapOf(
            "name" to name,
            "avatar" to if (avatar != null) mapOf("emoji" to avatar, "colorHex" to colorHex ?: "#3978A8") else null,
            "dateOfBirth" to dateOfBirth
        )
        val json = apiClient.postJson("/api/children", gson.toJson(map))
        return gson.fromJson(json, Map::class.java)?.let { m ->
            val childMap = m["child"] as? Map<*, *> ?: emptyMap()
            gson.fromJson(gson.toJson(childMap), Child::class.java)
        }
    }

    suspend fun updateChild(childId: String, updates: Map<String, Any?>): Boolean {
        val json = apiClient.putJson("/api/children/$childId", gson.toJson(updates))
        return gson.fromJson(json, Map::class.java)?.get("ok") == true
    }

    suspend fun deleteChild(childId: String): Boolean {
        val json = apiClient.deleteJson("/api/children/$childId")
        return gson.fromJson(json, Map::class.java)?.get("ok") == true
    }

    // ---------- Tasks ----------
    suspend fun getTasks(): List<KiddoTask> {
        val json = apiClient.getJson("/api/tasks")
        val type = object : TypeToken<Map<String, List<KiddoTask>>>() {}.type
        val map = gson.fromJson(json, type)
        return map?.get("tasks") ?: emptyList()
    }

    suspend fun createTask(task: KiddoTaskRequest): KiddoTask? {
        val json = apiClient.postJson("/api/tasks", gson.toJson(task))
        return gson.fromJson(json, Map::class.java)?.let { m ->
            val t = m["task"] as? Map<*, *> ?: emptyMap()
            gson.fromJson(gson.toJson(t), KiddoTask::class.java)
        }
    }

    suspend fun updateTask(taskId: String, updates: Map<String, Any?>): Boolean {
        val json = apiClient.putJson("/api/tasks/$taskId", gson.toJson(updates))
        return gson.fromJson(json, Map::class.java)?.get("ok") == true
    }

    suspend fun archiveTask(taskId: String): Boolean {
        val json = apiClient.deleteJson("/api/tasks/$taskId")
        return gson.fromJson(json, Map::class.java)?.get("ok") == true
    }

// ---------- Completions ----------
    data class SubmitCompletionResult(
        val completionId: String,
        val requiresApproval: Boolean
    )

    suspend fun submitCompletion(taskId: String, childId: String, notes: String?, occurrenceKey: String?): SubmitCompletionResult {
        val map = mapOf(
            "taskId" to taskId,
            "childId" to childId,
            "notes" to notes,
            "occurrenceKey" to occurrenceKey
        )
        val json = apiClient.postJson("/api/completions", gson.toJson(map))
        val m = gson.fromJson(json, Map::class.java) ?: emptyMap()
        return SubmitCompletionResult(
            completionId = m["completionId"]?.toString() ?: "",
            requiresApproval = m["requiresApproval"] as? Boolean ?: true
        )
    }

    suspend fun approveCompletion(completionId: String): ApprovalResult {
        val json = apiClient.postJson("/api/completions/$completionId/approve", "{}")
        val m = gson.fromJson(json, Map::class.java) ?: emptyMap()
        return ApprovalResult(
            ok = m["ok"] as? Boolean ?: false,
            pointsAwarded = (m["pointsAwarded"] as? Number)?.toInt() ?: 0
        )
    }

    suspend fun declineCompletion(completionId: String): Boolean {
        val json = apiClient.postJson("/api/completions/$completionId/decline", "{}")
        return gson.fromJson(json, Map::class.java)?.get("ok") == true
    }

    // ---------- Rewards ----------
    suspend fun getRewards(): List<Reward> {
        val json = apiClient.getJson("/api/rewards")
        val type = object : TypeToken<Map<String, List<Reward>>>() {}.type
        val map = gson.fromJson(json, type)
        return map?.get("rewards") ?: emptyList()
    }

    suspend fun createReward(reward: RewardRequest): Reward? {
        val json = apiClient.postJson("/api/rewards", gson.toJson(reward))
        return gson.fromJson(json, Map::class.java)?.let { m ->
            val r = m["reward"] as? Map<*, *> ?: emptyMap()
            gson.fromJson(gson.toJson(r), Reward::class.java)
        }
    }

    suspend fun updateReward(rewardId: String, updates: Map<String, Any?>): Boolean {
        val json = apiClient.putJson("/api/rewards/$rewardId", gson.toJson(updates))
        return gson.fromJson(json, Map::class.java)?.get("ok") == true
    }

    suspend fun deleteReward(rewardId: String): Boolean {
        val json = apiClient.deleteJson("/api/rewards/$rewardId")
        return gson.fromJson(json, Map::class.java)?.get("ok") == true
    }

    // ---------- Claims ----------
    data class SubmitClaimResult(val claimId: String)

    suspend fun submitClaim(rewardId: String, childId: String, notes: String?): SubmitClaimResult {
        val map = mapOf("rewardId" to rewardId, "childId" to childId, "notes" to notes)
        val json = apiClient.postJson("/api/claims", gson.toJson(map))
        val m = gson.fromJson(json, Map::class.java) ?: emptyMap()
        return SubmitClaimResult(claimId = m["claimId"]?.toString() ?: "")
    }

    suspend fun approveClaim(claimId: String): Boolean {
        val json = apiClient.postJson("/api/claims/$claimId/approve", "{}")
        return gson.fromJson(json, Map::class.java)?.get("ok") == true
    }

    suspend fun declineClaim(claimId: String): Boolean {
        val json = apiClient.postJson("/api/claims/$claimId/decline", "{}")
        return gson.fromJson(json, Map::class.java)?.get("ok") == true
    }

    // ---------- Transactions ----------
    suspend fun getTransactions(childId: String? = null): List<PointTransaction> {
        val path = if (childId != null) "/api/transactions?childId=$childId" else "/api/transactions"
        val json = apiClient.getJson(path)
        val type = object : TypeToken<Map<String, List<PointTransaction>>>() {}.type
        val map = gson.fromJson(json, type)
        return map?.get("transactions") ?: emptyList()
    }

    // ---------- Result types ----------
    data class BootstrapResult(val familyId: String, val kidsPin: String)
    data class ApprovalResult(val ok: Boolean, val pointsAwarded: Int)

    // ---------- Request DTOs ----------
    data class KiddoTaskRequest(
        val name: String,
        val description: String = "",
        val icon: String = "checkmark.circle",
        val category: String = "household",
        val pointValue: Int = 10,
        val requiresApproval: Boolean = true,
        val approvalBehavior: String = "useFamilyDefault",
        val assignedChildIds: List<String> = emptyList(),
        val recurrence: Map<String, Any?> = mapOf("type" to "oneTime")
    )

    data class RewardRequest(
        val name: String,
        val description: String = "",
        val icon: String = "gift",
        val pointCost: Int = 50,
        val eligibleChildIds: List<String> = emptyList(),
        val isActive: Boolean = true
    )