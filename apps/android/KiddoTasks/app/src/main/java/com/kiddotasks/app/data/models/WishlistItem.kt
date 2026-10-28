package com.kiddotasks.app.data.models

import java.util.Date

data class WishlistItem(
    val id: String,
    val familyId: String,
    val childId: String,
    var name: String,
    var description: String = "",
    var icon: String = "star",
    var pointCost: Int = 0,
    var isActive: Boolean = true,
    val createdAt: Date = Date()
)