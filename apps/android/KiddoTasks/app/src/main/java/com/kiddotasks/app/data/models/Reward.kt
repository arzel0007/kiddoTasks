package com.kiddotasks.app.data.models

import java.util.Date

data class Reward(
    val id: String,
    val familyId: String,
    var name: String,
    var description: String = "",
    var icon: String = "gift",
    var pointCost: Int = 50,
    var eligibleChildIds: List<String> = emptyList(),
    var isActive: Boolean = true,
    val createdBy: String,
    val createdAt: Date = Date(),
    var updatedAt: Date = Date(),
    var version: Int = 1
) {
    fun isEligibleFor(childId: String): Boolean =
        eligibleChildIds.isEmpty() || eligibleChildIds.contains(childId)
}