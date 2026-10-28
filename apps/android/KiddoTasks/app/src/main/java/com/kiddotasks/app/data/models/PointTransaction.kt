package com.kiddotasks.app.data.models

import java.util.Date

enum class TransactionType {
    EARNED, DEDUCTED, ADJUSTED;

    val displayName: String
        get() = when (this) {
            EARNED -> "Earned"
            DEDUCTED -> "Deducted"
            ADJUSTED -> "Adjustment"
        }
}

data class PointTransaction(
    val id: String,
    val familyId: String,
    val childId: String,
    var type: TransactionType = TransactionType.EARNED,
    var points: Int = 0,
    var relatedCompletionId: String? = null,
    var relatedClaimId: String? = null,
    var note: String? = null,
    val createdAt: Date = Date(),
    var createdBy: String
)