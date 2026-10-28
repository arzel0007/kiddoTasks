package com.kiddotasks.app.data.models

import java.util.Date

data class Achievement(
    val id: String,
    val familyId: String,
    var name: String,
    var description: String = "",
    var icon: String = "badge",
    var pointsRequired: Int = 0,
    var isUnlocked: Boolean = false,
    var unlockedAt: Date? = null,
    val createdAt: Date = Date()
)