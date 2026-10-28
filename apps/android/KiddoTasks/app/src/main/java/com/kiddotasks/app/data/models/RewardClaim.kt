package com.kiddotasks.app.data.models

import com.google.gson.annotations.SerializedName
import java.util.Date

enum class RewardClaimStatus {
    @SerializedName("CLAIMED") PENDING,
    @SerializedName("APPROVED") APPROVED,
    @SerializedName("REJECTED") DECLINED,
    @SerializedName("REDEEMED") REDEEMED;

    val displayName: String
        get() = when (this) {
            PENDING -> "Pending"
            APPROVED -> "Approved"
            DECLINED -> "Declined"
            REDEEMED -> "Redeemed"
        }
}

data class RewardClaim(
    val id: String,
    val familyId: String,
    val rewardId: String,
    val childId: String,
    var status: RewardClaimStatus = RewardClaimStatus.PENDING,
    val claimedAt: Date = Date(),
    var approvedAt: Date? = null,
    var approvedBy: String? = null,
    var pointDeductionTransactionId: String? = null,
    var notes: String? = null
)