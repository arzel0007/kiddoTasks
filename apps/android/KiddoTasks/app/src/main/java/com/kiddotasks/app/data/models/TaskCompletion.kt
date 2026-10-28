package com.kiddotasks.app.data.models

import com.google.gson.annotations.SerializedName
import java.util.Date

enum class CompletionStatus {
    @SerializedName("AWAITING_APPROVAL") PENDING,
    @SerializedName("APPROVED") APPROVED,
    @SerializedName("REJECTED") DECLINED,
    @SerializedName("COMPLETED") COMPLETED;

    val displayName: String
        get() = when (this) {
            PENDING -> "Pending"
            APPROVED -> "Approved"
            DECLINED -> "Declined"
            COMPLETED -> "Completed"
        }
}

data class TaskCompletion(
    val id: String,
    val familyId: String,
    val taskId: String,
    val childId: String,
    var status: CompletionStatus = CompletionStatus.PENDING,
    val completedAt: Date = Date(),
    var approvedAt: Date? = null,
    var approvedBy: String? = null,
    var pointsAwarded: Int? = null,
    var pointTransactionId: String? = null,
    var notes: String? = null,
    var occurrenceKey: String? = null
)